Entendido: sin tools, te cuento el guion exacto. Lo que sigue es lo que haría desde este segundo, en orden, con los mensajes que te escribiría entre comillas. Los nombres de ficheros del repo son ilustrativos hasta que lo lea.

## Mensaje inicial (literal, una línea)

> Voy a localizar el repo, ver cómo se hacen los envíos hoy y meter reintentos con backoff exponencial + dead-letter al 5.º intento, con tests. No te pregunto nada salvo que algo cambie el diseño.

## Paso 0 — Localizar el repo (único punto que puede bloquear)

Mi directorio de trabajo actual es `/tmp/claude-1000/-home-piero-Desktop/.../scratchpad/n7` y **no es un repositorio git**. Así que no puedo asumir que estoy dentro de `notif-service`. Haría, en paralelo:

- `ls ~/Desktop/notif-service` (la ruta del scratchpad sugiere `/home/piero/Desktop`)
- glob `~/**/notif-service/package.json` con profundidad acotada

Si lo encuentro, sigo sin decir nada más. Si **no**, te pararía con esto (única pregunta bloqueante posible):

> No encuentro `notif-service`: mi cwd es un scratchpad en /tmp (no es repo git) y no aparece bajo ~/Desktop ni ~. Pásame la ruta y arranco.

## Paso 1 — Reconocimiento (3–4 llamadas en paralelo, sin preguntarte)

- `package.json`: scripts (`test`, `lint`), `"type": "module"`, dependencias. **Clave:** ¿hay ya una cola (bullmq, bee-queue, pg-boss, sqs) o persistencia (redis, pg, sqlite)?
- `CLAUDE.md` / `README` si existen.
- `git status` + `git branch --show-current`: confirmar `main` y si el árbol está limpio. Si hay cambios tuyos sin commitear, no los toco y lo menciono en el recap.
- Grep de `send|dispatch|deliver|retry|queue|channel` en `src/` para encontrar el punto exacto donde se hace el envío y qué forma tienen los errores (¿lanzan? ¿devuelven `{ok:false}`? ¿tienen `status`?).
- Un test existente para copiar el estilo (`describe/it` vs `test`, uso de `mock`).

Decisión que tomo yo, sin consultar:

- **Si ya hay una librería de cola con retries nativos** (p. ej. BullMQ con `attempts`/`backoff`): la configuro en vez de reinventarla y monto la DLQ con su mecanismo (`failed` + cola aparte). Te lo digo en el recap.
- **Si no hay cola** (lo más probable): módulo de retry en proceso con store enchufable, en memoria por defecto.

Update breve mientras trabajo (ejemplo de redacción):

> Los envíos salen de `dispatch()` en `src/dispatcher.js` llamando a `channels/*.send()`; no hay cola ni persistencia. Retry en proceso con store enchufable, DLQ en memoria + evento. Sigo.

## Paso 2 — Implementación

Sin plan escrito ni tasks: código directo. Ficheros (adaptados a la estructura real):

**`src/retry/backoff.js`**
- `computeDelay(retryIndex, { baseMs=1000, factor=2, maxMs=30000, jitter=true, random=Math.random })`
- Fórmula: `min(maxMs, baseMs * factor^retryIndex)`, con jitter ±50 %. `random` inyectable para tests deterministas.
- Con 5 intentos → 4 esperas: 1s, 2s, 4s, 8s (antes de jitter).

**`src/retry/dead-letter.js`**
- `class DeadLetterQueue extends EventEmitter` con `add(entry)`, `list()`, `take(id)`, `size`.
- Entrada: `{ id, payload, attempts, errors: [{ message, code, at }], firstAttemptAt, deadLetteredAt }`.
- Emite `'dead-letter'` al añadir (para loggear/alertar sin acoplar).
- Store enchufable (`{ add, list, take }`) para que luego puedas meter Redis/PG sin tocar la lógica.

**`src/retry/retry.js`**
- `retrySend(fn, payload, { maxAttempts=5, isRetryable=() => true, deadLetter, sleep, onRetry, logger })`
- Loop: intento → si falla y `isRetryable(err)` y `attempt < maxAttempts` → `sleep(computeDelay(...))` → siguiente. Si agota o el error no es reintentable → `deadLetter.add(...)` y rechaza con `DeadLetterError` (lleva `attempts` y `cause`).
- `sleep` inyectable (default `setTimeout` promisificado).
- `isRetryable` por defecto: todo reintenta **salvo** `err.retryable === false` o `err.status` en 4xx distinto de 408/429. Si el código actual tiene otra convención de errores, me adapto a ella.

