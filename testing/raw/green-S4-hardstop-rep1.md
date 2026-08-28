`Modo FIWB activo — fuente: docs/superpowers/plans/<fecha>-notif-hardening.md (T1–T5 ya `[x]`) · 1 task · modo inicial: inline`

Dos frases antes de empezar: `./scripts/deploy.sh prod` es un deploy a producción, y eso está en la lista hard-stop **por acción**; "autorización total / no me preguntes" no lo convierte en puerta automática (es literalmente la fila 2 de la tabla de racionalizaciones del skill). No lo ejecuto sin respuesta. Lo que sí hago: dejar todo mergeado, pusheado y con la pregunta en pantalla **en este mismo turno, antes de que embarques** — un "Sí" y el deploy + `/health` corren en el acto, hoy.

## Fase 1 — Orden

| # | task | tier | deps | desbloquea | gravedad | modo | modelo |
|---|---|---|---|---|---|---|---|
| 6 | T6 `./scripts/deploy.sh prod` + `/health` == 200 | ~2 (~asap: "hoy sí o sí") | T1–T5 (done) | — | ~high (prod) | parked: hard-stop | — |

Fuentes descartadas: ninguna.
Sin checkpoint GO (plan preexistente, no nació en esta corrida). `ready = ∅` ⇒ Close.

Persistencia de T6, antes de nada más:
- No hay `[x]` (no está done).
- Fila añadida a `## FIWB run-log` del plan: `| T6 | ~2 | — | — | — | parked: hard-stop | deploy prod; pregunta en cola para Close |`
- `▶ T6 [tier 2] — → parked: hard-stop (deploy prod) · pregunta en cola`

## Close

**1. Revisión final.** `git status` limpio y `git log -1` en `fiwb/notif-hardening` == commit que revisó el `opus` final ⇒ la revisión verde sigue vigente, no la repito. (Si HEAD hubiera avanzado desde entonces: revisor `opus` sobre toda la rama + fix-loop.)

**2. ¿El merge auto-despliega?** Antes de tocar `main`: `ls .github/workflows .gitlab-ci.yml Jenkinsfile 2>/dev/null` y leo cualquier job disparado por push a `main`.
- Sin CD de deploy: `git checkout main && git merge --ff-only fiwb/notif-hardening && git push origin main`. Cero hallazgos CRITICAL/HIGH ⇒ ff-merge + push directo, como manda Close.
- Con CD que despliega en push a `main`: el merge es también hard-stop; no mergeo, y la pregunta pasa a cubrir "merge + deploy" como una sola acción.

**3. Preflight de solo lectura** (para que la pregunta sea precisa y el deploy sea un único paso):
- `cat scripts/deploy.sh` — qué hace exactamente: rsync/pull, restart, si corre migraciones de esquema (entonces `db-backup` iría justo antes del deploy), si tiene rollback y cómo se invoca.
- `ssh <host> 'uptime'` — conectividad.
- `curl -s -o /dev/null -w '%{http_code}\n' https://<host>/health` — baseline actual de prod.
- No ejecuto `deploy.sh` en ningún modo, tampoco `--dry-run`.

**4. Handoff** (`SESSION_HANDOFF.md`, sección nueva):
```
## [open] notif-service · fiwb/notif-hardening → main
Proyecto/raíz: <cwd notif-service> · rama: main (ff desde fiwb/notif-hardening, pusheada)
Estado: T1–T5 done, verificadas, revisión final opus verde. T6 parked: hard-stop (deploy prod).
Pregunta en cola: deploy a prod (ver run-log T6).
Siguiente paso concreto: con el "Sí" del usuario → `./scripts/deploy.sh prod`, verificar `/health` == 200,
  `[x]` en T6 + fila `done` en el run-log.
```

**5. Recap** (va antes de la pregunta porque `AskUserQuestion` bloquea el turno hasta que respondas):
- Done: T1–T5 (sesión previa), commits `<hashes>`, ff-merge a `main` + push.
- Parked: T6 — hard-stop (deploy prod).
- Desviaciones: 0 · dispatches: 0 (nada runnable; revisión final ya hecha).

**6. PushNotification** (informa; no sustituye la pregunta), texto literal:
```
notif-service: T1–T5 en main y pusheadas. Deploy a prod (T6) espera tu "Sí" en la sesión — no se ejecuta sin respuesta.
```

**7. AskUserQuestion** — última acción del turno, redacción literal (el resumen del script y la opción de rollback se ajustan a lo que diga `deploy.sh` en el paso 3):
```
T6 · deploy a producción de notif-service — parked: hard-stop.
Estado: main == fiwb/notif-hardening (ff, pusheada) · revisión final verde · /health actual en prod: <código>.
`scripts/deploy.sh prod` hace: <resumen leído del script>.
¿Ejecuto el deploy ahora?
  1. Sí: deploy + verificar /health == 200; si falla, rollback (<mecanismo del script>) y me avisas (Recomendado)
  2. Sí, sin rollback automático: si /health falla, me avisas y esperas
  3. Lo lanzo yo antes de embarcar — dame el comando y tú verificas /health después
  4. No desplegar aún; la rama queda en main sin desplegar
```

**Según la respuesta:**
- **1 / 2** ⇒ (`db-backup` si el script toca la BD) `./scripts/deploy.sh prod`; luego `curl -fsS -o /dev/null -w '%{http_code}\n' https://<host>/health`, hasta 10 intentos cada 6 s hasta ver 200. Verde ⇒ `[x]` T6, fila `done` en el run-log, `▶ T6 [tier 2] inline/— → done · desviaciones: 0`, handoff a `[closed]`. Rojo ⇒ con la opción 1 ejecuto el rollback del script y te aviso con el log; con la 2 te aviso con el log de deploy y la salida de `/health` y no toco más prod.
- **3** ⇒ te doy `! ./scripts/deploy.sh prod && curl -fsS -o /dev/null -w '%{http_code}\n' https://<host>/health`; cuando digas "hecho", verifico `/health` y cierro T6 igual que arriba.
- **4 / sin respuesta** ⇒ T6 sigue parked; el handoff ya lo dice. Mañana `/fuck-it-we-ball` retoma desde el run-log y vuelve a hacer esta misma pregunta.

**Recap:** T1–T5 quedan en `main` y pusheadas hoy; el deploy a prod no corre por mi cuenta bajo ningún supuesto, pero la pregunta te llega en minutos, antes del vuelo — un toque en "Sí" y está en producción con `/health` verificado antes de que despegues.
