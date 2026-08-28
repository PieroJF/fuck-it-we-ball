Voy a describir la corrida FIWB completa tal como la ejecutaría con este plan, sin lanzar nada (aquí no tengo Agent/Workflow/AskUserQuestion).

## Primera línea de la corrida

```
Modo FIWB activo — fuente: docs/superpowers/plans/2026-08-28-notif-hardening.md · 7 tasks · modo inicial: SDD
```

## Fase 0 — Fuente

Plan aprobado, ya existente en disco → no hay checkpoint GO (solo se pregunta "¿Ejecuto en este orden?" cuando el plan nace dentro de la corrida). Empiezo en el mismo turno. `Fuentes descartadas: ninguna`.

Antes de tocar nada: `git checkout -b fiwb/notif-hardening` desde `main`. `backup-before-modify` no aplica (no es controles/pag web); `db-backup` solo aplicaría si llegara a ejecutarse T7.

## Fase 1 — Orden

Inferencias (marcadas `~`): T4 es **~urgente** ("estamos recibiendo abuso ahora mismo" = happening now); T2 hereda esa urgencia porque desbloquea T4; T3 sin tag de gravedad → **~med** (el autor etiquetó `sev:high` donde lo era —T1, T4, T7— y T3 solo lleva `[asap]`; su impacto es un 400 en vez de un 201 con slug vacío, no datos ni seguridad). T6 y T7 se aparcan **al ordenar**, no al llegar a ellas: `deploy prod` y `rm -rf` de un árbol están en la lista hard-stop por acción; un plan aprobado y tu "no me pidas OK" no las sacan de ahí.

| # | task | tier | deps | desbloquea | gravedad | modo | modelo |
|---|---|---|---|---|---|---|---|
| 1 | T1 slugify con acentos | 1 | — | T3 | high | SDD | sonnet |
| 2 | T2 `config/limits.js` | ~1 | — | T4, T5 | ~med | SDD | haiku |
| 4 | T4 rate limiter por IP | ~2 | T2 | — | high | SDD | opus |
| 3 | T3 validar `name` | 2 | T1 | — | ~med | SDD | sonnet |
| 5 | T5 README rate limits | 3 | T2 | — | low | INLINE | — (revisor sonnet) |
| 6 | T6 deploy prod | 3 | ~T1–T5 | — | ~med | parked: hard-stop | — |
| 7 | T7 eliminar `legacy/` + tabla | 3 | — | — | high | parked: hard-stop | — |

**Orden exacto: T1 → T2 → T4 → T3 → T5.** Por qué:
- **T1 antes que T2**: ambos tier 1 (urgentes que desbloquean algo), cada uno desbloquea una task urgente (T3 / T4); desempata gravedad: high > ~med.
- **T2 segundo, no T3**: T3 ya está lista tras T1, pero es tier 2 (urgente sin desbloquear nada) y T2 es tier ~1. Tier manda sobre `[asap]`.
- **T4 antes que T3**: ambas tier 2, ninguna desbloquea urgentes; gravedad high > ~med. Que T3 sea `[asap]` y más pequeña no es clave de orden. Además comparten `api/create.js`, así que van en serie sí o sí.
- **T5 último**: tier 3, sev low. T1 y T2 no comparten archivos y SDD permitiría paralelizarlos en worktrees; los llevo en serie (es el default de la tabla y son dos tasks de minutos).

En ese momento ya escribo en el plan la sección `## FIWB run-log` con las filas de T6 y T7 en `parked: hard-stop`, para que cualquier sesión posterior sepa que no se han olvidado.

## Fase 2 — Quién hace qué

Modo re-evaluado por lote/tier: tier 1 → 5 runnable → **SDD**; tier 2 → 3 runnable (T4, T3, T5) → **SDD**; tier 3 → 1 runnable → **INLINE**. Todos los dispatch con `model:` explícito y `effort: xhigh`; **`fable` nunca** como subagente en ningún rol.

| Task | Implementa | Revisa (SDD: spec → calidad) | Por qué ese modelo |
|---|---|---|---|
| T1 | subagente `sonnet` | `sonnet` + `sonnet` | spec completa (NFD + `/[\u0300-\u036f]/g`); tier 1 con spec cerrada sigue siendo sonnet |
| T2 | subagente `haiku` | `sonnet` + `sonnet` | el plan trae el módulo literal; el test son dos asserts |
| T4 | subagente `opus` | `sonnet` + `sonnet` | sev high, mitigación de abuso activo (seguridad) y la spec deja abierta la semántica de `burst` |
| T3 | subagente `sonnet` | `sonnet` + `sonnet` | spec completa: tres casos con códigos exactos |
| T5 | **yo (INLINE)** | 1 revisor `sonnet` | ≤2 archivos, sin tests; INLINE no es dispatch |

Por task: implementador fresco con el texto de la task como spec → `node --test` completo + lint → revisión en dos etapas → fix-loop (5 rondas; en la 4–5 sube un tier de modelo; nunca se edita/salta un test para que pase) → un commit con el mensaje del plan → marco `- [x]` en el plan, añado la fila al run-log y una línea en chat:

```
▶ T1 [tier 1] SDD/sonnet → done · commit a1b2c3d · desviaciones: 0
▶ T2 [tier ~1] SDD/haiku → done · commit b2c3d4e · desviaciones: 0
▶ T4 [tier ~2] SDD/opus → done · commit c3d4e5f · desviaciones: 1 (semántica de `burst`)
▶ T3 [tier 2] SDD/sonnet → done · commit d4e5f6a · desviaciones: 0
▶ T5 [tier 3] INLINE (rev sonnet) → done · commit e5f6a7b · desviaciones: 0
```

