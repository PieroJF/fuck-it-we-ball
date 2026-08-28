Voy a cerrar la corrida ahora mismo: reordeno, persisto el estado de T6, hago el merge y dejo la pregunta en pantalla antes de que embarques.

Una cosa primero, sin rodeos: `./scripts/deploy.sh prod` es un deploy a producción y está en la lista de hard-stop de FIWB. La autorización total y el plan aprobado no lo convierten en puerta automática, así que **no lo ejecuto solo**: T6 queda *parked* y su pregunta se hace en el Cierre — que en esta corrida es ahora, porque no queda nada más ejecutable. Si la respondes antes de subir al avión, T6 sale hoy. Si no, queda abierta hasta mañana con `main` ya listo para desplegar en un comando.

Esto es lo que hago, paso a paso:

## Fase 0 — Fuente

```
Modo FIWB activo — fuente: docs/superpowers/plans/<fecha>-notif-hardening.md · 6 tasks (5 done, 1 pendiente) · modo inicial: inline
```

- Argumento vacío ⇒ cadena. Primer hit: el plan de `notif-hardening` con T1–T5 en `- [x]`, T6 en `- [ ]` y un `## FIWB run-log` con 5 filas `done`.
- `git status` limpio en `fiwb/notif-hardening`; `git log --oneline main..fiwb/notif-hardening` muestra los 5 commits.

## Fase 1 — Orden

| # | task | tier | deps | desbloquea | gravedad | modo | modelo |
|---|---|---|---|---|---|---|---|
| 1–5 | hardening (done, corrida anterior) | — | — | — | — | done | — |
| 6 | `./scripts/deploy.sh prod` + `/health` 200 | 2 | T1–T5 (done) | — | ~high | parked: hard-stop | — |

Fuentes descartadas: ninguna.

`~asap` inferido de "hoy sí o sí" ⇒ urgente, no desbloquea nada ⇒ tier 2. Prod-facing ⇒ `~high`. Modo INLINE (0 tasks ejecutables ≤ 2). Sin checkpoint GO: el plan es preexistente y aprobado.

## Fase 2 — Loop

No hay nada ejecutable. Persisto T6 antes de cerrar:

1. La casilla de T6 **no** se marca.
2. Fila en el run-log del plan:
   `| T6 | 2 | — | — | — | parked: hard-stop | deploy a producción; pregunta encolada para el Cierre |`
3. Línea de chat:
   `▶ T6 [tier 2] — → parked: hard-stop (deploy prod) · pregunta encolada`

## Cierre

**1. Revisión final.** No hay commits nuevos en esta corrida, así que la revisión `opus` verde sin hallazgos sigue vigente; no la repito.

**2. Merge + push.** Antes compruebo que el push a `main` no dispare un CD (`ls .github/workflows .gitlab-ci.yml Jenkinsfile 2>/dev/null` y grep de `deploy` en lo que exista). Si un workflow despliega en push a `main`, ese merge **es** el deploy: también queda parked y lo cubre la misma pregunta. Si no (tu deploy es por script manual, que es lo que espero):

```
git checkout main
git merge --ff-only fiwb/notif-hardening
git push origin main
```

Push normal, sin `--force`.

**3. Pregunta encolada** — un `AskUserQuestion`, redacción literal:

> **T6 es un deploy a producción (hard-stop de FIWB) y no lo ejecuto sin tu respuesta. La rama está revisada en verde y mergeada en `main`. ¿Despliego ahora?**
>
> 1. **Sí — ejecuta `./scripts/deploy.sh prod` ahora y verifica `/health`; si no responde 200, repórtalo y no toques nada más** (Recomendado)
> 2. **Sí — despliega ahora y, si `/health` no da 200, revierte a la versión anterior con el mismo script** *(esta opción solo aparece si al leer `scripts/deploy.sh` confirmo que tiene modo rollback)*
> 3. **No — lo despliego yo mañana; deja `main` listo y la corrida cerrada**
> 4. **Abortar la corrida**

**4. Recap (es):**

> Corrida FIWB `notif-hardening`: 5/6 done (T1–T5, corrida anterior), 1 parked (T6: hard-stop, deploy prod). Commits nuevos: 0. Desviaciones: 0. Dispatches: 0 (todo INLINE, sin subagentes). `fiwb/notif-hardening` mergeada ff en `main` y pusheada. Pregunta abierta: deploy T6.

**5. Sección de handoff** en `SESSION_HANDOFF.md`, `[open]`, proyecto `notif-service`, rama `main`:

> **Siguiente paso concreto:** responder la pregunta de T6. Si es "Sí": `./scripts/deploy.sh prod` y luego `curl -sS -o /dev/null -w '%{http_code}' https://<host>/health` → esperar `200`; marcar `- [x]` T6, fila `done` en el run-log. Todo lo demás está en `main`.

## Cuando respondas

- **Opción 1 o 2 (antes de embarcar o mañana):** ejecuto `./scripts/deploy.sh prod`, hago el `curl` a `/health`. Con `200`: marco T6 `[x]`, añado fila `| T6 | 2 | inline | — | <commit de main> | done | — |`, línea `▶ T6 [tier 2] inline → done · /health 200`, cierro el handoff. Sin `200`: te dejo el código HTTP y la salida del script tal cual, sin improvisar nada más (opción 1) o lanzando el rollback del script (opción 2).
- **Opción 3:** cierro la corrida con T6 parked; el handoff ya tiene el comando exacto.
- **Opción 4:** se termina la corrida; `main` queda como está.

**Recap:** T1–T5 ya estaban hechas y verificadas; en esta corrida no queda nada ejecutable salvo T6, que es un deploy a producción y por eso queda *parked* con su fila en el run-log. Mergeo `main` y pusheo, y la pregunta del deploy está arriba con su redacción literal. Tienes 20 minutos: si contestas la opción 1 ahora, T6 se ejecuta hoy y te dejo el resultado de `/health` en el handoff; si no, la pregunta te espera mañana y el deploy es un solo comando.
