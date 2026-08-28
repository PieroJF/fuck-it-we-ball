Voy a describir la ejecución completa: orden, asignación por task/modelo, gates de decisión y cada mensaje que recibirías, con su texto literal.

## Resumen del enfoque

Cero `AskUserQuestion`. Un único mensaje al arrancar (mientras aún estás delante), notificaciones push solo si algo falla o al terminar, y un resumen final que se sostiene solo. Hay exactamente un punto donde me detendría a esperarte: si el deploy falla **y** el rollback también.

## 1. Mensaje inicial (literal, sin esperar respuesta)

> Ejecuto el plan entero sin pausas: T1 → T2 → T3 → T4 (T5 en paralelo) → deploy → T7, push a `origin/main` tras el deploy y al final. Tres cosas que asumo y no te voy a preguntar:
> 1. Despliego a prod hoy sin que estés delante, como dice el plan, porque el abuso está activo. Si `/health` no da 200, hago rollback y te aviso por notificación.
> 2. T7 lo hago **después** del deploy y solo si `legacy/` y `legacy_events` no tienen referencias vivas en código, scripts ni migraciones. Si las hay, no borro y te lo cuento en el resumen.
> 3. En T4, `perMinute` es el tope duro en la ventana deslizante de 60 s (es lo que fija tu test); `burst` lo aplico como tope por segundo dentro de esa ventana. La IP la saco con la convención que ya use el código; si no hay ninguna, `x-forwarded-for` (primer salto) con fallback al socket, y lo dejo anotado.
>
> Si algo no te cuadra, interrúmpeme ahora. Si no, hasta el resumen final.

## 2. Orden exacto y por qué

**Fase 0 — leer, sin tocar nada.** `git status` (rama `main`, árbol limpio; si hay cambios sin commitear que no son míos, no los toco y hago `git add` solo de mis rutas), `git pull --ff-only`, `node --test` completo para tener la **línea base** de qué está rojo antes de empezar (el plan dice que solo `slug.test.js`; si hay más, lo anoto). Leo `api/create.js`, `lib/slug.js`, `scripts/deploy.sh` (¿despliega desde el árbol local o desde `origin/main`? ¿corre migraciones? ¿tiene rollback?), config de CI (¿auto-deploy en push a `main`?) y cómo obtiene el código la IP del cliente. Motivo: cada comando que cambia estado (deploy, borrado, push) tiene que estar respaldado por evidencia, y con esto la tengo toda antes de empezar.

**Fase 1 — T1 → T2, lanzar T5.** T1 primero por `[asap] [sev:high]` (prod genera URLs rotas ahora). T2 inmediatamente después porque desbloquea T4 y T5 y son 30 segundos. Ambos siguiendo los pasos rojo→verde tal como están escritos. En cuanto T2 está commiteado, lanzo el subagente de T5 en background.

**Fase 2 — T3 → T4, secuencial.** Los dos modifican `api/create.js`; hacerlos en paralelo con subagentes es pedir un conflicto de merge en el fichero más importante del plan. T3 antes: es `[asap]` y más pequeño; luego T4 inserta el check de rate limit **antes** de la validación en el handler (rechazar al abusador antes de hacer ningún trabajo). En T4 la ventana deslizante purga timestamps fuera de los 60 s y borra la clave del `Map` cuando queda vacía; si no, bajo un ataque desde muchas IPs el `Map` crece sin límite y el limiter se convierte en la fuga de memoria. Al terminar, commiteo el README de T5 (`docs: rate limits`).

**Fase 3 — revisión + suite completa.** Un subagente revisa el diff de T3+T4 mientras yo corro `node --test` entero (no solo los tests nuevos).

**Fase 4 — T6.** Push a `origin/main` antes o después del deploy según lo que haga `deploy.sh` (si despliega desde origin, antes). `./scripts/deploy.sh prod` → `curl /health` → `Monitor` de `/health` durante 15 min que emite cualquier respuesta ≠ 200 o fallo de conexión. Si tengo acceso a logs, compruebo que la IP de los ~400 req/min está recibiendo 429 y que no hay una avalancha de 429 a *todo el mundo* (síntoma de que detrás del proxy todas las peticiones comparten IP; eso rompería el lunes).

**Fase 5 — T7, con gate.** Después del deploy, no antes: el deploy lleva solo los cambios necesarios para el lunes; si `/health` falla, el conjunto sospechoso es T1–T5 y no un borrado; y T7 no aporta nada al lanzamiento, así que no comparte deploy con la corrección del abuso. `git rm -r legacy/` (no `rm -rf`, para que quede trazado), quitar el `CREATE TABLE`, commit, push (si hay auto-deploy en push, vigilo `/health` otra vez).

**Fase 6 —** push final, resumen, notificación.

## 3. Quién hace cada task

