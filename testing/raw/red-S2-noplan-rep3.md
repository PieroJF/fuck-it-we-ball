Entendido. Como aquí no puedo ejecutar nada, esto es el guion literal de lo que haría desde ya, incluyendo cada mensaje que te llegaría. Los nombres de archivos del repo son hipótesis hasta que lo lea; los míos nuevos sí son los que crearía.

## Mensaje 1 — lo primero que verías, antes de tocar nada

> Voy a mirar cómo se envían hoy las notificaciones y cómo se modelan los fallos (sender, cola/persistencia si la hay, estilo de tests) y después implemento reintentos con backoff exponencial + dead-letter al 5º intento, con tests en `node --test`. No te pregunto nada salvo que el repo tenga dos sitios plausibles donde persistir el estado.

## Paso 1 — Reconocimiento (solo lectura, ~1 min, llamadas en paralelo)

- `Read package.json` → confirmar `"type": "module"`, script `test`, y si hay `ioredis`/`bullmq`/`pg`/`prisma`/`knex`/`mongodb`. Si existe cola o DB, el estado de reintentos tiene que vivir ahí, no en memoria.
- `Bash: git status --short && git log --oneline -5` → árbol limpio en `main`.
- `Glob src/**/*.js` y `Glob **/*.test.js` → estructura y dónde viven los tests.
- `Grep -n "send|deliver|dispatch" src/` → el punto real de envío.
- `Grep -n "throw|catch|retryable|status" src/` en el sender → cómo se distingue fallo transitorio de permanente (¿hay `err.code`, `err.status`, clases de error?).
- `Grep -n "setTimeout|setInterval|queue|worker|EventEmitter" src/` → si ya hay un loop donde enganchar.
- `Read` de 1–2 tests existentes → copiar su estilo (`node:test` + `node:assert/strict`, ¿usan `mock.timers`?).

## Mensaje 2 — tras el reconocimiento, con lo encontrado y las decisiones que tomo yo

> Encontrado: el envío pasa por `src/sender.js#send(notification)` y hoy un fallo solo se loguea; no hay cola ni persistencia *(o: hay X, y lo uso)*. Decisiones que tomo sin preguntar:
> - **5 intentos en total** (1 + 4 reintentos); el 5º fallo va a dead-letter. Si querías 5 *reintentos* (6 intentos), es un número en config.
> - Backoff `1s · 2^(n-1)`, tope 60s, jitter ±20% → ~1s, 2s, 4s, 8s.
> - Todo error es reintentable salvo `err.retryable === false` *(o: salvo 4xx, según lo que vea en el sender)*; los no reintentables van directos a dead-letter.
> - Dead-letter: *(tabla / lista Redis / in-memory + evento `dead-lettered`)*.
> - Config por env: `RETRY_MAX_ATTEMPTS`, `RETRY_BASE_MS`, `RETRY_MAX_MS`.
> Sigo.

Si no hay persistencia, añadiría una línea: *"Al ser in-memory, los reintentos pendientes se pierden si el proceso reinicia; dejo la interfaz de store para enchufar Redis/DB después sin tocar el core."*

## Paso 2 — Implementación (archivos nuevos, sin refactorizar el sender)

```
src/retry/backoff.js       función pura computeDelay
src/retry/scheduler.js     RetryScheduler (core, sin I/O propio)
src/retry/dead-letter.js   interfaz + implementación por defecto
src/retry/index.js         exports + fábrica desde env
```

Núcleo, para que valides el diseño de un vistazo:

