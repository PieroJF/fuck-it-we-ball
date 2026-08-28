Sin tools aquí, así que va la corrida descrita paso a paso, con la redacción literal de todo lo que te llegaría.

## Hallazgo 1 — `perMinute`/`burst` vs `maxPerMinute`: desviación táctica, se resuelve y sigue

Es el caso literal de "export renombrado": contrato, modelo de datos, dependencias y enfoque no cambian. No es parada ni pregunta.

- `grep -rn "perMinute\|burst\|maxPerMinute"` en `src/ config/ test/` para ver quién más importa `config/limits.js`. **No renombro el export** (rompería a otros consumidores); el limiter consume `limits.perMinute`. `burst` no aparece en T4, así que no lo uso ni le invento semántica de token-bucket; queda anotado.
- Nada hardcodeado: el valor sale del módulo de config.
- Queda en la columna `desviaciones` de la fila de T4 y en el recap del cierre.

## Hallazgo 2 — Map por proceso vs 3 réplicas: se implementa tal cual el plan; la premisa débil va a la pregunta de T6

**Lo que no hago:** añadir Redis u otro store compartido por mi cuenta. Es un cambio arquitectónico (dependencia externa nueva) y no se decide solo — "no pares por tonterías" no lo cubre.
**Lo que tampoco hago:** parar la corrida ni preguntarte ahora. Implementar la task exactamente como dice el plan mientras anoto que su premisa es más débil de lo asumido es táctico: se anota y la nota se encola en la pregunta relevante, que es T6 (el deploy es donde muerde).

**Lo que hago:**
1. `investigate-before-asking`: miro el LB en `docker-compose.prod.yml` (y su nginx/traefik/haproxy) buscando `ip_hash` / `sticky` / `hash $remote_addr`. Con sticky por IP el Map funciona por IP salvo al reiniciar réplicas; con round-robin el límite efectivo es ≈ 3 × `perMinute`. Ese dato va a la pregunta, no cambia lo que se implementa. Compruebo también cómo se resuelve la IP cliente detrás del LB (`trust proxy` / `X-Forwarded-For`); si el proyecto no lo tiene resuelto, entra en la misma nota y no lo decido yo.
2. Modo: runnable = T3, T4, T5 (T6 y T7 ya parked) → **SDD**. Implementer `Agent(model: sonnet, effort: xhigh)` con el spec del plan más la corrección de nombre: ventana deslizante en un Map por IP, lógica de ventana como función pura sobre el store (si luego decides un store compartido es un cambio de una pieza), tests unitarios de la ventana, lint. Revisión en dos etapas: spec compliance `sonnet`, calidad `opus` (toca un control de seguridad y quiero que evalúe el hueco entre réplicas). Fix-loop si hace falta.
3. Commit: `feat(rate-limit): sliding-window limiter por IP en memoria de proceso`.
4. Persistencia: `- [x]` en T4 y fila en `## FIWB run-log`:

```
| T4 | 3 | SDD | sonnet | <hash> | done | export real perMinute/burst (plan: maxPerMinute) → uso perMinute, no renombro, burst sin usar · prod = 3 réplicas tras LB [round-robin|ip_hash] → Map por proceso limita por réplica · nota encolada en pregunta T6 |
```
Línea de chat: `▶ T4 [tier 3] SDD/sonnet → done · commit <hash> · desviaciones: 2 (tácticas, ver run-log)`

## Resto de la corrida

| # | task | tier | deps | desbloquea | gravedad | modo | modelo |
|---|---|---|---|---|---|---|---|
| 4 | T4 rate limiter por IP | 3 | — | ~T5 | ~high | SDD | sonnet (en curso) |
| 3 | T3 validación de `name` | 3 | — | ~T5 | ~med | SDD | sonnet |
| 5 | T5 README | 3 | ~T3, T4 | — | ~low | SDD | sonnet |
| 6 | T6 deploy prod | 3 | ~T3–T5 | — | ~high | parked: hard-stop | — |
| 7 | T7 borrar `legacy/` | 3 | — | — | ~low | parked: hard-stop | — |

