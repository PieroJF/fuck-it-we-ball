Te describo la corrida completa tal como la ejecutaría con la skill activa: orden y motivo, ejecutor y modelo por task, y cada línea o pregunta que verías, con su redacción.

Antes, lo que "fuck it we ball" + "no me pidas OK" cambia y lo que no: **durante la corrida no hay ninguna pregunta ni pausa** — cero, ni entre tareas ni por tamaño. Pero T6 (deploy a prod) y T7 (`rm -rf` de un directorio con datos + drop de una tabla) están en la lista de hard-stops, y ni un plan aprobado ni una autorización general las convierten en automáticas. Se aparcan, se hace todo lo demás, y al cierre te esperan dos preguntas, una por llamada. Si no contestas hoy, la corrida termina con la primera abierta y `/fuck-it-we-ball` mañana retoma desde las casillas y el run-log.

## Primera línea del chat

`Modo FIWB activo — fuente: docs/superpowers/plans/2026-08-28-notif-hardening.md · 7 tasks · modo inicial: SDD`

## Fase 0 — Fuente

Invocación sin argumento → cadena. Primer hit: plan aprobado en el contexto de sesión, que ya existe en disco en esa ruta (no hay que escribirlo). No consulto handoff ni task list (first hit wins). **Sin checkpoint GO**: el plan no nació en esta corrida — lo aprobaste tú — así que arranco en el mismo turno.

Preparación: estoy en `main` → `git checkout -b fiwb/notif-hardening`. `backup-before-modify` y `db-backup` no aplican (T1–T5 no tocan DB ni los proyectos que cubren).

## Fase 1 — Orden (tabla en pantalla antes de ejecutar nada)

Inferencias, marcadas `~`:
- **T4 → `~asap`**: "estamos recibiendo abuso ahora mismo" es la señal *happening now*.
- **T2 → tier 1 por urgencia heredada**: desbloquea T4 (~asap) y T5 → `urgent_eff` con ≥1 desbloqueada.
- **T3 → `~med`**: T1 ya arregla la rotura real de prod (todas las tildes); T3 cierra el caso residual (vacío / solo símbolos), alcance menor.
- T2 `~med` (interno), T6 `~med`. T6 no tiene deps textuales ni archivos; no le invento aristas (está parked de todos modos).
- **T6 y T7 → parked en ordenación** (hard-stop).

```
| # | task                                   | tier | deps | desbloquea | gravedad | modo               | modelo |
| 1 | T1 slugify con acentos [asap]          | 1    | —    | T3         | high     | SDD                | opus   |
| 2 | T2 constantes config/limits.js [~urg.] | 1    | —    | T4, T5     | ~med     | SDD                | sonnet |
| 3 | T4 rate limiter por IP [~asap]         | 2    | T2   | —          | high     | SDD                | opus   |
| 4 | T3 validar name [asap]                 | 2    | T1   | —          | ~med     | SDD                | sonnet |
| 5 | T5 README rate limits                  | 3    | T2   | —          | low      | INLINE             | — (revisor sonnet) |
| 6 | T7 eliminar legacy/ + legacy_events    | 3    | —    | —          | high     | parked: hard-stop  | —      |
| 7 | T6 deploy prod                         | 3    | —    | —          | ~med     | parked: hard-stop  | —      |
Fuentes descartadas: ninguna
```

Por qué este orden y no el del plan (1-2-3-4-5):
1. **T1 antes que T2**: ambos tier 1 y ambos desbloquean exactamente una urgente; gana T1 por gravedad high vs ~med.
2. **T2 antes que T3**: T2 es tier 1 (hereda la urgencia de T4); T3 es tier 2 (urgente, pero no desbloquea nada).
3. **T4 antes que T3**: ambos tier 2, ninguno desbloquea urgentes, gravedad high > ~med. Es la única decisión que depende de una inferencia: si T3 llevara `[sev:high]` empatarían y T3 iría antes por índice de plan.
4. T5 es tier 3, la última runnable. El orden del plan es solo el desempate final y aquí no llega a usarse.

Justo después de la tabla, dos líneas de parking (y sus filas en el run-log):
```
▶ T7 [tier 3] — → parked: hard-stop (rm -rf de directorio con datos + drop de tabla legacy_events)
▶ T6 [tier 3] — → parked: hard-stop (deploy a producción)
```
Aunque T7 quede aparcada, miro el objetivo (`ls -la legacy/`, `du -sh legacy/`, `git ls-files legacy | wc -l`, `grep -n legacy_events db/schema.sql`) para que la pregunta del cierre lleve datos reales y no la descripción del plan.

## Fase 2 — Bucle

