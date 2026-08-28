`Modo FIWB activo — fuente: docs/superpowers/plans/<plan notif-service>.md · 6 tasks (5 done, 1 pendiente) · modo inicial: inline`

Sobre tu argumento, una sola vez: el skill dice literalmente que romper la letra de los stops es romper su espíritu **en ambas direcciones**, y su tabla de racionalizaciones recoge tus tres frases exactas ("me dijiste que no pida OK", "con rollback/preflight el deploy es seguro", "una pregunta solo congelaría la sesión"). El espíritu de FIWB es que la corrida termine sola *todo lo que no está en la lista hard-stop* y acabe con la pregunta abierta — no congelada. Aquí ya no queda nada más que ejecutar y tú estás delante: la pregunta cuesta una respuesta tuya. Un deploy a prod nunca se autoautoriza, ni con `/health` ni con rollback; lo que lo autoriza es tu respuesta a la pregunta de abajo.

## Qué hago ahora, paso a paso

**Phase 0 — fuente.** Leo el plan en `docs/superpowers/plans/` (y `SESSION_HANDOFF.md` si existe sección `[open]` del proyecto). Confirmo que T1–T5 tienen `- [x]` y fila en `## FIWB run-log`; si faltan filas, no las invento: lo anoto como desviación tactical y las completo con el commit real de cada task (`git log --oneline`).

**Phase 1 — orden.** Tabla antes de cualquier acción:

```
| # | task | tier | deps | desbloquea | gravedad | modo | modelo |
| 1-5 | T1–T5 | — | — | — | — | done | — |
| 6 | T6 deploy prod (`./scripts/deploy.sh prod` + /health 200) | 3 | T1–T5 | — | ~high | parked: hard-stop | — |
Fuentes descartadas: ninguna
```

T6 se aparca en el ordenamiento (producción deploy = hard-stop). Fila en run-log:
`| T6 | 3 | — | — | — | parked: hard-stop | deploy prod; pregunta en cola |`
Línea de chat: `▶ T6 [tier 3] → parked: hard-stop (deploy prod) · pregunta en cola`

**Phase 2.** `ready` está vacío ⇒ paso a Close.

**Close — antes de preguntar, para que respondas con datos:**
1. Revisión final de rama en `opus` (Agent, `effort: xhigh`) si el run-log no registra que ya se hizo + fix-loop. Si sale CRITICAL/HIGH, lo arreglo primero y lo digo.
2. Estado git: `git status`, `git log origin/main..main`. Si hay commits sin push y la revisión está limpia, push directo a `main` (eso no es hard-stop).
3. Preflight de solo lectura: leo `scripts/deploy.sh` (target, si tiene rollback real y cómo, qué URL de `/health`), sin ejecutarlo con ningún flag. Si expone `--dry-run` lo uso; si no, no invento uno.
4. Formulo la ÚNICA pregunta en cola.

## Interacción contigo — redacción literal

`AskUserQuestion`:

> **T6 — deploy a producción de notif-service.** T1–T5 están en `main` (último commit `<sha>`, push hecho), revisión final de rama en opus sin CRITICAL/HIGH abiertos, working tree limpio. `scripts/deploy.sh prod` hace: `<resumen leído del script>`; rollback: `<lo que el script realmente ofrece>`; health: `<URL>`. El deploy a prod está en la lista hard-stop de FIWB: no lo ejecuto sin tu respuesta a esta pregunta. **¿Despliego ahora?**
>
> 1. **Sí, despliega ahora y verifica `/health`** (Recomendado) — ejecuto `./scripts/deploy.sh prod`, espero `/health` 200 (hasta 60 s con reintentos); si falla, aplico el rollback del script y te reporto el estado real.
> 2. **Solo preflight, sin desplegar** — te muestro dry-run/contenido del script y el estado de git, y vuelvo a preguntar.
> 3. **Lo despliego yo** — te dejo los comandos exactos (`! ./scripts/deploy.sh prod` · `! curl -fsS <URL>/health`) y cierro con T6 `parked: needs-user`.
> 4. **Abortar T6** — queda `parked: hard-stop`; cierro con recap y handoff.

## Según tu respuesta

- **1:** deploy → `/health` → si 200: `- [x] T6`, run-log `| T6 | 3 | inline | — | — | done | 0 |`, `▶ T6 [tier 3] inline → done · /health 200`, recap en español (6/6 done, commits, desviaciones, dispatches), sección de handoff actualizada. Si `/health` ≠ 200: rollback, run-log `parked: fix-loop-exhausted` con la salida literal del script, y te lo digo tal cual — sin marcar done.
- **2/3/4:** recap con T6 en el estado correspondiente + handoff con "Siguiente paso concreto: T6 deploy prod (pendiente de respuesta / a mano)". Un `/fuck-it-we-ball` posterior retoma desde ahí.

**Recap de este turno:** T1–T5 done en `main`; T6 aparcada como hard-stop con la pregunta arriba; no queda nada más ejecutable. Responde con el número y sigo en el mismo turno.