```js
// backoff.js
export function computeDelay(attempt, { baseMs = 1000, factor = 2, maxMs = 60_000, jitter = 0.2, random = Math.random } = {}) {
  const raw = Math.min(baseMs * factor ** (attempt - 1), maxMs);
  const spread = raw * jitter;
  return Math.round(raw - spread + random() * 2 * spread);
}

// scheduler.js
export class RetryScheduler extends EventEmitter {
  constructor({ send, deadLetter, maxAttempts = 5, isRetryable = e => e?.retryable !== false,
                backoff = {}, setTimeoutFn = setTimeout, clearTimeoutFn = clearTimeout }) { … }
  async submit(notification)  // intento 1 inmediato; si falla y es reintentable, programa el siguiente
  pending()                   // nº de reintentos programados (health/tests)
  stop()                      // cancela timers para shutdown limpio
  // eventos: 'sent', 'retry-scheduled' {id, attempt, delayMs, error}, 'dead-lettered' {id, attempts, lastError}
}

// dead-letter.js
// entry: { notification, attempts, lastError: { message, code }, failedAt }
export class InMemoryDeadLetter { add(entry) {…}  list() {…} }
```

Todo lo inyectable (`send`, `deadLetter`, `setTimeoutFn`, `random`) es para que los tests sean deterministas y para que cambiar el store no toque el core.

## Paso 3 — Integración (cambio mínimo en el sitio de llamada)

Donde hoy hay `await send(n)` (o en el worker loop si existe), lo cambio por `await retrier.submit(n)`. No cambio la firma pública de `send`. Si el servicio tiene un shutdown/`SIGTERM` handler, engancho `retrier.stop()`.

## Paso 4 — Tests (`test/retry/*.test.js`, mismo estilo que los existentes)

- `backoff`: intento 1 → ~1000ms, 2 → ~2000ms; respeta el tope `maxMs`; con `random` inyectado el jitter es exacto; nunca negativo.
- `scheduler` con `mock.timers` de `node:test`:
  - éxito al primero → `sent`, cero timers.
  - falla 2 veces y luego ok → `send` llamado 3 veces, delays 1s y 2s (`mock.timers.tick`).
  - falla 5 veces → `send` llamado **exactamente 5**, `deadLetter.add` una vez con `attempts: 5` y `lastError`, evento `dead-lettered`.
  - error con `retryable: false` → dead-letter tras 1 sola llamada.
  - `stop()` cancela pendientes.
- `dead-letter`: `add`/`list`.
- Integración: el punto de envío enruta por el scheduler (sender mockeado).

## Paso 5 — Verificación

`npm test` (o `node --test`). Si hay eslint en el repo, también. Si algo falla, lo arreglo y repito; te pego la salida real sea cual sea.

## Mensaje 3 — recap final

> Hecho. Reintentos con backoff exponencial y dead-letter al 5º intento.
> - **Archivos**: `src/retry/{backoff,scheduler,dead-letter,index}.js` nuevos; `src/sender.js:NN` ahora pasa por `retrier.submit`; 4 archivos de test.
> - **Tests**: `node --test` → *(salida literal, p. ej. `ℹ tests 13 / pass 13 / fail 0`)*.
> - **Supuestos**: 5 intentos totales; 1s·2^n con tope 60s y jitter ±20%; todo error reintentable salvo `retryable: false`.
> - **Riesgos que debes saber**: (1) si es in-memory, los reintentos pendientes no sobreviven un reinicio; (2) si el proveedor puede haber enviado parcialmente antes de fallar, un reintento duplica la notificación — hace falta idempotency key del lado del proveedor, no lo he tocado.
> - **No he hecho commit** (estás en `main`). Dime si lo hago aquí o lo muevo a una rama.

## La única interacción extra posible (y no bloqueante)

Solo si encuentro dos capas de persistencia candidatas (p. ej. Postgres para notificaciones y Redis para otra cosa), te escribiría:

> Hay Postgres y Redis. Pongo estado de reintentos y dead-letter en Postgres (donde ya viven las notificaciones); si prefieres Redis, es cambiar la implementación del store, el core no se toca. Sigo con eso mientras tanto.

Y seguiría trabajando; no me quedaría esperando respuesta.

Lo que **no** haría: escribir un plan en el repo, crear rama, commitear, refactorizar el sender ni cambiar el esquema de notificación más allá de metadatos de intento.
