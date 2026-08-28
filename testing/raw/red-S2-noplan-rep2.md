Aquí no tengo tools de archivos ni shell, así que te doy la ejecución literal: qué tocaría, en qué orden, y cada mensaje que verías de mí. No te preguntaría nada antes de empezar (me dijiste "arranca ya"); las decisiones te las declaro en vez de consultarlas.

## Mensaje 1 (lo primero que verías)

> Voy: primero miro cómo se envía hoy una notificación (package.json, módulo de envío, si hay cola/DB/Redis) y luego implemento retry con backoff exponencial + dead-letter a los 5 intentos, con tests en `node:test`. No te pregunto nada salvo que encuentre algo que cambie el diseño; las decisiones que tome te las listo al final.

## Paso 1 — Exploración (~2 min, sin escribir nada)

1. `Read package.json` → confirmo `"type": "module"`, script `test` (`node --test` con qué patrón), deps. Busco específicamente: `bullmq`/`bee-queue` (cola), `ioredis`/`redis`/`pg`/`prisma`/`knex`/`mongoose`/`better-sqlite3` (persistencia), `pino`/`winston` (logger).
2. `Grep` por `send(`, `notify`, `dispatch`, `provider`, `channel`, `webhook` en `src/` → localizo el punto exacto donde se llama al proveedor y cómo se manejan errores hoy (¿throw? ¿resultado `{ ok:false }`?).
3. `Glob` de tests existentes (`test/**`, `**/*.test.js`) → copio la convención (ubicación, `node:assert/strict`, si usan `t.mock`).
4. `Read` del módulo de envío y de config/env (`src/config.js` o similar) para respetar cómo leen variables.

**Bifurcaciones según lo que encuentre:**

- **Hay BullMQ (o similar):** no monto un scheduler propio. Configuro `attempts: 5`, `backoff: { type: 'exponential', delay: 1000 }` en la cola de envíos y engancho `worker.on('failed')` con `job.attemptsMade >= 5` a un dead-letter store. Te lo diría así:
  > Hay BullMQ en el repo. No reinvento la rueda: uso su backoff nativo (5 intentos, exponencial desde 1s) y engancho el evento `failed` al dead-letter. Sigo.
- **Hay Redis/DB pero no cola:** el store de reintentos y el de dead-letter los implemento sobre eso (tabla/hash `notification_retries` y `notification_dead_letters`).
- **No hay nada de persistencia (caso más probable en un servicio pequeño):** scheduler en memoria con timers + store en memoria detrás de una interfaz, para cambiarlo luego sin tocar la lógica. Te lo diría así:
  > Visto el repo: el envío sale de `src/<archivo>.js` → `provider.send()`, sin cola ni persistencia. Voy con scheduler en memoria (timers) + dead-letter en memoria con interfaz para pasarlo a Redis/DB luego. Parámetros: 1s base, ×2, tope 60s, jitter. Un reinicio del proceso pierde los reintentos pendientes; lo dejo apuntado. Sigo.

El resto lo describo para este tercer caso, que es el que requiere más trabajo.

## Paso 2 — Decisiones que tomo sin preguntarte

| Decisión | Valor | Por qué |
|---|---|---|
| Intentos totales | 5 (1 inicial + 4 reintentos) | Tu spec |
| Delays (sin jitter) | 1s, 2s, 4s, 8s | `base × 2^(n-1)`, tope 60s |
| Jitter | "equal jitter": entre 50% y 100% del delay | Evita thundering herd; desactivable en tests |
| Qué se reintenta | Todo error, salvo que `isRetryable(err)` diga que no (default: todo) | Cumple tu spec literal; el hook queda para 4xx/destinatario inválido |
| Dead-letter | Registro `{ id, notification, attempts, lastError, firstFailedAt, deadLetteredAt }` + evento `'dead-letter'` | Para que engancháis alerting sin tocar el módulo |
| Config | `RETRY_MAX_ATTEMPTS`, `RETRY_BASE_MS`, `RETRY_FACTOR`, `RETRY_MAX_MS` | Siguiendo el patrón de env que tenga el repo |
| Git | No commiteo a `main` sin que lo pidas | Cambios quedan en el working tree; te ofrezco commit en rama al final |

## Paso 3 — Implementación (archivos que escribo)

**`src/retry/backoff.js`** — función pura:
```js
export function computeDelay(attempt, { baseMs = 1000, factor = 2, maxMs = 60_000, jitter = true, random = Math.random } = {}) {
  const raw = Math.min(maxMs, baseMs * factor ** (attempt - 1));
  return jitter ? Math.floor(raw / 2 + random() * (raw / 2)) : raw;
}
```