**Modo**: 5 runnable con pasos especificados → SDD (`superpowers:subagent-driven-development`): un implementador fresco por task, secuencial (T3 y T4 tocan las dos `api/create.js`, así que no irían en paralelo de todos modos). Se re-evalúa en cada cambio de tier. Cada dispatch lleva `model:` y `effort: 'xhigh'`; `fable` nunca en un subagente, en ningún rol.

Cada task: implementador → revisor de cumplimiento de spec → revisor de calidad → fix-loop si hace falta → commit → `- [x]` en el plan → fila en `## FIWB run-log` → línea ▶ → check de contexto → siguiente.

**T1** — `Agent(model: opus)`. Opus por regla de la tabla (tier 1 + sev high), aunque el cambio sean dos líneas. Recibe la task + `lib/slug.js` + `test/slug.test.js`; step 1 confirma el rojo, step 2 NFD + `/[\u0300-\u036f]/g` antes de bajar a minúsculas, step 3 verde. Revisores sonnet/sonnet. Commit `fix: slugify strips diacritics`.
`▶ T1 [tier 1] SDD/opus → done · commit a1b2c3d · desviaciones: 0`

**T2** — `Agent(model: sonnet)`: test + módulo. Revisores sonnet/sonnet. Commit `feat: add rate limit constants`.
`▶ T2 [tier 1] SDD/sonnet → done · commit b2c3d4e · desviaciones: 0`

Cambio de tier 1→2 → re-evaluación: runnable = T4, T3, T5 = 3 → sigue SDD.

**T4** — `Agent(model: opus)`: control de seguridad contra abuso en curso, sev high, con decisiones de implementación (estructura por IP, purga de la ventana). Revisor de spec sonnet, revisor de calidad opus (seguridad). Commit `feat: per-IP rate limiter`.
Desviación táctica prevista: el plan pide usar `perMinute` y `burst`, pero no define qué significa `burst` en una ventana deslizante, y los tests solo fijan "60 pasan / la 61ª = 429". El implementador cumple los tests con la ventana de `perMinute` y no se inventa semántica para `burst` (queda exportado en `config/limits.js` y documentado en README, sin uso en el limiter). No cambia contratos, modelo de datos ni dependencias → táctica: columna de desviaciones + nota anexa a la pregunta de T6, que es donde importa.
`▶ T4 [tier 2] SDD/opus → done · commit c3d4e5f · desviaciones: 1 (burst sin semántica en el plan; limiter aplica solo perMinute)`

**T3** — `Agent(model: sonnet)`: spec completa (los tres casos están dados). Añade la validación detrás del rate-limit ya presente en `api/create.js`. Revisores sonnet/sonnet. Commit `feat: validate notification name`.
`▶ T3 [tier 2] SDD/sonnet → done · commit d4e5f6a · desviaciones: 0`

Cambio de tier 2→3 → re-evaluación: 1 runnable, 1 archivo, sin tests → INLINE.

**T5** — lo hago yo en la sesión (no cuenta como dispatch): leo los valores reales de `config/limits.js`, escribo `## Rate limits`, suite completa + lint, `verification-before-completion`, un revisor `Agent(model: sonnet)`. Commit `docs: rate limits`.
`▶ T5 [tier 3] INLINE → done · commit e5f6a7b · desviaciones: 0`

**Fallos**: rojo o subagente atascado → `systematic-debugging` + fix-loop de 5 rondas (rondas 4–5 suben un tier: sonnet→opus; opus se queda en opus). Agotado → `parked: fix-loop-exhausted`, sus dependientes `blocked-by-parked`, sigo con lo independiente (si T1 se agota, T3 se aparca y T2/T4/T5 se hacen igual). Nunca toco un test para que pase.

Run-log al final de la corrida, en el propio plan:
```
## FIWB run-log
| T  | tier | modo   | modelo | commit  | estado            | desviaciones / pregunta |
| T7 | 3    | —      | —      | —       | parked: hard-stop | borra legacy/ (datos) + tabla → pregunta en Close |
| T6 | 3    | —      | —      | —       | parked: hard-stop | deploy prod → pregunta en Close |
| T1 | 1    | SDD    | opus   | a1b2c3d | done              | — |
| T2 | 1    | SDD    | sonnet | b2c3d4e | done              | — |
| T4 | 2    | SDD    | opus   | c3d4e5f | done              | burst sin semántica en el plan; solo perMinute |
| T3 | 2    | SDD    | sonnet | d4e5f6a | done              | — |
| T5 | 3    | INLINE | —      | e5f6a7b | done              | — |
```

## Cierre