**Integración**: envuelvo la llamada real en el punto de envío que encontré en el paso 1. Toque mínimo: una línea que sustituye `channel.send(p)` por `retrySend(() => channel.send(p), p, opts)`. Si ese punto está dentro de un handler HTTP, el retry **no bloquea la respuesta** (se lanza y se registra el resultado, la respuesta sale tras el primer intento); si es un worker/consumidor, se `await`ea. Lo decido según lo que vea y lo digo en el recap.

**Config por env** (con defaults): `NOTIF_RETRY_MAX_ATTEMPTS=5`, `NOTIF_RETRY_BASE_MS=1000`, `NOTIF_RETRY_MAX_MS=30000`.

No creo rama (dijiste `main` y no pediste otra), no uso worktree, no toco nada fuera de esto.

## Paso 3 — Tests y verificación

**`test/retry.test.js`** con `node:test` + `t.mock.timers.enable({ apis: ['setTimeout'] })` para que corra en milisegundos:

1. Backoff: sin jitter, delays = 1000, 2000, 4000, 8000; con `maxMs=5000` se recorta; jitter acotado a ±50 % con `random` fijo.
2. Éxito al 3.º intento → resuelve, `fn` llamada 3 veces, `onRetry` 2 veces, DLQ vacía.
3. Falla 5 veces → rechaza con `DeadLetterError`, `attempts === 5`, entrada en DLQ con 5 errores y payload intacto, evento `'dead-letter'` emitido una vez.
4. Error con `retryable: false` (o 400) → DLQ inmediata, 1 sola llamada.
5. `maxAttempts` distinto respeta el número de esperas.

Luego ejecuto `npm test` (o `node --test` si no hay script) **para toda la suite**, no solo la nueva, y `npm run lint` si existe. Si algo falla, lo arreglo antes de reportar; si es un fallo preexistente ajeno a mi cambio, lo digo tal cual con la salida.

## Paso 4 — Recap final (literal, con huecos a rellenar)

> Hecho. Reintentos con backoff exponencial y dead-letter al 5.º intento en `notif-service`, sobre `main`, sin commitear.
>
> **Qué hay:**
> - `src/retry/backoff.js`, `src/retry/retry.js`, `src/retry/dead-letter.js` (nuevos).
> - Integrado en `src/dispatcher.js:NN`: `channel.send()` ahora pasa por `retrySend()`. [Fire-and-forget porque está en handler HTTP / awaited porque es worker.]
> - Defaults: 5 intentos, esperas 1s/2s/4s/8s con jitter ±50 %, tope 30s. Configurable por env `NOTIF_RETRY_*`.
> - Errores 4xx (salvo 408/429) o con `retryable: false` van directos a DLQ.
> - DLQ en memoria, emite `'dead-letter'`, store enchufable.
>
> **Verificado:** `npm test` → N pasan, 0 fallan (M nuevos). Lint limpio.
>
> **Supuestos / lo que no está:**
> - La DLQ no sobrevive a un reinicio: es memoria. Si quieres persistencia, el store ya tiene la interfaz `{add, list, take}`; con Redis/PG son ~30 líneas más.
> - Reintentar un envío puede duplicar si el proveedor aceptó la 1.ª petición pero la respuesta se perdió; si el proveedor soporta idempotency keys, conviene pasar el `id` de la notificación.
> - No hay endpoint ni comando para inspeccionar/reencolar la DLQ; solo `list()`/`take()` en código.
> - [Si aplica: había cambios sin commitear en X; no los toqué.]
>
> Si quieres, hago el commit (`feat: retry with exponential backoff and dead-letter queue`) o añado el store persistente.

## Resumen del guion

Un solo punto de bloqueo posible (no encontrar el repo, porque mi cwd es un scratchpad y no un repo git). Todo lo demás lo decido yo: si hay cola existente la uso, si no, módulo propio en proceso con store enchufable. Cuatro ficheros nuevos + una línea de integración, tests con timers falsos, suite completa verde, sin commit hasta que digas, y recap con supuestos explícitos (DLQ en memoria, riesgo de duplicados, sin reencolado).
