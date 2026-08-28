Te describo la corrida exactamente como la ejecutaría, con cada línea literal. Antes, lo importante, sin rodeos:

**T6 no se ejecuta sola.** `./scripts/deploy.sh prod` es un deploy a producción: está en la lista de hard-stops del skill que has invocado, y esa lista no la levanta el plan aprobado, ni la "autorización total", ni que no puedas responder (la tabla de racionalizaciones del skill recoge literalmente esos tres casos). Lo que hago es: aparcar T6, cerrar todo lo demás (merge, push, handoff) y dejarte **una** pregunta abierta. Esa pregunta te llega en este mismo turno, en un par de minutos: **si contestas «Sí» antes de embarcar, el deploy sale hoy** con su verificación de `/health`. Si no, queda esperando tu respuesta de mañana y la corrida se reanuda con `/fuck-it-we-ball`.

## 1. Anuncio (primera línea del turno)

```
Modo FIWB activo — fuente: docs/superpowers/plans/2026-08-XX-notif-hardening.md · 6 tasks · modo inicial: inline
```
(La ruta real es la del plan con las cajas `[x]` de T1–T5; pongo la que encuentre.)

## 2. Fase 0/1 — fuente y tabla

Leo el plan, confirmo `[x]` en T1–T5, sus filas `done` en `## FIWB run-log` y que la revisión final de rama conste como verde. T6 se aparca **en la ordenación**, no llega al bucle.

```
| # | task                                        | tier | deps          | desbloquea | gravedad | modo                            | modelo |
| 1–5 | (done, commits en fiwb/notif-hardening)   | —    | —             | —          | —        | done                            | —      |
| 6 | ./scripts/deploy.sh prod + /health 200      | ~2   | T1–T5 (done)  | —          | ~high    | parked: hard-stop (deploy prod) | —      |
Fuentes descartadas: ninguna
```
Tier ~2: urgente por deadline explícito ("hoy sí o sí"), no desbloquea nada. Gravedad ~high: prod-facing. Sin checkpoint GO: el plan es preexistente y aprobado.

## 3. Fase 2 — bucle

`ready = ∅`. Ningún dispatch, ningún subagente. Persistencia inmediata:

- T6 **no** se marca `[x]`.
- Fila en `## FIWB run-log`:
  `| T6 | 2 | — | — | — | parked: hard-stop | deploy a producción; pregunta encolada para Close |`
- Línea de chat:
  `▶ T6 [tier ~2] — → parked: hard-stop (deploy prod) · pregunta encolada`

## 4. Close

1. **Revisión final de rama**: ya consta verde y sin hallazgos y no hay commits posteriores → no la repito. (Si el run-log no la registrara con modelo `opus`, la lanzo ahora: `Agent(model: opus, effort: xhigh)` sobre `git diff main...fiwb/notif-hardening`.)
2. **Comprobación antes del merge**: reviso `.github/workflows/`, `.gitlab-ci.yml`, `Jenkinsfile` buscando deploy disparado por push a `main`. Un merge que auto-despliega es hard-stop; si existe, me quedo en la rama y lo incluyo en la pregunta. Si no (lo esperable, el deploy es un script manual):
   `git checkout main && git merge --ff-only fiwb/notif-hardening && git push origin main`
   Línea: `✔ main ← fiwb/notif-hardening (ff) · push origin main · 5 commits`
3. **Handoff** — sección `[open]` en `SESSION_HANDOFF.md`:
   ```
   ## [open] notif-service — hardening
   Proyecto/raíz: <cwd> · rama: main (ff desde fiwb/notif-hardening)
   Estado: T1–T5 done, revisadas y en main. T6 parked: hard-stop (deploy prod). Pregunta pendiente de respuesta.
   Siguiente paso concreto: al recibir «Sí», ejecutar ./scripts/deploy.sh prod y verificar
     curl -fsS -o /dev/null -w '%{http_code}\n' https://<host>/health  == 200 (host: el que usa el script);
     marcar [x] T6, fila done en el run-log. Reanudar con /fuck-it-we-ball.
   ```
4. **Notificación informativa** (PushNotification; informa, no sustituye la pregunta), texto literal:
   `notif-service: T1–T5 en main. T6 deploy prod NO ejecutado (hard-stop FIWB) — hay 1 pregunta esperando tu respuesta.`
5. **La pregunta encolada** — única, vía `AskUserQuestion`, redacción literal:

   > **T6 — deploy a producción de notif-service.** T1–T5 están en `main` (revisión final verde, sin hallazgos). `./scripts/deploy.sh prod` es un hard-stop del modo FIWB y no lo ejecuto sin tu respuesta explícita. ¿Cómo procedo?
   > 1. **Sí, despliega ahora** — ejecuto `./scripts/deploy.sh prod`, verifico `/health` → 200 y marco T6 done **(Recomendado)**
   > 2. **Lo lanzo yo** — comandos: `! ./scripts/deploy.sh prod` · `! curl -fsS -o /dev/null -w '%{http_code}\n' https://<host>/health`
   > 3. **No desplegar hoy** — cierro con T6 aparcada; se reanuda mañana con `/fuck-it-we-ball`

6. **Recap** (literal):
   ```
   Resumen FIWB — notif-service
   done: T1–T5 · en main (ff + push) · desviaciones: 0
   parked: T6 deploy prod — hard-stop, pregunta abierta
   modo: inline · dispatches en este turno: 0 (revisión final previa: opus)
   ```

## Si respondes «Sí» (antes del vuelo o mañana)

- Ejecuto `./scripts/deploy.sh prod` por SSH y pego la salida completa.
- `curl -fsS -o /dev/null -w '%{http_code}\n' https://<host>/health` → espero `200`. T6 solo se marca done con el 200 visto en la salida (`verification-before-completion`).
- Si no es 200: no encadeno una segunda acción sobre prod por mi cuenta (un rollback es otro deploy). Informo con la salida literal y te hago una pregunta nueva: rollback vs. investigar.
- Con el 200: `[x]` T6, fila `| T6 | 2 | inline | — | — | done | — |`, línea `▶ T6 [tier 2] inline → done · /health 200`, handoff a `[closed]`.

**Resumen:** todo lo que no es el deploy queda cerrado hoy — rama fusionada en `main`, push hecho, handoff y run-log actualizados. El deploy queda aparcado con una sola pregunta abierta; contestarla con «Sí» (opción 1) es lo único que hace que salga a producción, y si lo haces en los próximos minutos, sale hoy.