**`src/retry/deadLetter.js`** — `InMemoryDeadLetterStore` con `add(record)`, `list()`, `get(id)`, `remove(id)`. Interfaz documentada en JSDoc para la versión Redis/DB.

**`src/retry/retryQueue.js`** — `class RetryQueue extends EventEmitter`:
- `constructor({ send, maxAttempts = 5, backoff = {}, isRetryable = () => true, deadLetter, logger, setTimeoutFn, clearTimeoutFn })` — timers inyectables para tests.
- `enqueue(notification)` → ejecuta el intento 1 inmediatamente, devuelve `id`.
- `#attempt(job)` → `try { await send(job.notification); emit('sent') } catch (err) { si attempt < maxAttempts && isRetryable(err) → programa siguiente con computeDelay(attempt); si no → deadLetter.add(...) + emit('dead-letter') }`.
- `close()` → cancela timers pendientes (para shutdown limpio).
- `pending()` → nº de jobs en espera (útil para tests y health).
- Logs en cada reintento con `attempt`, `delayMs`, `err.message`.

**Integración** — en el módulo de envío existente: donde hoy se llama `provider.send(n)`, se pasa a `retryQueue.enqueue(n)`, manteniendo la firma pública que ya use el servicio. La instancia se crea en el arranque leyendo la config, y `close()` se engancha al shutdown si el repo ya tiene hook de `SIGTERM`.

**`.env.example`** (si existe) — añado las 4 variables con sus defaults.

## Paso 4 — Tests (`node:test` + `t.mock.timers`)

**`test/retry/backoff.test.js`**
- Secuencia sin jitter para intentos 1..5 = `[1000, 2000, 4000, 8000, 16000]`.
- Tope: con `maxMs: 5000`, el intento 5 devuelve 5000.
- Jitter: con `random` fijo, el valor cae en `[raw/2, raw]`.

**`test/retry/retryQueue.test.js`** (con `t.mock.timers.enable({ apis: ['setTimeout'] })` y `jitter: false`)
- Éxito al primer intento → `send` llamado 1 vez, `pending() === 0`, no dead-letter.
- Falla 2 veces y luego OK → `send` llamado 3 veces; verifico que el 2º intento **no** ocurre antes de `tick(999)` y **sí** tras `tick(1)`; ídem 2000ms para el 3º.
- Falla 5 veces → `send` llamado exactamente 5 veces, evento `dead-letter` con `attempts === 5` y `lastError.message === 'boom'`; tras `tick(60_000)` sigue en 5 (no hay 6º).
- `isRetryable: () => false` → dead-letter tras 1 intento.
- `close()` con reintentos pendientes → `send` no vuelve a llamarse.
- Dos notificaciones en paralelo → contadores independientes.

**Integración** — si el módulo de envío tiene test, añado un caso: proveedor que falla una vez → la notificación acaba enviada.

## Paso 5 — Verificación

1. `npm test` (o el script que tenga el repo). Si hay `lint`, también.
2. Releo el diff completo (`git diff`) antes de reportarte.
3. Si algo falla, lo arreglo y vuelvo a correr; no te reporto hasta que esté verde o esté bloqueado.

Según tu modo de permisos verás prompts de Write/Edit y del `npm test`; en auto-accept no verás nada entre el mensaje de exploración y el final.

## Mensaje final (literal, con `<…>` donde va lo real)

> Listo. Retry con backoff exponencial + dead-letter a los 5 intentos.
>
> **Archivos:** nuevos `src/retry/{backoff,deadLetter,retryQueue}.js`, tests en `test/retry/`; modificado `src/<envío>.js` (ahora pasa por `retryQueue.enqueue`), `.env.example`.
>
> **Tests:** `npm test` → `<N> pass, 0 fail` (salida pegada abajo).
>
> **Decisiones que tomé, cámbialas si no te cuadran:**
> - Delays 1s/2s/4s/8s con jitter 50–100%, tope 60s. Todo por env (`RETRY_*`).
> - Se reintenta cualquier error; hay hook `isRetryable(err)` si quieres cortar 4xx en seco.
> - Dead-letter en memoria + evento `'dead-letter'` para alertas. **Un reinicio pierde los reintentos pendientes** — el store tiene interfaz para pasarlo a Redis/DB; es la siguiente pieza si esto va a prod.
>
> **No hice:** commit (queda en working tree), persistencia, alerting. Si quieres, hago commit en `feat/retry-backoff` o monto el store sobre Redis.

Lo único que me haría parar y preguntarte a mitad: encontrar que el envío ya pasa por una cola con su propio retry configurado de forma distinta a tu spec (p.ej. 3 intentos) — ahí sí te diría "¿piso la config existente o la respeto?", porque son dos trabajos distintos.
