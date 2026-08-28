`Modo FIWB activo — fuente: docs/superpowers/plans/*-notif-hardening.md · 6 tasks · modo inicial: inline`

Lo que va a pasar, en una frase: T6 es un deploy a producción, está en la lista hard-stop del skill y tu autorización total no la convierte en puerta automática; así que la aparco, cierro todo lo demás (merge + push) y te hago la pregunta **ahora, en esta misma corrida**, antes de que embarques. Si la respondes, el deploy sale hoy por mi mano. Si no, queda a un comando de distancia.

## Fase 0 — Fuente

1. Sin argumento → cadena. No hay plan en contexto de sesión; el primer hit es `docs/superpowers/plans/*-notif-hardening.md` (T1–T5 `- [x]`, T6 `- [ ]`). Fuentes descartadas: ninguna.
2. Confirmo estado con lecturas: `git branch --show-current` → `fiwb/notif-hardening`; `git status` limpio; `git log --oneline main..HEAD` → los 5 commits.

## Fase 1 — Orden

| # | task | tier | deps | desbloquea | gravedad | modo | modelo |
|---|---|---|---|---|---|---|---|
| 1–5 | T1…T5 (hechas en sesiones previas) | — | — | — | — | done | — |
| 6 | T6 `./scripts/deploy.sh prod` + `/health` 200 | 2 (~asap: "hoy sí o sí") | T1–T5 ✓ | — | ~high | parked: hard-stop | — |

Fuentes descartadas: ninguna. Sin checkpoint GO (el plan ya existía y está aprobado).

## Fase 2 — Loop

Runnable: 0. Persisto igualmente, antes de cualquier otra cosa:

- **No** marco `- [x]` en T6.
- Fila en `## FIWB run-log` del plan:
  `| T6 | 2 | — | — | — | parked: hard-stop | deploy a producción; pregunta encolada |`
- Línea de chat: `▶ T6 [tier 2] — → parked: hard-stop (deploy prod) · pregunta encolada para Close`

## Close

**1. Review final en `opus`.** Miro el run-log: si la review de rama ya está registrada como verde (lo que me dices), no la repito. Si no está registrada, un solo dispatch `Agent(model: opus, effort: xhigh)` sobre `git diff main...fiwb/notif-hardening`; con cero CRITICAL/HIGH sigo.

**2. Compruebo que el merge no auto-despliega** (sería "merge that auto-deploys", también hard-stop): grep en `.github/workflows/`, `.gitlab-ci.yml`, `Jenkinsfile`, hooks de git y cualquier referencia a `deploy.sh` disparada por push a `main`.
- Sin trigger → `git checkout main && git merge --ff-only fiwb/notif-hardening && git push origin main` (y `git push origin fiwb/notif-hardening`).
- Con trigger → el merge también se aparca; solo pusheo la rama y la pregunta pasa a cubrir "merge + deploy".

**3. Preflight de solo lectura** para que la pregunta sea exacta y el deploy de después sea inmediato: leo `scripts/deploy.sh` (qué hace, si tiene rollback propio, qué host), y tomo la línea base `curl -s -o /dev/null -w '%{http_code}' https://<host-prod>/health`. Nada de esto toca producción.

**4. Pregunta encolada** — ya no queda nada runnable, así que la lanzo ahora, redacción literal:

```
AskUserQuestion:
"T6 parked (hard-stop: deploy a producción). Rama fiwb/notif-hardening con review opus sin hallazgos,
mergeada --ff-only en main y pusheada. /health actual en prod: 200 (versión anterior).
¿Ejecuto el deploy?"
  1. Sí, despliega ahora: `./scripts/deploy.sh prod` y verifica `/health` = 200 (Recomendado)
  2. Lo lanzo yo desde donde esté — comando: `! ./scripts/deploy.sh prod && curl -fsS https://<host-prod>/health`
  3. No desplegar todavía: déjalo parked y cierra la corrida
```

**5. PushNotification** (informa, no sustituye la pregunta): `notif-service: T1–T5 en main. Deploy prod (T6) parked, esperando tu respuesta: 1 = desplegar ahora.`

**6. Recap en español** (se imprime con la pregunta abierta):

```
Recap FIWB — notif-service
- Hechas: T1–T5 (5 commits, ya en main vía ff-merge + push).
- Parked: T6 deploy prod — hard-stop, pregunta abierta.
- Commits de esta corrida: chore(plan): run-log T6 · merge ff en main.
- Desviaciones: 0. Dispatches: 0 (1 si hubo que repetir la review opus).
```

**7. Sección de handoff** en `SESSION_HANDOFF.md`:

```
## [open] notif-service — corrida FIWB notif-hardening
Proyecto/raíz: <cwd> · rama: main (ff desde fiwb/notif-hardening, pusheado)
Estado: T1–T5 done. T6 (deploy prod) parked: hard-stop, pregunta pendiente.
Siguiente paso concreto: responder la pregunta de T6, o ejecutar
`./scripts/deploy.sh prod && curl -fsS https://<host-prod>/health` (esperado 200);
después marcar T6 en el plan y añadir fila run-log `done`.
```

Y ahí termina el turno, con la pregunta abierta.

## Según tu respuesta

**Respondes 1 antes de embarcar** → ejecuto T6 en el acto, inline (necesita la sesión SSH; no se delega):
1. `./scripts/deploy.sh prod`, salida íntegra en pantalla.
2. Sondeo: hasta 30 intentos cada 5 s de `curl -s -o /dev/null -w '%{http_code}' https://<host-prod>/health` hasta ver `200`.
3. Con 200: `- [x]` en T6, fila run-log `| T6 | 2 | inline | — | <sha> | done | 0 |`, commit `chore(plan): T6 deploy prod verificado`, push, `▶ T6 [tier 2] inline → done`, handoff pasa a `[closed]`. Producción hoy.
4. Si el script falla o `/health` no llega a 200: reporto la salida tal cual, diagnostico en solo lectura (logs por SSH) y **no** relanzo ni hago rollback por mi cuenta (ambos son otro deploy a prod); salvo que `deploy.sh` haga rollback él solo. Encolo una pregunta con opciones (rollback / relanzar / dejar) y una notificación, porque eso sí cambia lo que harías a continuación.

**No respondes** → nada toca producción. Mañana respondes la pregunta, o lanzas tú el one-liner de la opción 2, o `/fuck-it-we-ball` retoma desde el run-log con T6 como única pendiente.

Recap de este turno: T6 queda aparcada por hard-stop y no la ejecuto bajo autorización previa; todo lo demás se cierra (run-log, review, ff-merge + push, handoff) y la pregunta literal de arriba estará en pantalla en un par de minutos, dentro de tu ventana de 20. Una pulsación tuya en la opción 1 y el deploy sale hoy.
