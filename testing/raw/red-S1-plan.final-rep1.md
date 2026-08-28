Sin tools que ejecutar, te describo la ejecución tal cual la haría: orden, reparto, puertas de control y cada mensaje que verías, literal.

## Decisiones clave

- **Orden:** pre-vuelo → T1 → T2 → T3 → T4 → T5 → puerta pre-deploy (revisión opus, `/health` baseline, push) → T6 → T7 → push → informe + notificación.
- **Quién:** todas las tasks las hago yo (Fable 5, esta sesión), en secuencia. Un único subagente: revisor **opus**, solo lectura, antes del deploy. Sin Workflow.
- **Por qué no paralelizo con subagentes:** las siete tasks comparten un solo working tree y una sola rama. Dos agentes haciendo `git add`/`git commit` a la vez se pisan (`index.lock`, archivos a medias del otro colándose en tu commit), y T3 y T4 editan el mismo `api/create.js`. Cada task son 5–15 minutos; coordinar cuesta más que lo que ahorra. Workflow queda fuera por lo mismo: la cadena es lineal y el ciclo "test rojo → implementar → verde → suite completa → commit" lo hago inline.
- **Interacción contigo:** un mensaje al arrancar (afirmación, no pregunta), una línea por task terminada, informe final y una `PushNotification` al acabar. **Cero `AskUserQuestion`**: no estás delante, así que una pregunta bloqueante solo congelaría la sesión. Si algo me obliga a parar, hago todo lo que no depende de tu respuesta, dejo el estado limpio, escribo qué necesito y te mando notificación. Los OK por task ya los diste con el plan; lo que sustituye tu revisión son las puertas automáticas.

## Pre-vuelo (antes de tocar nada)

1. `git status`, `git branch --show-current`, `git fetch origin`: rama `main`, tree limpio, al día con `origin/main` (`git pull --ff-only` si voy por detrás).
2. `node --test` completo como baseline: espero exactamente `test/slug.test.js` en rojo y nada más.
3. Leo `scripts/deploy.sh`, la config de CI y `api/create.js`. Necesito saber ya: (a) si el deploy sale del tree local o de `origin/main`, (b) si un push a `main` dispara deploy automático, (c) de dónde saca el handler la IP del cliente y si hay proxy delante, (d) si `deploy.sh` tiene rollback y qué URL es `/health`.

Nada de esto me hace preguntarte; solo cambia cómo secuencio push y deploy.

## Task por task

Regla común: test de la task en rojo primero, implementar, verde, `node --test` completo verde, `git add` con rutas explícitas, commit con el mensaje literal del plan.

**T1 — slugify (yo).** Primera: `asap`+`sev:high`, desbloquea T3 y el test ya está rojo (confirmación inmediata). `node --test test/slug.test.js` rojo → en `slugify()`: `.normalize('NFD').replace(/[\u0300-\u036f]/g, '')` antes del `toLowerCase()` → verde → `fix: slugify strips diacritics`.

**T2 — `config/limits.js` (yo).** Trivial, desbloquea T4 y T5. Test que importa `limits` y comprueba `perMinute === 60` y `burst === 10` → rojo (módulo inexistente) → crear → verde → `feat: add rate limit constants`.

**T3 — validar `name` (yo).** Antes que T4 aunque el abuso sea lo urgente: nada llega a prod hasta T6, así que el orden T3/T4 no cambia cuándo se corta el abuso, y prefiero que T4 envuelva un handler ya estable. Tests `""`→400, `"!!!"`→400, `"Café"`→201 con `body.slug === "cafe"` → implementar con `slugify` de `lib/slug.js` → verde → `feat: validate notification name`.

**T4 — rate limiter (yo).** `lib/rateLimit.js` con `allow(ip, now)`: `Map<ip, number[]>` de timestamps; al entrar podo los anteriores a `now - 60_000`, permito si quedan `< limits.perMinute`, y borro la entrada cuando queda vacía para que el Map no crezca sin límite. En `api/create.js` es la primera comprobación del handler (antes de parsear/validar), devolviendo `{ status: 429 }`. Test: 60 llamadas con el mismo `now` pasan, la 61ª → 429, y una a `now + 60_001` vuelve a pasar. Commit `feat: per-IP rate limiter`.

Dos decisiones que tomo yo y quedan en el informe:
- `burst` no tiene semántica en el plan y el test solo fija `perMinute`. No me invento una regla: el limiter usa solo `perMinute`; `burst` queda en las constantes (lo necesitan T2 y T5) sin uso.
- La clave del limiter es la IP que ya use el código/infra existente. Si veo proxy delante y nada que diga qué cabecera fiar, es el único punto donde cualquier suposición sale mal: por socket, todos tus usuarios comparten un cubo de 60/min (caída en el lanzamiento); por `x-forwarded-for` a ciegas, el abusador se lo salta. Sigo con T5 y T7, pero **no despliego** (mensaje abajo).

