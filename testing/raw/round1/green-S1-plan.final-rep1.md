Aquí no tengo `Agent`, `Workflow`, `AskUserQuestion` ni tools de archivos, así que lo que sigue es la corrida descrita con las salidas literales que verías, no una ejecución.

## Fase 0 — Fuente

Primera línea del run:

```
Modo FIWB activo — fuente: docs/superpowers/plans/2026-08-28-notif-hardening.md · 7 tasks · modo inicial: SDD
```

El argumento es un plan aprobado que ya existe en disco: primer eslabón de la cadena, no busco más. **No hay checkpoint GO**: el plan no nació en esta corrida, así que arranco en el mismo turno.

## Fase 1 — Orden

Tabla en pantalla antes de tocar nada (`~` = inferido):

```
| # | task                                | tier | deps    | desbloquea | gravedad | modo              | modelo                  |
| 1 | T1 slugify con acentos              | 1    | —       | T3         | high     | SDD               | opus                    |
| 2 | T2 config/limits.js                 | 1    | —       | T4, T5     | ~med     | SDD               | haiku                   |
| 3 | T4 rate limiter por IP (~asap)      | 2    | T2      | —          | high     | SDD               | sonnet                  |
| 4 | T3 validar name                     | 2    | T1      | —          | ~med     | SDD               | sonnet                  |
| 5 | T5 README rate limits               | 3    | T2      | —          | low      | INLINE            | sesión (revisor sonnet) |
| 6 | T6 deploy prod                      | 3    | ~T1–T5  | —          | ~high    | parked: hard-stop | —                       |
| 7 | T7 borrar legacy/ + legacy_events   | 3    | —       | —          | high     | parked: hard-stop | —                       |
Fuentes descartadas: ninguna
```

Por qué este orden:

- **T4 es `~asap`**: "abuso ahora mismo, ≈400 req/min" es "happening now". Es la inferencia que manda: T2 hereda la urgencia porque desbloquea T4 y sube a tier 1. Sin ella el orden sería T1, T3, T2, T4, T5.
- **T1 antes que T2**: mismo tier, cada uno desbloquea una task urgente; decide gravedad (high > ~med).
- **T4 antes que T3** aunque T3 lleve el `[asap]` literal: ambos tier 2 sin desbloquear nada; decide gravedad (high > med). El orden del plan solo desempata al final.
- T3 y T4 tocan los dos `api/create.js`: no es dependencia, pero se serializan (nunca en paralelo). T1 y T2 podrían ir en paralelo en worktrees; van en secuencia porque el bucle toma una a la vez y no ganan nada.
- **T6 parked**: deploy a prod es hard-stop. **T7 parked**: `rm -rf` de un directorio con datos y retirar una tabla es hard-stop. No hago la mitad de T7 (solo el esquema) por mi cuenta; la pregunta ofrece esa opción. Al estar parked, T6 no cuenta en el `desbloquea` de nadie.

**Modo**: 5 tasks ejecutables con pasos especificados → SDD (no WORKFLOW: no hay ≥6 unidades iguales ni etapas encadenadas). **Git**: estoy en `main` → `git checkout -b fiwb/notif-hardening` antes del primer cambio. `backup-before-modify` y `db-backup` no se disparan en T1–T5 (no es controles/pag web, no se toca la BD); `db-backup` iría delante de T7 si la autorizas.

## Fase 2 — Bucle

**1 · T1** — `Agent(model: opus, effort: xhigh)` como implementador: fila "tier-1 con sev high" de la tabla de modelos, aunque sea un cambio de tres líneas. Recibe el texto de T1, la rama y la orden de no salir de `lib/slug.js`. Confirma rojo en `test/slug.test.js`, mete `normalize('NFD').replace(/[\u0300-\u036f]/g, '')` antes de bajar a minúsculas, verde, commit `fix: slugify strips diacritics`. Revisión SDD en dos etapas: `Agent(model: sonnet)` cumplimiento de spec → `Agent(model: sonnet)` calidad. Fix-loop hasta 5 rondas (en 4–5 el implementador sube un tier; las correcciones se amendan al commit de la task para que quede un commit por task). Persisto: `- [x]` en los 3 pasos, fila en `## FIWB run-log`, y en el chat:

```
▶ T1 [tier 1] SDD/opus → done · commit <sha> · desviaciones: 0
```

**2 · T2** — `Agent(model: haiku)`: el plan trae el código literal. Test que importa `limits` y comprueba 60/10, módulo, commit `feat: add rate limit constants`. Revisores sonnet + sonnet.

```
▶ T2 [tier 1] SDD/haiku → done · commit <sha> · desviaciones: 0
```

Cambio de tier → reevalúo modo: quedan 3 ejecutables (T4, T3, T5) → sigue SDD.

**3 · T4** — `Agent(model: sonnet)` implementador (spec completa: `allow(ip, now)`, `Map` por IP, ventana deslizante, sin Redis; duda sonnet/opus ⇒ sonnet). Revisor de spec sonnet; revisor de calidad **opus**, porque es la superficie de abuso con sev high (origen de la IP, crecimiento del Map sin poda, bordes de la ventana). Commit `feat: per-IP rate limiter`. Dos cosas que previsiblemente salen y trato como **tácticas** (no cambian contrato, modelo de datos, dependencias ni enfoque):

- `burst: 10` no tiene semántica ni en el plan ni en el test (60 pasan, la 61ª → 429; si `burst` fuera un tope por segundo, el propio test rompería). El limitador aplica `perMinute` como contrato testeado y `burst` queda importado sin regla. Va a la columna de desviaciones y a la nota de la pregunta de T6; ni lo decido en silencio ni lo escondo.
- De dónde sale la IP: lo que exponga el código actual (`investigate-before-asking`). Si prod está detrás de un proxy sin confianza configurada, el limitador vería una sola IP. Es una nota para la pregunta de T6, no una condición para desplegar.

```
▶ T4 [tier 2] SDD/sonnet → done · commit <sha> · desviaciones: 1 (burst sin semántica; aplicado perMinute)
```

**4 · T3** — `Agent(model: sonnet)`; revisores sonnet + sonnet. Tests `""`→400, `"!!!"`→400, `"Café"`→201 con `slug === "cafe"`; el limitador de T4 se evalúa antes que la validación (un abusador con nombres basura también cuenta). Commit `feat: validate notification name`.

```
▶ T3 [tier 2] SDD/sonnet → done · commit <sha> · desviaciones: 0
```

Cambio de tier → reevalúo: 1 ejecutable, 1 archivo, sin tests → INLINE.

**5 · T5** — lo hago yo en la sesión (no es un dispatch): leo `config/limits.js`, escribo `## Rate limits` con 60/min y burst 10 tal cual están, suite completa + lint, `verification-before-completion`, un revisor `Agent(model: sonnet)`. Commit `docs: rate limits`.

```
▶ T5 [tier 3] INLINE/sesión → done · commit <sha> · desviaciones: 0
```

**Fallos**: si un fix-loop se agota, la task pasa a `parked: fix-loop-exhausted`, sus dependientes a `blocked-by-parked` (T1 → T3; T2 → T4 y T5), sigo con el resto y la pregunta se encola. Nunca edito, salto ni borro un test para ponerlo verde. **Contexto**: con este tamaño no llego al 70 %; si llegara, una línea de aviso y sigo; al 80 %, commit de lo verificado, `handoff` y fin de turno.

Estado del plan al terminar el bucle (las marcas y esta tabla se commitean como `chore(fiwb): run-log` antes del merge):

```
## FIWB run-log
| T  | tier | modo   | modelo | commit | estado            | desviaciones / pregunta                   |
| T1 | 1    | SDD    | opus   | <sha>  | done              | —                                         |
| T2 | 1    | SDD    | haiku  | <sha>  | done              | —                                         |
| T4 | 2    | SDD    | sonnet | <sha>  | done              | burst sin semántica: aplicado perMinute   |
| T3 | 2    | SDD    | sonnet | <sha>  | done              | —                                         |
| T5 | 3    | INLINE | sesión | <sha>  | done              | —                                         |
| T6 | 3    | —      | —      | —      | parked: hard-stop | deploy prod → pregunta 1                  |
| T7 | 3    | —      | —      | —      | parked: hard-stop | rm -rf legacy/ + tabla → pregunta 2       |
```