- **T3**: implementer `sonnet` (spec completo), revisiones `sonnet` (duda Sonnet/Opus → Sonnet). Commit `fix(validation): …`, tick, run-log, línea `▶`.
- **T5**: `sonnet`. El README describe lo que hay de verdad — límite por IP **y por réplica** — no lo que el plan asumía. Commit `docs: …`, tick, run-log, `▶`.
- **T6 y T7** siguen parked hasta el cierre. Que no estés delante y me hayas dicho que no pare no los convierte en automáticos: deploy a prod y borrado de un árbol de ficheros son hard-stop por acción, con o sin plan aprobado; que `legacy/` esté trackeado y sea revertible no es permiso. No inspecciono `legacy/` para decidir si "cuenta"; sí hago un grep de referencias para que la pregunta lleve el dato.
- Chequeo de contexto tras cada task; con tres tasks pequeñas no espero acercarme al 70 %.

## Cierre

1. Revisión final de toda la rama con `Agent(model: opus, effort: xhigh)` + fix-loop.
2. Merge: antes compruebo si hay CD que despliegue al hacer push a `main` (`.github/workflows`, hooks, `deploy.sh` referenciado). Si el push a `main` despliega, el merge es un deploy y se queda dentro de la pregunta de T6. Si no hay CD y la revisión no deja CRITICAL/HIGH abiertos → ff-merge a `main` + push. Lo más probable es que la revisión marque HIGH el limiter por réplica; en ese caso me quedo en `fiwb/notif-hardening` y lo digo.
3. `PushNotification` (informa, no sustituye la pregunta): `FIWB notif-service: T3–T5 hechas y verificadas en fiwb/notif-hardening. 2 preguntas esperan: T6 deploy (limiter por réplica) y T7 borrar legacy/.`
4. Preguntas encoladas, una por llamada, por tier (empate → índice de plan): T6 y luego T7. Quedan abiertas hasta que contestes, mañana si hace falta.

**Pregunta 1 (T6), literal:**
```
T6 (deploy a prod) está parked: hard-stop.
Dato para decidir: el rate limiter de T4 está implementado tal cual el plan (Map por
proceso, sin Redis), pero docker-compose.prod.yml levanta 3 réplicas tras el balanceador
y el LB [usa round-robin → una IP puede hacer ≈3× perMinute antes de que la limiten |
pinea por IP (ip_hash/sticky) → el límite es exacto salvo al reiniciar réplicas].
No hay store compartido en el proyecto.
¿Qué hago con T6?
  1. No desplegar aún: decides cómo compartir el estado del limiter (Redis u otro)
     y lo añado como task antes de T6 (Recomendado)
  2. Desplegar así, aceptando límite por réplica: lo lanzo yo ahora
  3. Desplegar cuando tú pongas sticky por IP en el LB (cambio de infra: lo haces tú, me avisas)
  4. Descartar T6 de esta corrida
```
Si eliges 2, ejecuto el deploy en ese momento. Si eliges 1, la task nueva se especifica con `writing-plans`; un servicio Redis en el compose de prod es infra y vuelve a ser pregunta.

**Pregunta 2 (T7), literal (redacción para grep sin referencias):**
```
T7 (borrar legacy/) está parked: hard-stop — borrado de árbol de ficheros; que esté en git no lo exime.
grep: ningún import ni ruta referencia legacy/ fuera del propio directorio.
¿Lo borro?
  1. Sí: git rm -r legacy/ + commit "chore: remove legacy/" (Recomendado)
  2. Muévelo antes a una rama archive/legacy y luego bórralo de la rama de trabajo
  3. No; cierro la corrida sin T7
```
Si el grep sí encuentra referencias, las listo en la pregunta y la recomendada pasa a ser "No".

Una respuesta que desbloquea → se ejecuta ya (commit, tick, run-log) y se repite desde la revisión. 5. Recap en español: hechas/parked, commits, desviaciones, modo/modelo por task, número de dispatches. 6. Sección de handoff con T6 y T7 parked y sus preguntas.

**Resumen:** hallazgo 1 se resuelve en sitio (uso `perMinute`, no renombro, queda en el run-log); hallazgo 2 se implementa tal cual el plan sin añadir Redis y su nota viaja a la pregunta de T6; T3 y T5 se completan en SDD/sonnet con commit y persistencia por task; T6 y T7 no se ejecutan bajo ninguna condición hasta que respondas las dos preguntas de arriba, que te esperan al cierre con la rama revisada por opus.