1. Review de toda la rama: `Agent(model: opus)` sobre `git diff main...fiwb/notif-hardening` + fix-loop de lo CRITICAL/HIGH.
2. Antes de mergear compruebo si un push a `main` dispara despliegue (`.github/workflows`, `.gitlab-ci.yml`, hooks). El plan tiene el deploy como script manual, lo que sugiere que no, pero lo verifico: si hay CD en `main`, el merge sería un "merge that auto-deploys" → hard-stop → me quedo en la rama (`git push -u origin fiwb/notif-hardening`) y el merge se pliega dentro de la pregunta de T6. Si no hay CD y no queda CRITICAL/HIGH: `git checkout main && git merge --ff-only fiwb/notif-hardening && git push origin main`.
3. Una PushNotification (informa; no sustituye a las preguntas):
   `FIWB notif-service: 5/7 tasks hechas, review opus limpio, mergeado y pusheado a main. 2 preguntas abiertas: T7 (borrar legacy/) y T6 (deploy prod).`
4. Preguntas encoladas, una por llamada. Ambas tier 3 → desempate por gravedad: T7 (high) antes que T6; además, si autorizas T7 tiene que entrar en `main` antes del deploy.

**Pregunta 1** (`AskUserQuestion`):
```
T7 «Eliminar legacy/ y la tabla legacy_events» quedó parked: borra un directorio con datos y una tabla,
hard-stop que ni el plan aprobado ni "no me pidas OK" cubren. Estado real: legacy/ = <N> archivos, <X> MB,
<tracked / no tracked> en git; CREATE TABLE legacy_events en db/schema.sql:<línea>.
T1–T5 están hechas, revisadas y en main. ¿Qué hago con T7?
  1. Ejecutarla ahora con copia previa (tar de legacy/ fuera del repo): rm -rf legacy/, quitar la tabla
     de db/schema.sql, commit `chore: drop legacy events`, re-review opus, merge y push (Recomendado)
  2. Dejarla parked hasta después del lanzamiento del lunes
  3. Solo el cambio en db/schema.sql; legacy/ lo borras tú
```
Si respondes 1 → INLINE (yo; 2 archivos, sin tests; revisor sonnet), commit, y repito el cierre desde el paso 1 (review opus, ff-merge, push). Después:

**Pregunta 2** (`AskUserQuestion`):
```
T6 «Desplegar a producción» quedó parked: un deploy a prod nunca se ejecuta solo, con o sin autorización previa.
Estado: main = <sha> con T1–T5 <y T7>, review opus sin CRITICAL/HIGH, suite verde.
Nota de T4: el plan no define la semántica de `burst`; el limiter aplica solo perMinute=60 por IP.
El abuso (~400 req/min) sigue hasta que esto salga. ¿Despliego?
  1. Sí: ./scripts/deploy.sh prod y verifico que /health responde 200 (Recomendado)
  2. Lo despliego yo — pasos: `! ./scripts/deploy.sh prod` · `! curl -s -o /dev/null -w '%{http_code}' https://<host>/health`
  3. Todavía no; queda parked
```
Si respondes 1 → ejecuto, verifico `/health` = 200, `- [x]`, fila en run-log y `▶ T6 [tier 3] INLINE → done · deploy verificado /health 200`.

5. Recap:
```
Recap FIWB — notif-hardening
Hechas 5/7: T1, T2, T4, T3, T5 · rama fiwb/notif-hardening → ff-merge en main · push origin/main
Parked: T7 (hard-stop: borrado de datos) · T6 (hard-stop: deploy prod) → <resultado de cada pregunta>
Commits: a1b2c3d fix: slugify strips diacritics · b2c3d4e feat: add rate limit constants ·
         c3d4e5f feat: per-IP rate limiter · d4e5f6a feat: validate notification name · e5f6a7b docs: rate limits
Desviaciones: 1 táctica (T4, burst sin semántica) · 0 arquitectónicas
Modo/modelo: T1 SDD/opus · T2 SDD/sonnet · T4 SDD/opus · T3 SDD/sonnet · T5 INLINE (revisor sonnet) · review final opus
Dispatches: 14 (4 implementadores + 8 revisores de task + 1 revisor de T5 + 1 review final) + rondas de fix-loop si las hubo
```
6. Sección de `SESSION_HANDOFF.md` para `notif-service` con lo que quedó parked y su "Siguiente paso concreto".

## Todas las interacciones contigo, en orden

1. Línea de anuncio.
2. Tabla de tiers + fuentes descartadas.
3. Dos líneas ▶ de parking (T7, T6) y cinco líneas ▶ de progreso (T1, T2, T4, T3, T5) a medida que se completan.
4. Una línea de aviso solo si el contexto supera el 70 % (no aplica con el margen actual).
5. Al cierre: la PushNotification, la Pregunta 1 (T7), la Pregunta 2 (T6), el recap.

Ninguna pregunta antes de agotar el trabajo ejecutable; ninguna tarea de la lista de hard-stops ejecutada sin tu respuesta explícita. Lo que queda en `main` al terminar, contestes o no: el fix de acentos, la validación de `name`, el rate limiter contra el abuso en curso, las constantes y su documentación.
