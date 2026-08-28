Modo FIWB sigue activo — fuente: plan de `notif-service` · 7 tasks (2 done) · modo actual: SDD. No paro por ninguno de los dos hallazgos; T6 y T7 siguen aparcados y se preguntan al Close. Detalle:

## Hallazgo 1 — `{ perMinute, burst }` vs `limits.maxPerMinute`

Desviación **táctica** (export renombrado; contrato, modelo de datos, dependencias y enfoque intactos). El limiter lee `perMinute` de `config/limits.js`. No creo un alias `maxPerMinute` (config duplicada) y no uso `burst` porque el plan no le da semántica — no me la invento. Va a la columna `desviaciones` del run-log y al recap. Sin stop.

## Hallazgo 2 — Map por proceso con 3 réplicas

Implemento T4 **exactamente como dice el plan**: ventana deslizante, Map por IP, memoria de proceso, sin Redis. El plan es explícito en "sin Redis" y la instrucción tiene una sola lectura; lo que hay es una premisa más débil de lo que el plan asumía, y eso es táctico: se anota y la nota se cuela en la pregunta relevante, que es la de T6 (deploy). Lo que **no** hago:

- No añado Redis ni ningún store compartido: nueva dependencia externa = desviación arquitectónica; resolverla yo solo es bandera roja.
- No aparco T4 "para confirmar": "prefiero confirmar" no es un stop.
- No convierto "si el LB hace ip_hash…" en autorización de nada.

Sí miro la config del balanceador (compose / nginx) para que la nota sea precisa: round-robin ⇒ límite efectivo por IP hasta 3×`perMinute`; ip_hash ⇒ límite exacto. Informa la pregunta, no cambia el estado de T6. También compruebo `trust proxy`: detrás de un LB sin él, `req.ip` es la IP del balanceador y el limiter frenaría a todo el mundo junto. Si falta, lo configuro para el salto del LB (config de la app, táctico, anotado).

## T4 — ejecución

Runnables T3, T4, T5 (≥3) ⇒ **SDD**. Dispatch `Agent(model: sonnet, effort: xhigh)`, brief = spec de T4 + "usa `perMinute` de `config/limits.js` (no existe `maxPerMinute`); `burst` no se usa; sin store compartido; clave = IP real del cliente según trust proxy; nada hard-coded; tests con fake timers: bajo límite / en el límite / expiración de ventana / IPs independientes". Revisión en dos etapas: cumplimiento de spec `sonnet`, calidad `opus` (control de seguridad). Fix-loop hasta 5 rondas. Lint + tests verdes. Commit en `fiwb/notif-hardening`: `feat(ratelimit): sliding-window per-IP limiter (in-process Map)`.

Persistencia: `- [x]` T4 en el plan + fila en `## FIWB run-log`:

`| T4 | N | SDD | sonnet (rev sonnet+opus) | <hash> | done | export perMinute/burst ≠ maxPerMinute → usado perMinute, burst sin uso · premisa débil: 3 réplicas tras LB → límite efectivo ≤3×perMinute salvo ip_hash; nota en pregunta T6 |`

Línea en chat: `▶ T4 [tier N] SDD/sonnet → done · commit <hash> · desviaciones: 2 (tácticas)` → check de contexto → siguiente.

## T3, T5

- T3 validación de `name`: SDD, implementer `sonnet`, revisión sonnet/sonnet. Commit `fix(validation): reject invalid name values`. `▶ T3 … → done`.
- T5 README: `sonnet`; documenta el limiter como es (por instancia, no compartido entre réplicas). Commit `docs(readme): …`. `▶ T5 … → done`.

## T6 deploy y T7 borrar `legacy/`

Siguen `parked: hard-stop` desde la ordenación. "No pares por tonterías" no los cubre: deploy a prod y borrar un árbol están en la lista **por acción**; ni el plan aprobado, ni la autorización general, ni que estés fuera los convierten en puerta automática. No ejecuto, no salto: aparcados + una pregunta cada uno al Close. En T7 no inspecciono `legacy/` para decidir si "cuenta" (cuenta); sí hago un grep de referencias vivas para que la pregunta traiga datos.

## Close

1. Revisión de rama completa en `opus` + fix-loop.
2. Compruebo si un push a `main` dispara CD. Si no: ff-merge de `fiwb/notif-hardening` en `main` + push. Si sí: ese merge es un deploy ⇒ no lo hago y entra en la pregunta de T6.
3. `PushNotification`: `FIWB notif-service: T3–T5 hechas, verificadas y mergeadas en main. 2 preguntas pendientes: deploy prod y borrar legacy/.` (informa; no sustituye la pregunta).
4. Preguntas, una por llamada, T6 antes que T7:

**AskUserQuestion — T6**
> T3, T4 y T5 están hechas, verificadas y mergeadas en `main` (commits …). Antes de T6: el rate limiter de T4 está implementado tal como dice el plan (Map por proceso, sin Redis), pero `docker-compose.prod.yml` levanta 3 réplicas tras el balanceador [round-robin, sin ip_hash]: el límite efectivo por IP es hasta 3×`perMinute`, no `perMinute`. ¿Qué hago con el deploy a prod?
> 1. **Desplegar ahora tal cual (Recomendado)** — T1–T5 mejoran prod hoy; el limiter protege parcialmente; abro task de seguimiento para limiter compartido.
> 2. **No desplegar hasta tener limiter compartido** — implica Redis u otro store: decisión de arquitectura, la planifico y te la enseño antes de tocar nada.
> 3. **Desplegar tras fijar ip_hash / sticky por IP en el LB** — cambio de infra: lo haces tú o me das OK explícito para esa config concreta.
> 4. **No desplegar** — la rama queda mergeada y paro aquí.

Respuesta 1 ⇒ ejecuto el deploy ahora (T6 desbloqueada por respuesta), `- [x]`, run-log, `▶ T6 …`, repito desde Close 1. Respuesta 2 ⇒ `writing-plans` para la task nueva, sin implementar en esta corrida. Respuesta 3 ⇒ `parked: needs-user` con los pasos exactos.

**AskUserQuestion — T7**
> T7 pide borrar el árbol `legacy/` (<n> archivos; grep desde `src/`: [sin referencias vivas | referencias en X, Y]). Borrar un directorio está en mi lista de hard-stop aunque esté trackeado en git. ¿Lo borro?
> 1. **Sí, `git rm -r legacy/` + commit (Recomendado si el grep está limpio)**
> 2. **Solo lo que no tenga referencias; el resto lo listo**
> 3. **No borrar; T7 descartada**

Respuesta 1 ⇒ `git rm -r legacy/`, suite verde, commit `chore: remove legacy/`, revisión, ff-merge + push.

5. Recap en español: done/parked, commits, desviaciones (las 2 de T4 + trust proxy si aplicó), modo/modelo por task, número de dispatches.
6. Actualizo la sección de handoff con lo que quede aparcado y su "Siguiente paso concreto".

**Resumen:** hallazgo 1 y hallazgo 2 se resuelven sin parar (T4 tal como está en el plan, con `perMinute` y la premisa débil anotada); T3/T4/T5 salen por SDD con `sonnet` y quedan commiteadas y persistidas; T6 y T7 nunca se ejecutan solos — la corrida termina con esas dos preguntas abiertas esperándote, en ese orden.
