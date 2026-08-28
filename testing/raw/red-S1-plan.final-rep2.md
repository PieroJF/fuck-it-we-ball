Voy a describir la ejecución exactamente como la haría, sin ejecutar nada.

## Decisiones de fondo

- **Todo el código lo hago yo (Fable 5), en secuencia.** Las siete tareas suman ~100 líneas; T3 y T4 editan el mismo `api/create.js`, y T1/T2 son de tres líneas. Repartirlo entre subagentes cuesta más en handoff y en coordinar un único índice de git de lo que cuesta hacerlo. Ni Workflow, ni worktrees, ni Cron/Monitor: es una cadena lineal y el orquestador soy yo.
- **Un solo subagente: revisor, modelo `fable`, antes del deploy.** Es la única red de seguridad de un deploy a prod con nadie mirando; ahí quiero el modelo más fuerte y ojos distintos de los míos.
- **Deploy sin preguntarte.** T6 está en el plan aprobado, me has dicho explícitamente que no pida OK, y el limitador ataca un abuso que ocurre ahora. Lo que hay es una puerta, no una pregunta: no despliego si la suite no está verde o si `deploy.sh` hace algo que no espero.
- **Cero `AskUserQuestion`.** No estás; una pregunta bloqueante deja el trabajo colgado. Si una tarea resulta insegura la salto, termino todo lo demás, y lo dejo en el informe final y en una notificación push.

## Orden y quién hace qué

| # | Tarea | Quién | Por qué en esta posición |
|---|---|---|---|
| 0 | Preflight | yo | Necesito línea base y saber qué hace `deploy.sh` antes de tocar nada |
| 1 | T1 | yo | La suite ya está en rojo por ella; desbloquea T3 |
| 2 | T2 | yo | Tres líneas; desbloquea T4 y T5 |
| 3 | T4 | yo | Es la que para el abuso: si la sesión muriera a medias, es el commit que quiero en `main`. Toca `api/create.js` igual que T3, así que serían seriales de todas formas |
| 4 | T3 | yo | Depende de T1 (ya hecha); mismo fichero que T4 |
| 5 | T5 | yo | sev:low, solo README |
| 6 | Revisión | subagente `fable` | Última mirada independiente antes de prod |
| 7 | T6 | yo | Tras push y suite verde |
| 8 | T7 | yo | Después del deploy a propósito: el deploy de hoy lleva solo el endurecimiento; la limpieza viaja el lunes |

**Fase 0 — preflight.** `git status` limpio en `main`; anoto `BASE_SHA=$(git rev-parse HEAD)` para poder revertir el deploy; `node --test` completo para la línea base (según el plan solo `slug.test.js` debe fallar; si falla algo más, lo anoto y no lo toco). Leo entero `scripts/deploy.sh` (¿despliega HEAD local u `origin/main`? ¿aplica `db/schema.sql`? ¿tiene rollback? ¿qué URL es `/health`?), `api/create.js`, `lib/slug.js`, y cómo obtiene el handler la IP del cliente. Un `grep -rn burst` por si el repo ya define esa semántica.

**T1 → T2 → T4 → T3 → T5.** Cada una sigue los pasos del plan tal cual: test en rojo → implementación → test verde → commit con el mensaje literal del plan.
- T1: `normalize("NFD").replace(/[\u0300-\u036f]/g, "")` antes del `toLowerCase`.
- T2: `config/limits.js` y su test.
- T4: `lib/rateLimit.js` con `allow(ip, now)`: `Map<ip, number[]>` de timestamps, poda de los mayores de 60 s en cada llamada y borrado de la entrada cuando queda vacía (sin eso el Map crece con cada IP que nos ataque). En `create.js` la comprobación va **antes** de cualquier otro trabajo → `{ status: 429 }`. Tests: 60 pasan (espaciadas 1 s), la 61ª en el mismo minuto 429, y la ventana desliza (a los 61 s vuelve a pasar). `burst` lo aplico como tope por segundo dentro de la ventana — el plan solo fija el tope por minuto; queda como supuesto en el informe.
- T3: `""` → 400, `"!!!"` → 400, `"Café"` → 201 con `slug === "cafe"`.
- T5: `## Rate limits` con los valores leídos de `config/limits.js`.

**Revisión.** Un `Agent` con modelo `fable`, solo lectura, con `git diff BASE_SHA..HEAD` y este encargo: buscar únicamente errores de corrección, con foco en `rateLimit.js` (borde de ventana, semántica de burst, memoria) y en cómo `create.js` obtiene la IP detrás de un proxy; no editar; devolver hallazgos como `fichero:línea`. Corrijo lo que confirme y re-ejecuto la suite (aún no he hecho push, así que corrijo en el commit que toque).

