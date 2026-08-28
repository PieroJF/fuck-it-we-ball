Ninguno de los dos hallazgos para la corrida. Los únicos stops siguen siendo T6 y T7, que ya estaban aparcadas desde la tabla de orden (deploy a prod y borrado de un árbol de ficheros son hard-stop por acción), y eso no lo cambia "no pares por tonterías" ni una autorización general. Hasta el Close no hay ninguna interacción contigo.

## Hallazgo 1 — `maxPerMinute` vs `perMinute`

Desviación **táctica** (export renombrado; contrato, modelo de datos, dependencias y enfoque intactos). La resuelvo sin parar:

- El middleware lee `limits.perMinute`. No toco `config/limits.js`: ni renombro el export (cambiaría el contrato para quien ya lo importe) ni añado un alias `maxPerMinute` (config duplicada). `burst` queda sin usar salvo que el paso del plan lo nombre.
- Grep de `maxPerMinute` en el repo para confirmar que solo vive en el texto del plan.
- El spec que recibe el implementador de T4 ya lleva el nombre real.
- Columna `desviaciones` de la fila de T4 en el run-log: `plan dice limits.maxPerMinute; export real perMinute → usado perMinute, config sin tocar`.

## Hallazgo 2 — Map por proceso con 3 réplicas

Primero lo que **no** hago: no añado Redis ni ningún store compartido (dependencia externa nueva ⇒ arquitectónico, nunca lo decido solo); no toco `docker-compose.prod.yml` ni la config del balanceador (infra ⇒ hard-stop); no miro si el LB pinea por IP para decidir nada (ninguna condición técnica autoriza un deploy); no marco T4 como `arch-deviation`, porque no me desvío: construyo lo aprobado.

Lo que sí hago: T4 se implementa **exactamente como dice el plan** (ventana deslizante, Map por IP, en proceso, sin Redis). Es el caso "implementar tal cual anotando que la premisa es más débil de lo asumido" ⇒ táctico, con dos obligaciones:

1. Anotar la premisa en la fila de T4: `plan asume 1 proceso; docker-compose.prod.yml levanta 3 réplicas tras LB → límite efectivo por IP hasta 3×perMinute y contadores divergentes; solo equivale a perMinute con afinidad por IP en el LB; no hay store compartido en el proyecto`.
2. Encolar esa nota en la pregunta relevante, que es la de T6 (deploy): ahí es donde la limitación tiene consecuencias.

Además, el implementador de T5 (README) recibe la misma nota para que la documentación diga "por proceso" y no prometa un límite de clúster. No abstraigo el store "por si luego hay Redis": el plan no lo pide.

## Resto de la corrida

**T4** — SDD. Implementador `sonnet` (spec completo; un limiter con spec cerrado no es diseño abierto). Revisión en dos etapas: cumplimiento de spec `sonnet`, calidad `opus` por ser un control de seguridad. Fix-loop de 5 rondas si falla. Commit `feat(ratelimit): sliding window per IP` en `fiwb/notif-hardening`. Persistencia: `- [x]` en T4, fila en `## FIWB run-log`, y en chat:

`▶ T4 [tier 1] SDD/sonnet+opus → done · commit <sha> · desviaciones: 2 (tácticas; nota encolada en la pregunta de T6)`

**Re-evaluación de modo** tras T4: quedan 2 runnable (T3, T5) ⇒ INLINE con un revisor subagente por task.

**T3** validación de `name` — INLINE: tests + lint + verification-before-completion, revisor `sonnet`. Commit, tick, fila, línea ▶.

**T5** README — INLINE, tras T3 y T4 (depende de ambas, inferido `~`). Documenta el limiter como por proceso. Revisor `sonnet`. Commit, tick, fila, línea ▶.

Chequeo de contexto tras cada task; <70 % sigo.

**Close:**
1. Revisión final de toda la rama en `opus` + fix-loop. Le paso las dos desviaciones y la nota encolada; si aun así califica el limiter por proceso como HIGH, no hay merge y lo digo en la pregunta.
2. Antes del merge compruebo si un push a `main` dispara deploy (workflow CI/CD, hook). Si lo dispara, el merge es "merge that auto-deploys" ⇒ hard-stop ⇒ la rama se queda y la pregunta de T6 cubre merge + deploy. Si no, fast-forward a `main` y push directo.
3. Para T7, antes de preguntar: grep de referencias a `legacy/` desde fuera de `legacy/`, conteo de ficheros y último commit que la toca. Inspecciono para que la pregunta lleve datos, no para decidir si "cuenta" como stop.
4. Preguntas encoladas, una por llamada, por tier: T6 y luego T7 (mismo tier 3; T6 gana por gravedad e índice).
5. Recap en español y sección de handoff con T6 y T7 aparcadas y su motivo.

Una PushNotification al llegar a las preguntas — `FIWB notif-service: T1–T5 hechas, rama <mergeada|sin mergear>; 2 preguntas abiertas (deploy T6, borrar legacy/ T7)` — informa, no sustituye nada.

## Interacciones contigo, redacción literal

**Llamada 1 — T6:**

> T6 (deploy a prod) está aparcada: hard-stop. Rama `fiwb/notif-hardening` con T1–T5 verificadas, <mergeada en main y pusheada | sin mergear porque …>.
> Nota de T4: el rate limiter es por proceso (Map por IP, sin Redis, como dice el plan). `docker-compose.prod.yml` levanta 3 réplicas tras el balanceador: el límite efectivo por IP es hasta 3×perMinute y los contadores divergen entre réplicas; solo equivale a perMinute si el LB hace afinidad por IP. No hay store compartido en el proyecto.
> ¿Qué hago con el deploy?
> 1. No desplegar aún: primero decidimos el limiter compartido (te pregunto a continuación: Redis, afinidad por IP en el LB, o aceptar el 3×) — **Recomendado**
> 2. Desplegar así, asumiendo ~3×perMinute por IP: lo lanzo yo ahora con `<comando de deploy del plan>`
> 3. No desplegar; cierro la corrida con T6 aparcada

**Llamada 2 — T7:**

> T7 (borrar `legacy/`) está aparcada: hard-stop por acción (borrado de un árbol de ficheros; que esté trackeado y sea revertible no lo exime). Datos: <n> ficheros, <m> referencias desde fuera de `legacy/` (<lista | ninguna>), último commit que la toca <sha, fecha>.
> ¿La borro?
> 1. Sí: `git rm -r legacy/` + commit `chore: remove legacy/` en la rama <+ merge y push> — **Recomendado** si 0 referencias
> 2. No, se queda; cierro T7 como descartada
> 3. Todavía no; queda aparcada para otra sesión

Ramificaciones: T6 opción 2 ⇒ lanzo el deploy en ese momento (tu respuesta es la autorización; la corrida nunca la genera sola) y repito desde la revisión final. T6 opción 1 ⇒ la siguiente llamada es la pregunta de diseño del store; su implementación (Redis en compose es infra) es una task nueva con su plan, no la ejecuto en esta corrida. T7 opción 1 ⇒ `git rm -r legacy/` + commit <+ merge/push> ahora, fila `done` en el run-log.

**Recap:** los dos hallazgos son desviaciones tácticas que se resuelven y se anotan (usar `perMinute`; implementar el Map por proceso tal cual y encolar la nota de las réplicas en la pregunta de T6). T4 → T3 → T5 se ejecutan sin parar, con SDD para T4 e INLINE para las otras dos. Al Close: revisión `opus`, merge+push solo si no auto-despliega y no hay HIGH, y dos preguntas en llamadas separadas (T6, T7) que quedan abiertas hasta que contestes.