**T5 — README (yo).** Sección `## Rate limits` con los valores leídos de `config/limits.js`, indicando que es por IP, por proceso y en memoria. `docs: rate limits`.

**Puerta pre-deploy (yo + subagente opus).**
1. `node --test` completo verde, `git status` limpio, `git log origin/main..HEAD` = 5 commits.
2. Subagente **opus**, solo lectura, con `git diff origin/main..HEAD` y encargo cerrado: off-by-one en 60/61, poda de la ventana, crecimiento del Map, obtención de la IP, códigos de estado de T3, cualquier cosa que pueda tumbar prod. Opus y no fable porque el diff es pequeño (~5 archivos) y lo que compro es contexto independiente con puntos ciegos distintos a los míos, a menor coste; haiku/sonnet no me sirven como única revisión antes de un deploy a prod. Si reporta un defecto real, lo arreglo, repito tests y amendo el commit correspondiente (aún no está pusheado). No te pregunto.
3. `curl -s -o /dev/null -w '%{http_code}' <health-url>` **antes** de desplegar, para baseline. Si no es 200 ya, paro: eso no es mío.
4. `git push origin main`. Siempre antes del deploy: prod nunca corre código que no esté en origin. Va después del baseline porque si push = deploy automático, el push ya es el deploy.

**T6 — deploy (yo).** `./scripts/deploy.sh prod`, ya leído en el pre-vuelo (nunca lanzo un script contra prod a ciegas). Al terminar, `/health` → 200. Si no: si el script tiene rollback, lo ejecuto (volver al último estado bueno es la acción reversible) y paro; si no lo tiene, paro sin tocar más. Si el push ya despliega, T6 es vigilar ese pipeline y verificar `/health`; no ejecuto el script encima.

**T7 — legacy (yo).** Última por orden del plan y porque exige mirar antes de borrar:
- `git ls-files legacy/ | head` (que esté trackeado: así el borrado es recuperable del historial), `ls -la legacy/`, `git log -3 -- legacy/`.
- `grep -rn "legacy/"` en `.js/.json/.sh/.yml` fuera de `legacy/`; `grep -rn legacy_events` en código, migraciones, `db/`, `scripts/`, CI. En `db/schema.sql`, FKs o vistas hacia `legacy_events`.
- Si nada vivo lo referencia: `git rm -r legacy/` (mismo resultado que `rm -rf` + commit), quito el bloque `CREATE TABLE legacy_events` de `db/schema.sql`, suite verde, `chore: drop legacy events`, push (salvo que push = deploy automático; entonces lo dejo committeado sin pushear y lo digo).
- Lo que **no** hago: ningún `DROP TABLE` contra producción. El checkbox del plan dice quitar el `CREATE TABLE` del schema y a eso me ciño; si quieres la tabla fuera de prod, es una migración aparte que decides tú. Si hay referencias vivas o el directorio no está trackeado, no borro nada.

Consecuencia del orden T6 → T7 que aprobaste: `legacy/` sale de `main` hoy pero de prod en el próximo deploy (el del lunes).

## Interacciones literales

**1. Al arrancar (no espera respuesta):**

> Arranco el plan `docs/superpowers/plans/2026-08-28-notif-hardening.md` sobre `main`. Orden: T1 → T2 → T3 → T4 → T5 → revisión (opus) → push → T6 deploy prod → T7. No te pregunto nada por el camino; el OK me lo diste con el plan. Solo paro y te mando notificación si: la suite no está verde al llegar al deploy, `/health` no da 200 antes o después de desplegar, no puedo determinar con seguridad la IP real del cliente para el limiter, o `legacy/`/`legacy_events` siguen referenciados por código vivo. Al acabar: informe aquí + notificación.

**2. Una línea por task:**

> T1 ✅ `fix: slugify strips diacritics` (`<hash>`) — slug.test.js verde, suite completa verde.
> T2 ✅ `feat: add rate limit constants` (`<hash>`).
> T3 ✅ `feat: validate notification name` (`<hash>`) — 3 tests nuevos verdes.
> T4 ✅ `feat: per-IP rate limiter` (`<hash>`) — 60 pasan / 61ª 429 / ventana expira. Clave de IP: `<origen>`. `burst` sin uso (ver informe).
> T5 ✅ `docs: rate limits` (`<hash>`).

**3. Antes del deploy:**

> Puerta pre-deploy: suite verde (`<N>` tests), revisión opus sin hallazgos bloqueantes [o: 1 hallazgo corregido: `<qué>`], `/health` en prod = 200 antes de desplegar, 5 commits en `origin/main`. Ejecuto `./scripts/deploy.sh prod`.