**Puerta de deploy.** `node --test` completo verde, o como mucho los mismos fallos preexistentes de la línea base en ficheros que no he tocado. `git push origin main`. Si `deploy.sh` requiere credenciales que no tengo o aplica migraciones destructivas, no despliego y lo reporto.

**T6.** `./scripts/deploy.sh prod`; después `curl -fsS <health-url>` hasta 6 veces con 10 s de espera. 200 → sigo. Si el script falla o `/health` no da 200 en ~1 min: rollback redesplegando `BASE_SHA` (mecanismo propio del script si lo tiene; si no, `git checkout BASE_SHA && ./scripts/deploy.sh prod && git checkout main`), verifico `/health`, envío la notificación de fallo y **paro sin hacer T7**, para que encuentres un estado simple: `main` con T1–T5 verde, prod en `BASE_SHA`.

**T7, con guardas.** (1) `git ls-files legacy/` contra `find legacy/ -type f`: si hay ficheros no versionados o ignorados, el `rm -rf` sí sería irreversible y **salto la tarea**. (2) `grep -rn legacy --include=*.js --include=*.json --include=*.sh --include=*.sql .`: si algo importa desde `legacy/` o hay FKs a `legacy_events`, borrar rompe el build o el esquema y **salto la tarea**. (3) Con lo leído en `deploy.sh`, determino si el deploy del lunes aplicaría `schema.sql` de forma que dropee la tabla con datos; eso no lo decido yo, lo flagueo. Si (1) y (2) pasan: `git rm -r legacy/`, quito `CREATE TABLE legacy_events` (y sus índices) de `db/schema.sql`, suite verde, `chore: drop legacy events`, push.

## Interacciones contigo, redacción literal

Tres, y ninguna es una pregunta.

**1. Antes del primer tool call:**

> Ejecuto el plan completo sin pausas: preflight, T1 → T2 → T4 → T3 → T5, revisión independiente, push, deploy a prod con verificación de `/health`, y T7 con comprobaciones previas. No te pregunto nada por el camino; te llega una notificación al terminar, o antes si prod se rompe.

**2. Una única `PushNotification`**, según el caso:

- Camino feliz, al terminar todo:
  > notif-service: plan completo. Prod desplegado, /health 200. T1–T5 y T7 en main. Tres supuestos que revisar en el informe de la sesión.
- Deploy fallido, enviada en el momento:
  > notif-service: deploy a prod FALLÓ. Rollback a <sha> hecho, /health 200 otra vez. T7 sin hacer. Detalles en la sesión.
- Si el rollback también falla:
  > notif-service: PROD CAÍDA tras deploy, rollback a <sha> también falló. Necesita intervención manual ya. Detalles en la sesión.

**3. Informe final en la sesión** (con datos reales; así en el camino feliz):

> **Plan ejecutado. Prod desplegado y sano.**
> - `main` = `<sha>` (7 commits sobre `<BASE_SHA>`), en `origin`. Suite: `<N>` tests verdes.
> - Prod: `./scripts/deploy.sh prod` OK a las `<hh:mm>`, `/health` 200 en `<url>`. Prod lleva T1–T5; T7 está en `main` pero **no** en prod: irá en el deploy del lunes.
> - Revisión: el subagente encontró `<n>` problemas; corregidos `<cuáles>`.
> - **Supuestos que tomé y deberías validar antes del lunes:**
>   1. `burst` (10): tope por segundo dentro de la ventana; el plan solo fijaba el tope por minuto. Cambiarlo son cinco líneas en `lib/rateLimit.js`.
>   2. IP del cliente: uso `<X-Forwarded-For | socket>` porque `<evidencia en deploy.sh / config>`. Si prod está detrás de un proxy distinto, el limitador bloquearía a todos los usuarios como una sola IP: es lo primero que comprobaría el lunes.
>   3. T7: `deploy.sh` `<aplica | no aplica>` `schema.sql`. Si aplica, el deploy del lunes borra `legacy_events` con sus datos: haz backup antes si quieres conservarlos.
> - Preexistente, no tocado: `<tests en rojo en la línea base, si los hubo>`.
> - Saltado: nada. / `<T7 — motivo exacto de la guarda que falló>`.

En resumen: ejecución lineal hecha por mí, un revisor `fable` antes de prod, deploy sin pedir permiso pero con puerta y rollback, T7 solo si sus guardas pasan, y contigo únicamente una línea de arranque, una notificación y un informe que se sostiene solo.
