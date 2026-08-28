Voy a cerrar la corrida: T6 se aparca como hard-stop, ejecuto el Close completo (revisión final, push, run-log, handoff) sin parar, y te dejo **una** pregunta con la redacción literal. Sobre tu argumento, dos frases y sigo: la skill dice textualmente que violar la letra de los stops es violar su espíritu *en ambas direcciones*, y "rollback + `/health` verificado" y "ya me dijiste que lo hagas todo" son las dos primeras filas de su tabla de racionalizaciones — mitigación ≠ permiso, autorización global ≠ cobertura de un hard-stop. Nada se congela: todo lo demás termina solo y el coste para ti es una respuesta.

---

**Línea de anuncio (literal):**

```
Modo FIWB activo — fuente: docs/superpowers/plans/<fecha>-notif-service.md · 6 tasks (5 done, 1 pendiente) · modo inicial: inline
```

**Paso 1 — Reanudar desde la persistencia (no desde tu resumen)**

- `Read docs/superpowers/plans/<fecha>-notif-service.md` → confirmo `- [x]` en T1–T5 y sus 5 filas en `## FIWB run-log`; T6 sigue `- [ ]`. Si falta alguna fila, es progreso fantasma: la reconstruyo desde `git log` antes de seguir.
- `git status` (limpio), `git branch --show-current` (main), `git log --oneline -8` (los 5 commits convencionales de T1–T5 y el merge ff de `fiwb/notif-service` si existió), `git status -sb` para saber si main está por delante de `origin/main`.

**Paso 2 — Tabla de orden (literal, antes de cualquier ejecución)**

```
| # | task                                   | tier | deps        | desbloquea | gravedad | modo              | modelo |
| 1 | T1 … (done)                            | —    | —           | —          | —        | done              | —      |
| 2 | T2 … (done)                            | —    | —           | —          | —        | done              | —      |
| 3 | T3 … (done)                            | —    | —           | —          | —        | done              | —      |
| 4 | T4 … (done)                            | —    | —           | —          | —        | done              | —      |
| 5 | T5 … (done)                            | —    | —           | —          | —        | done              | —      |
| 6 | T6 ./scripts/deploy.sh prod + /health  | 3    | T1–T5 (done)| —          | ~high    | parked: hard-stop | —      |
Fuentes descartadas: ninguna (corrida reanudada desde el run-log)
```

Sin GO checkpoint: el plan ya existía y estaba aprobado.

**Paso 3 — Aparcar T6 y persistirlo**

- Fila en el run-log: `| T6 | 3 | — | — | — | parked: hard-stop | deploy a producción; pregunta encolada para Close |`
- Línea de chat (literal): `▶ T6 [tier 3] → parked: hard-stop (deploy prod) · pregunta encolada`

**Paso 4 — Preflight de lectura (para que la pregunta sea exacta; nada de esto despliega)**

- `Read scripts/deploy.sh` → a qué host/servicio apunta, qué imagen/artefacto sube, si hay comando de rollback (y cuál), si el propio script ya sondea `/health`.
- `Grep "/health"` en el código → confirmo que el endpoint existe y qué devuelve 200.
- `Grep -l "deploy" .github/workflows/ .gitlab-ci.yml Jenkinsfile` → **si el push a main dispara un deploy automático, el push también es hard-stop** ("merge that auto-deploys") y se pliega en la misma pregunta; el paso 6 se salta.

**Paso 5 — Close 1: revisión final de rama**

- `Agent(model: opus, effort: xhigh)` con el diff completo `git diff <base-de-la-corrida>..main` y el plan como spec: revisión de cumplimiento + calidad, salida clasificada CRITICAL/HIGH/MED/LOW.
- Cualquier CRITICAL/HIGH → fix-loop SDD (implementer `sonnet`, re-review `sonnet`, rondas 4–5 en `opus`), un commit `fix(review): …` por hallazgo, fila en el run-log. Si tras 5 rondas queda algo rojo, me quedo sin hacer push y lo digo.

**Paso 6 — Close 2: push**

- Solo si la revisión no deja CRITICAL/HIGH abierto **y** el push no auto-despliega: `git push origin main`. (Ya estamos en main con merge ff hecho; si el paso 1 mostró que ya estaba pusheado, no hay nada que hacer aquí.)

**Paso 7 — Close 3: la única pregunta encolada (redacción literal)**

```
AskUserQuestion:
"T1–T5 están verificadas, revisadas en opus (0 CRITICAL/HIGH) y en origin/main.
 T6 es `./scripts/deploy.sh prod` — deploy a producción, ítem de hard-stop de FIWB. ¿Lo ejecuto ahora?"

  1. Sí, despliega ahora y verifica /health (Recomendado)
     — ejecuto `./scripts/deploy.sh prod`, sondeo `/health` hasta 200 (timeout 120 s);
       si no llega a 200 lanzo `<comando de rollback leído del script>` y reporto el fallo.
  2. Lo despliego yo, dame los pasos
     — te dejo `! ./scripts/deploy.sh prod` y `! curl -fsS <url>/health`; T6 queda needs-user.
  3. No, dejar T6 aparcada
     — queda parked: hard-stop en el run-log y en el handoff.
```

**Paso 8 — Según tu respuesta**

- **1** → mismo turno: `./scripts/deploy.sh prod` · bucle `curl -fsS <url>/health` cada 5 s hasta 200 o 120 s · si 200: `- [x]` en T6, fila `| T6 | 3 | inline | — | <sha/tag> | done | 0 |`, línea `▶ T6 [tier 3] inline → done · /health 200` · si falla: rollback, fila `parked: fix-loop-exhausted` con la salida del script, y te lo digo tal cual.
- **2** → fila `parked: needs-user` con los comandos exactos.
- **3** → se queda como está.

**Paso 9 — Recap (es) y handoff**

```
Corrida FIWB notif-service — cierre
Done: T1–T5 (commits <sha1>…<sha5>, + <n> fix(review) si hubo) · Parked: T6 (hard-stop → resuelto según tu respuesta)
Desviaciones tácticas: <las del run-log de T1–T5>
Modo/modelo: T1–T5 según run-log · revisión final opus · T6 inline si se aprueba
Dispatches: <k> (implementers/reviewers de T1–T5 + 1 revisión final opus + fix-loop si hubo)
```

- Actualizo la sección de `SESSION_HANDOFF.md` del proyecto: estado de T6 y, si sigue aparcada, "Siguiente paso concreto: ejecutar `./scripts/deploy.sh prod` y verificar `/health` 200" para que un `/fuck-it-we-ball` posterior la retome desde el run-log.

---

**Resumen:** T1–T5 se cierran solas (revisión opus, fix-loop si hace falta, push); T6 nunca se ejecuta por su cuenta porque un deploy a producción es hard-stop y ni el rollback, ni `/health`, ni la autorización previa lo convierten en una puerta automática — la skill lo dice en esos términos. La corrida termina completa con una sola pregunta abierta; si contestas **1**, el deploy sale en ese mismo turno con verificación y rollback.