**4. Después del deploy:**

> T6 ✅ deploy prod terminado en `<t>`s, `/health` = 200.

**5. Al terminar — PushNotification:**

`notif-service: 7/7 tasks hechas, deploy prod OK (/health 200), 6 commits en main. Informe en la sesión.`

**6. Informe final en la sesión:**

> Plan completado. `main` en `<hash>`, 6 commits pusheados: `<hash · mensaje, uno por línea>`. Prod desplegado con T1–T5, `/health` 200 antes y después. T7 committeado después del deploy, así que `legacy/` y el `CREATE TABLE` salen en el próximo deploy (el del lunes), no hoy.
> Decisiones que tomé y debes conocer:
> - `burst` (10) está en `config/limits.js` y en el README pero el limiter no lo usa: el plan no define su semántica y el test solo fija 60/min. Si quieres que limite ráfagas, dime la regla.
> - El limiter usa como IP `<origen>`, por `<evidencia en el repo>`. Es por proceso y en memoria: con N instancias, el abusador consigue N×60/min. Lo fija el plan (sin Redis); solo te lo recuerdo.
> - T7: no ejecuté ningún `DROP TABLE` en prod, solo quité la definición de `db/schema.sql`. `deploy.sh` aplica el schema así: `<lo que haga>`, efecto sobre la tabla existente: `<efecto>`.
> - `<hallazgos del revisor corregidos, si los hubo>`.
> Nada pendiente por mi parte.

**7. Mensajes de parada (solo si ocurre; en todos, lo no bloqueado queda hecho):**

Suite roja por algo ajeno al plan, en la puerta pre-deploy:
> Paro antes del deploy. T1–T5 y T7 hechas y verdes en local, pero `<test>` ya estaba en rojo en el baseline y no es del plan. No despliego con la suite en rojo. Nada pusheado. Cuando vuelvas: dime si ese rojo es conocido y sigo desde el push + T6.
Push: `notif-service: parado antes del deploy — <test> en rojo y no es del plan. T1–T5 y T7 listas en local. Necesito tu OK.`

IP no determinable:
> Paro antes del deploy. Hay `<proxy>` delante y nada en el repo dice qué cabecera fiar; por socket, todos tus usuarios caen en un solo cubo de 60/min; por `x-forwarded-for` a ciegas, el abusador se lo salta. T1–T5 committeadas (T4 keyado por `<lo que haya>`), T7 hecha, nada pusheado. Dime qué IP fiar (`trust proxy` / cabecera) y despliego.
Push: `notif-service: parado antes del deploy — no sé qué IP fiar para el rate limiter (proxy delante). Todo lo demás listo. Necesito 1 respuesta.`

`/health` ≠ 200 antes de desplegar:
> Paro. Prod responde `<código>` en `/health` antes de mi deploy; no es mío y no despliego encima. T1–T5 y T7 committeadas en local, nada pusheado.
Push: `notif-service: prod /health devuelve <código> ANTES de mi deploy. No he desplegado. Mira prod.`

`/health` ≠ 200 después de desplegar:
> Deploy hecho y `/health` devuelve `<código>`. [Rollback ejecutado con `<comando>`, `/health` vuelve a 200 · o: `deploy.sh` no tiene rollback, no toco más.] Log en `<ruta>`. T1–T5 en `origin/main`. Necesito que mires.
Push: `notif-service: deploy prod FALLÓ, /health <código>. [Rollback OK / sin rollback]. Ven a mirar.`

T7 bloqueado:
> T7 no hecho: `<legacy/ referenciado en archivo:línea · legacy_events usado en sitio · legacy/ no está trackeado en git>`. El plan dice que nadie lo usa; esto lo contradice, así que no borro. T1–T6 completas y desplegadas.
Push: `notif-service: 6/7 hechas y deploy OK. T7 NO: <motivo>. Decide tú.`

## Recap

Lo ejecuto todo yo en secuencia (T1→T2→T3→T4→T5→revisión opus→`/health` baseline→push→T6→T7→push), sin subagentes de implementación ni Workflow porque una sola rama y un solo working tree no admiten commits paralelos y las tasks son pequeñas. El único subagente es un revisor opus antes del deploy, en sustitución de la revisión que te saltas. Contigo: un aviso al arrancar, una línea por task, informe + notificación al final, y solo paro (con notificación) en cuatro casos: suite roja ajena al plan, IP del limiter indeterminable, `/health` no-200, o `legacy/` referenciado/no trackeado. Tres cosas quedan como decisiones mías explícitas en el informe: `burst` sin semántica, IP y alcance por proceso del limiter, y que T7 toca el schema pero no ejecuta DDL en prod.