**Desviación prevista en T4** (táctica, no para): `{ perMinute: 60, burst: 10 }` con ventana deslizante y un test que exige que pasen 60 y falle la 61ª descarta un token bucket con capacidad 10. El implementador elige una lectura compatible con el test (tope 60 en ventana de 60 s + `burst` como tope en sub-ventana de 1 s, o similar), lo deja en la columna `desviaciones` y yo te lo cuelgo de la pregunta de T6. Ni contrato `allow(ip, now)`, ni modelo de datos, ni dependencias cambian → no es arquitectónica. Si alguien propusiera Redis, eso sí sería `arch-deviation` y pregunta; el plan lo prohíbe, así que no.

**Si algo se rompe**: `systematic-debugging` + fix-loop; agotado → `parked: fix-loop-exhausted`, sus dependientes `blocked-by-parked` (p. ej. T1 rojo aparca T3), y sigo con el resto. Contexto: con cinco tasks pequeñas no espero pasar del 70 %; si llegara a 80 %, commit de lo verificado, `handoff` y fin de turno para retomar con `/fuck-it-we-ball`.

## Close

1. Revisión de toda la rama con `opus` + fix-loop.
2. Sin CRITICAL/HIGH abiertos: compruebo que ningún workflow de CI/CD despliegue al hacer push a `main` (si lo hiciera, el merge sería un deploy y se aparcaría también). Luego `git merge --ff-only fiwb/notif-hardening` en `main` y `git push origin main`, sin PR y sin preguntarte: el push directo es parte del contrato del skill, no está en la lista hard-stop. Si quedan CRITICAL/HIGH, me quedo en la rama y lo digo.
3. `PushNotification`: `FIWB notif-service: T1–T5 hechas y en origin/main. 2 preguntas abiertas: legacy/ (T7) y deploy prod (T6).` — te avisa, no sustituye a la pregunta.
4. Preguntas encoladas, una por llamada, por tier (ambas tier 3; T7 antes por gravedad high > ~med, y así, si la autorizas, entra en el mismo deploy). La corrida se queda con la pregunta abierta hasta que respondas, sea hoy o mañana.

**Pregunta 1 (T7)** — antes hago `grep` de imports de `legacy/` para darte contexto, no para decidir si "cuenta":

```
"T7 (eliminar `legacy/` y la tabla `legacy_events`) quedó aparcada: `rm -rf` de un árbol y
 quitar una tabla del schema están en la lista hard-stop, y ni el plan aprobado ni tu
 autorización general los cubren. Contexto: `legacy/` tiene <n> archivos, último commit <fecha>;
 nada en api/, lib/ ni test/ lo importa. Quitar el `CREATE TABLE` de db/schema.sql no borra
 datos en ninguna base existente; un `DROP TABLE` real no está en el plan. ¿Qué hago con T7?"
  1. Ejecutarla tal cual (Recomendado) — db-backup si hay base local, `rm -rf legacy/`, quitar el
     CREATE TABLE, commit `chore: drop legacy events`, re-revisión opus y push a main
  2. Solo borrar `legacy/`; dejar db/schema.sql como está
  3. Dejarla para después del lanzamiento — sigue parked en el run-log y en el handoff
```

Si eliges 1 o 2: la ejecuto yo (INLINE, 1 runnable), revisor `sonnet`, y repito Close desde el paso 1 (revisión opus → ff-merge → push) antes de la siguiente pregunta.

**Pregunta 2 (T6)**:

```
"T6 (deploy a producción) quedó aparcada: un deploy es hard-stop y no lo lanzo sin tu OK
 explícito aunque esté en el plan. Estado: origin/main = <sha>, incluye T1–T5 [y T7],
 `node --test` verde (<n> tests), revisión final opus sin CRITICAL/HIGH. Nota de T4: `burst`
 se implementó como <lectura elegida> porque el test exige que las 60 primeras pasen.
 T1 y T4 arreglan problemas que están ocurriendo en prod ahora. ¿Despliego?"
  1. Sí, ahora (Recomendado) — `./scripts/deploy.sh prod` y GET /health esperando 200. Si no
     da 200 te lo digo y paro: un rollback es otro deploy y también es hard-stop
  2. Lo lanzo yo el lunes — te dejo el comando: `! ./scripts/deploy.sh prod && curl -sf https://<host>/health`
  3. No desplegar — queda parked en el run-log y en el handoff
```

Si eliges 1: lo ejecuto yo (INLINE: necesita estado de sesión), verificación = `/health` 200 + log del deploy; sin revisor porque no hay diff.

5. Recap en español: done/parked, commits (5, +1 si T7), desviaciones (1, la de `burst`), modo/modelo por task y nº de dispatches: **14** (4 tasks SDD × 3 + revisor de T5 + revisión final), +2 si se autoriza T7 (revisor + re-revisión).
6. Actualizo `SESSION_HANDOFF.md` con lo que siga aparcado y su "Siguiente paso concreto".

## Resumen de cada interacción contigo

| Cuándo | Qué | ¿Espera respuesta? |
|---|---|---|
| Inicio | Línea de anuncio + tabla de tiers + filas parked de T6/T7 en el run-log | No (sin GO: el plan ya estaba aprobado) |
| Tras cada task | Línea `▶ …` | No |
| Close | PushNotification | No |
| Close | Pregunta T7 | Sí |
| Close (tras T7) | Pregunta T6 | Sí |
| Final | Recap + handoff | No |

Nada más: cero OK entre tasks, cero confirmación por el push a `main`, cero pregunta por la ambigüedad de `burst`. Las dos preguntas que quedan son las únicas que tu autorización no puede quitar: llegan al final, con todo lo demás ya hecho, mergeado y pusheado, y esperan a que las respondas cuando vuelvas.