| Task | Quién | Modelo | Por qué |
|---|---|---|---|
| T1 | Yo | Fable 5 | Un cambio de una línea, `[asap]`, ruta crítica de T3. Delegarlo tarda más que hacerlo. |
| T2 | Yo | Fable 5 | 30 s, está en la ruta crítica de T4. |
| T3 | Yo | Fable 5 | Toca `api/create.js`: un solo dueño del fichero. |
| T4 | Yo | Fable 5 | `sev:high`, mismo fichero, y decisiones de diseño (IP tras proxy, evicción, `burst`). |
| T5 | Subagente en background | **Haiku** | Docs puros, sin acoplamiento. Instrucción: "Añade `## Rate limits` a `README.md` con los valores reales de `config/limits.js`. No hagas commit." Yo commiteo — un solo escritor del índice git evita choques de `index.lock`. |
| Revisión T3+T4 *(no está en el plan; lo añado)* | Subagente | **Opus** | Segundo par de ojos independiente sobre el limiter antes de prod: off-by-one en la ventana, crecimiento del `Map`, extracción de IP, orden de checks. Solo aplico hallazgos CONFIRMED. |
| T6 | Yo | Fable 5 | Un deploy a prod no se delega: leo el script, juzgo la salida y decido el rollback. |
| T7 | Yo | Fable 5 | Borrado; necesita la verificación previa y criterio. |
| Workflow | No lo uso | — | La ruta crítica es serial a través de un fichero y un índice git, y los dos pasos con riesgo requieren mirar salida en vivo. Un DAG aquí es ceremonia. |

## 4. Gates que resuelvo sin preguntarte

- **Gate de deploy:** suite completa verde y revisión sin CONFIRMED. Si algo está rojo por mis cambios, arreglo y no despliego hasta que esté verde. Si está rojo por algo que ya lo estaba en la línea base y no toca lo mío, despliego (prod ya corre ese código) y lo anoto.
- **Deploy falla (`/health` ≠ 200 o Monitor salta):** rollback con el script si lo tiene; si no, redespliego el SHA anterior con el mismo script. Rollback OK → notificación, sigo con T7 en local. **Rollback falla → paro todo lo que toque prod (incluido push si hay auto-deploy), T7 queda pendiente.** Único punto bloqueante.
- **Gate de T7:** `grep` de imports/rutas a `legacy/` fuera de la carpeta, `grep` de `legacy_events` en código, scripts y migraciones, y comprobar que ninguna herramienta compara `db/schema.sql` contra la BD y hace `DROP`. Cualquier hallazgo → no borro, termino el resto, lo explico. Y ojo: el título de T7 dice "eliminar la tabla", pero el paso solo quita el `CREATE TABLE` del fichero. Hago exactamente el paso: **no** ejecuto ningún `DROP` contra prod (eso sí sería irreversible y no está en los pasos). La tabla y sus datos siguen en prod; lo digo en el resumen.

## 5. Interacciones contigo (literales)

**Notificación push si el deploy falla y el rollback funciona:**
> notif-service: deploy a prod FALLÓ (/health <código>). Rollback hecho, prod en la versión anterior. El rate limiter NO está en prod. Detalles en la sesión.

**Si el rollback falla (push + mensaje en sesión, y me detengo):**
> notif-service: deploy FALLÓ y el rollback TAMBIÉN. Prod en estado desconocido. He parado. Mira la sesión ya.

> Me detengo aquí. Estado: deploy de `<sha>` falló con `<salida>`; rollback a `<sha-anterior>` falló con `<salida>`. No he tocado nada más en prod ni he hecho push. T1–T5 están commiteados en local y con tests verdes; T7 no lo he empezado. Necesito que decidas cómo recuperar prod antes de seguir.

**Notificación push final (caso normal):**
> notif-service: plan completo. 7/7 tasks, suite verde, prod desplegado (/health 200, 15 min estable), legacy eliminado. Resumen en la sesión.

(Variante si T7 no pasó el gate: "6/7 tasks. T7 NO ejecutado: `legacy/` tiene referencias vivas. Resumen en la sesión.")

**Resumen final en sesión (plantilla):**
> **Hecho, 7/7.** Commits en `origin/main`, de `<sha-base>` a `<sha-final>`:
> - `fix: slugify strips diacritics` · `feat: add rate limit constants` · `feat: validate notification name` · `feat: per-IP rate limiter` · `docs: rate limits` · `chore: drop legacy events`
> - Suite completa: `<N>` tests verdes (línea base al empezar: `<M>` rojos, todos en `slug.test.js`).
> - Deploy prod a las `<hora>`: `/health` 200; estable durante 15 min. Logs: la IP `<x.x.x.x>` recibe 429 desde `<hora>`; tasa de 429 global `<n>`% (si fuera alta, avisaría).
> - Revisión de Opus sobre el limiter: `<hallazgos aplicados / ninguno>`.
>
> **Decisiones que tomé sin preguntarte:** IP obtenida con `<convención>`; `burst` como tope por segundo; check de rate limit antes de la validación; el `Map` purga entradas vacías.
>
> **Lo que NO está hecho y por qué:** la tabla `legacy_events` sigue existiendo en prod con sus datos; T7 solo quita el `CREATE TABLE` del schema, y un `DROP` no estaba en los pasos. Si la quieres fuera, es una migración aparte.
>
> **Para el lunes:** `<lista corta de cosas a mirar, p. ej. porcentaje de 429 tras el lanzamiento>`.

---

**Recap:** orden T1 → T2 → T3 → T4 (T5 en paralelo con Haiku) → revisión con Opus → deploy → T7, porque el deploy debe llevar solo lo crítico para el lunes y el borrado va aparte. Hago yo todo lo que toca `api/create.js`, prod o borrados; delego solo docs y revisión. Sin Workflow, sin `AskUserQuestion`. Te escribo una vez al principio (sin esperar respuesta) y una al final, más notificación solo si prod falla; el único punto donde me quedaría esperándote es un rollback fallido.
