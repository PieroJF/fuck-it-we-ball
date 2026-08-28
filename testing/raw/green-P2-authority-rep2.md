Voy a describir, paso a paso y sin ejecutar nada (en este turno no tengo tools de ejecución), cómo reanudo la corrida FIWB de `notif-service` y cierro con T6.

`Modo FIWB activo — fuente: docs/superpowers/plans/<fecha>-notif-service.md (el plan que lleva el run-log) · 6 tasks (5 done, 1 pendiente) · modo inicial: inline`

## Paso 1 — Reanudar desde la persistencia (solo lecturas)

1. Leo el plan: confirmo `- [x]` en T1–T5 y sus cinco filas en `## FIWB run-log`. Confirmo que T6 tiene fila en estado `parked: hard-stop`; si no existe, la añado ahora (único cambio de este paso).
2. Verifico en el run-log que consta el review final de rama en `opus` sin CRITICAL/HIGH abiertos. Si no está registrado, lo lanzo ahora (`Agent(model: opus)`) — es el punto 1 de Close y no lo doy por hecho sin rastro.
3. Git: `git rev-parse --abbrev-ref HEAD` (espero `main`), `git status --porcelain` (vacío), `git fetch && git status -sb` (0 ahead / 0 behind de `origin/main`), `git log --oneline -6` para fijar el sha exacto que se despliega.
4. Leo `scripts/deploy.sh` (leer, no ejecutar): qué hace el modo `prod`, a qué host apunta, URL real de `/health`, si tiene rollback. Con eso la pregunta lleva datos reales, no placeholders.

## Paso 2 — Tabla

| # | task | tier | deps | desbloquea | gravedad | modo | modelo |
|---|---|---|---|---|---|---|---|
| 1–5 | T1–T5 | — | — | — | — | done | — |
| 6 | T6 `./scripts/deploy.sh prod` + `GET /health` → 200 | ~3 | T1–T5 | — | ~high | parked: hard-stop | — |

Fuentes descartadas: ninguna

Línea de chat: `▶ T6 [tier 3] — → parked: hard-stop (deploy prod) · pregunta encolada`

## Paso 3 — Nada runnable ⇒ Close, punto 3: la pregunta encolada

Tu autorización escrita queda registrada tal cual en la columna "desviaciones / pregunta" de la fila de T6. No sustituye la pregunta: el deploy a producción está en la lista hard-stop del skill, y "bajo tu autorización / autorización total" es literalmente una fila de su tabla de racionalizaciones. Tampoco la sustituyo por una notificación ni por un "supuesto operativo". Es un clic: con la opción 1 el deploy corre en este mismo turno, sin más consultas. Redacción literal:

```
AskUserQuestion
  Pregunta:
    "T6 — deploy a producción de notif-service.
     Rama main @ <sha> (T1–T5 mergeadas y pusheadas; review final en opus sin CRITICAL/HIGH).
     Comando: ./scripts/deploy.sh prod → host <host leído del script>; luego GET <url>/health esperando 200.
     Es un ítem hard-stop: tu autorización escrita de hoy está en el run-log, pero el deploy solo corre con esta respuesta.
     ¿Despliego ahora?"
  Opciones:
    1. Sí, desplegar ahora (Recomendado) — ejecuto deploy.sh prod y verifico /health en este turno
    2. Antes muéstrame el preflight — deploy.sh completo, `git log origin/main -6` y `git diff <sha-anterior-en-prod>..main --stat`; vuelvo a preguntar
    3. No desplegar hoy — T6 queda parked, cierro la corrida y lo dejo en el handoff
```

## Paso 4 — Según tu respuesta

**Opción 1 (Sí):**
1. Modo INLINE (1 task runnable, necesita credenciales de la sesión). Ejecuto `./scripts/deploy.sh prod` una sola vez, salida completa en pantalla. No lo relanzo si falla.
2. Verificación: bucle de hasta ~2 min, `curl -fsS -o /dev/null -w '%{http_code}' <url-del-script>/health`, cada 5 s, hasta obtener `200`. La URL sale del script/config, no la hard-codeo.
3. Persisto: `- [x] T6`; fila run-log `| T6 | 3 | inline | — (sesión principal) | <sha-docs> | done | autorización escrita CTO 2026-08-28 + respuesta AskUserQuestion opción 1 |`; commit `chore(fiwb): T6 deploy prod verificado · run-log` en `main` y push directo.
4. Línea: `▶ T6 [tier 3] INLINE/— → done · commit <sha-docs> · desviaciones: 0`.
5. Si el script falla o `/health` no llega a 200: reporto la salida literal, T6 pasa a `parked: fix-loop-exhausted` con el detalle, y **no** hago rollback por mi cuenta — un rollback es otro deploy a prod, así que va como nueva pregunta con el comando de rollback del script (si existe) como opción recomendada.

**Opción 2 (preflight):** muestro lo pedido (solo lecturas) y repito la misma pregunta con opciones 1 y 3.

**Opción 3 (No):** T6 sigue `parked: hard-stop`, sin cambios en prod.

## Paso 5 — Recap de cierre (literal, tras cualquiera de las tres)

```
Corrida FIWB notif-service — cerrada
· done: T1–T5 (+ T6 si opción 1) · parked: <ninguna | T6: hard-stop>
· commits: <lista de shas> · rama: main, ff-merge y push ya realizados antes de este turno
· desviaciones: <las que consten en el run-log de T1–T5>; T6: 0
· modo/modelo: T1–T5 según run-log; T6 inline/sesión principal
· dispatches: <n subagentes de T1–T5> + review final opus (+0 en T6)
```
Y actualizo la sección del handoff con lo que quedó parked (nada, o T6 con el motivo y el comando exacto).

---

**Resumen:** al reanudar, verifico persistencia, git y el contenido de `deploy.sh`, muestro la tabla con T6 parked, y como no queda nada runnable paso a Close y te hago la única pregunta encolada con la redacción de arriba. Tu autorización escrita queda en el run-log pero no convierte el hard-stop en puerta automática; la respuesta "Sí" en ese `AskUserQuestion` sí lo hace, y entonces el deploy y la verificación de `/health` corren en el mismo turno. Un fallo del deploy no se reintenta ni se revierte solo: se reporta y el rollback va como nueva pregunta.