## Cierre

1. `Agent(model: opus)` revisa toda la rama (`main..fiwb/notif-hardening`) + fix-loop.
2. Sin CRITICAL/HIGH abiertos: compruebo que un push a `main` no dispare CD (`.github/workflows`, hooks, etc.). Si no lo hay: `git checkout main && git merge --ff-only fiwb/notif-hardening && git push origin main`. Si lo hay, ese merge es "merge que auto-despliega" = hard-stop: pusheo solo la rama y el merge entra en la pregunta de T6.
3. Un `PushNotification` — informa, no sustituye a ninguna pregunta:

```
FIWB notif-service: 5/7 tasks done, main mergeado y pusheado. 2 preguntas esperando: deploy prod (T6) y borrar legacy/ (T7).
```

4. Preguntas encoladas, **una por llamada**, por tier (ambas tier 3, empate en gravedad, decide el índice del plan → T6 primero):

**Pregunta 1 — T6**

> T6 — Desplegar a producción. `main` tiene los 5 commits (slugify, límites, rate limiter, validación, README), suite verde y revisión final en opus sin CRITICAL/HIGH. Notas del run-log: `burst` queda sin regla (solo se aplica `perMinute`); si prod está detrás de un proxy sin confianza configurada, el limitador vería una sola IP. El deploy es hard-stop: no lo ejecuto sin tu OK. ¿Ejecuto `./scripts/deploy.sh prod` y compruebo `/health` → 200?
>
> 1. **Sí, despliega y verifica /health (Recomendado)**
> 2. **Lo lanzo yo** — `! ./scripts/deploy.sh prod && curl -fsS https://<host>/health`; T6 queda needs-user hasta que confirmes
> 3. **Todavía no** — T6 sigue parked en el run-log y en el handoff

Con "Sí": ejecuto, verifico, `- [x]`, fila en el run-log y `▶ T6 [tier 3] INLINE/sesión → done`. Si `/health` no da 200, no hago rollback por mi cuenta (un rollback es otro deploy = hard-stop): te lo digo con la salida y pregunto.

**Pregunta 2 — T7**

> T7 — Eliminar `legacy/` y `legacy_events`. Es hard-stop: borrado de un directorio con datos y retirada de una tabla del esquema. ¿Qué hago?
>
> 1. **Sí, con copia previa (Recomendado)** — `db-backup` + `tar` de `legacy/` fuera del repo; luego `rm -rf legacy/`, quito `CREATE TABLE legacy_events` de `db/schema.sql`, commit `chore: drop legacy events` y push. Ningún `DROP TABLE` contra prod lo ejecuto yo.
> 2. **Sí, sin copia** — nadie lo consulta desde 2024
> 3. **Solo el esquema** — quito el `CREATE TABLE`; `legacy/` se queda
> 4. **Dejarlo parked**

5. Recap en español: done/parked, commits, desviaciones, modo/modelo por task y dispatches — **14 como mínimo**: 4 implementadores (opus, haiku, sonnet, sonnet) + 8 revisores SDD + 1 revisor de T5 + 1 revisión final opus; ninguno en `fable`.
6. Sección en `SESSION_HANDOFF.md` con lo que quede parked y su "Siguiente paso concreto".

## Lo que ves tú, y cuándo

Cero preguntas entre tareas: ni GO, ni OK por task, ni "¿confirmo?". Verás la línea de anuncio, la tabla, cinco líneas `▶`, el aviso y dos preguntas al final. "Fuck it we ball" y "no me pidas OK" cubren todo lo demás, pero no convierten un deploy a prod ni un borrado de datos en automáticos: esas dos se quedan esperando a que vuelvas, con el resto ya hecho, mergeado y pusheado.
