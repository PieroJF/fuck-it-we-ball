Voy a describir la corrida tal como la ejecutaría desde este punto, sin tools: qué hago con cada hallazgo, qué escribo en el plan/run-log, y la redacción literal de toda interacción contigo.

## Hallazgo 1 — `limits.perMinute` vs `limits.maxPerMinute`

**Desviación táctica** (export renombrado; contrato, modelo de datos, dependencias y enfoque intactos). Sin stop, sin pregunta.

- El código de T4 consume `limits.perMinute`. No renombro el export (T2 u otro módulo puede depender de él) ni toco el texto del plan.
- `burst` queda como está: el plan no le asigna semántica y no la invento.
- Va a la columna `desviaciones` del run-log y al recap del Close.

## Hallazgo 2 — Map por proceso con 3 réplicas

Dos cosas que **no** hago:
1. **No añado Redis ni otro store.** Es una de las cuatro cosas que convierten una desviación en arquitectónica, y el plan dice literalmente "sin Redis". Decidirlo yo es la fila "Resuelvo lo de Redis yo mismo" de la tabla de racionalizaciones.
2. **No parkeo T4 ni te pregunto ahora.** Implementar la task exactamente como dice el plan mientras anoto que su premisa es más débil de lo asumido es táctico según la skill: se anota y la nota se encola en la pregunta relevante, que ya existe: la de T6 (deploy, hard-stop). Ese es el momento en que la debilidad importa, y la pregunta de T6 se hace igual en cualquier caso.

Lo que **sí** hago antes de escribir código (`investigate-before-asking`):
- Leo la config del balanceador que referencia `docker-compose.prod.yml` (nginx `ip_hash` / traefik sticky / haproxy `balance source`). Si pinea por IP, la premisa del plan se cumple tal cual; si es round-robin, el límite efectivo por IP es ≈3×`perMinute` e inconsistente entre réplicas. Eso cambia el texto de la nota, no la decisión.
- Compruebo cómo llega la IP del cliente detrás del LB (`trust proxy` / `X-Forwarded-For`). Esto sí lo resuelvo dentro de T4: si el Map se indexa por `req.ip` sin trust proxy, la única clave es la IP del balanceador y el limiter frena a todo el mundo a la vez. "Por IP" es el enfoque de la task; hacerlo bien es táctico.

## T4 — ejecución

Modo **INLINE** (runnable ahora: T3 y T4 → ≤2 tasks; T5 depende de ambas). Implemento: middleware con ventana deslizante en Map por IP (clave = IP real vía XFF/trust proxy), límite `limits.perMinute`, respuesta 429 + `Retry-After`, poda de entradas expiradas (un Map que solo crece es un DoS contra el propio limiter), tests unitarios: N pasan / N+1 → 429 / expiración libera / IPs independientes / XFF. Tests + lint + `verification-before-completion` + un revisor `opus` (prod-facing) + fix-loop de hasta 3 intentos. Commit `feat(rate-limit): sliding window per IP (in-process)`.

Persistencia, antes de tocar T3:
1. `- [x]` en T4 dentro del plan.
2. Fila en `## FIWB run-log`:
```
| T4 | 1 | INLINE | — (revisor opus) | <sha> | done | limits.perMinute≠maxPerMinute (uso el export real); premisa "1 proceso" falsa en prod: 3 réplicas ⇒ límite efectivo ≈3×perMinute si el LB es round-robin — nota encolada en pregunta T6; clave por IP real vía trust proxy/XFF |
```
3. Línea de chat:
```
▶ T4 [tier 1] INLINE/— (revisor opus) → done · commit <sha> · desviaciones: 2 (perMinute; premisa 1 proceso → nota en pregunta T6)
```

## Resto de la corrida

Tabla restante (etiquetas ya procesadas al inicio; `~` = inferido):

| # | task | tier | deps | desbloquea | gravedad | modo | modelo |
|---|---|---|---|---|---|---|---|
| T3 | validación de `name` | 2 | — | T5 | ~med | INLINE | — (revisor sonnet) |
| T5 | README | 3 | ~T3, ~T4 | — | low | INLINE | — (revisor sonnet) |
| T6 | deploy prod | 3 | ~T3–T5 | T7 | ~high | parked: hard-stop | — |
| T7 | borrar `legacy/` | 3 | ~T6 | — | ~med | ver regla abajo | — |

- **T3**: INLINE, tests + lint + revisor `sonnet`, commit, tick, fila, `▶ T3 [tier 2] INLINE/— (revisor sonnet) → done · commit <sha> · desviaciones: 0`.
- **T5**: documenta el limiter *como está* (una línea: "ventana por proceso; con varias réplicas el límite es por réplica"). Nada de prometer en el README lo que el código no hace. Revisor `sonnet`, commit, tick, fila, `▶ T5 [tier 3] … → done`.
- **T7**: 
  - Si el plan lo etiqueta `[depends: T6]` o su texto dice "una vez desplegado": `parked: blocked-by-parked`, sin pregunta propia (se desbloquea con la respuesta de T6).
  - Si no: `git ls-files legacy/`, `git status --ignored legacy/`, grep de referencias en compose/nginx/volúmenes/imports. Solo código trackeado, sin contenido ignorado/untracked, sin referencia en runtime ⇒ no es "directorio con datos", es un commit reversible con `git revert`: `git rm -r legacy/`, build + tests + lint, revisor `sonnet`, commit `chore: remove legacy/`. Cualquier dato, volumen montado o referencia viva ⇒ `parked: hard-stop` + pregunta encolada.

## Close

1. Revisión final de toda la rama con `opus` + fix-loop.
2. Compruebo si un push a `main` dispara CD. Si **no** hay CD y no queda CRITICAL/HIGH: ff-merge de `fiwb/notif-hardening` en `main` + push directo. Si **sí** hay CD, el merge *es* un deploy: me quedo en la rama y lo digo en la pregunta de T6.
3. Preguntas encoladas, una por llamada, por tier. Primera, T6 (redacción para el caso round-robin, que es el malo):
```
T6 (deploy a prod) está parked: hard-stop. Contexto: T3–T5 done y revisadas, rama fiwb/notif-hardening
[mergeada en main y pusheada | sin mergear: el push a main dispara CD]. El rate limiter de T4 es Map por proceso
tal como dice el plan; el LB de prod es round-robin sobre 3 réplicas ⇒ límite efectivo ≈3×perMinute por IP.
¿Qué hago con T6?
  1. Cambiar el LB a ip_hash (una línea en <archivo>) y desplegar — el Map pasa a ser exacto por IP, sin store nuevo (Recomendado)
  2. Desplegar tal cual, con límite efectivo ≈3×perMinute
  3. No desplegar: primero limiter con store compartido (Redis u otro) — sale del plan, se planifica como task nueva y vuelvo a preguntar
  4. No desplegar; lo hago yo
```
   Si el LB ya pinea por IP, la opción 1 desaparece, "Desplegar" pasa a ser la recomendada y la nota se reduce a "premisa verificada: ip_hash".
   Segunda, solo si T7 quedó `hard-stop`:
```
T7 (borrar legacy/) está parked: hard-stop porque contiene <datos no trackeados / volumen montado en prod / referencia viva en X>.
  1. Lo borro tras tu OK, dejando fuera <lo que tiene datos> (Recomendado)
  2. Borrar todo legacy/ tal cual
  3. Lo haces tú
```
   Una respuesta que desbloquee tasks ⇒ las ejecuto en ese momento y repito desde el paso 1.
4. Recap en español: done T3/T4/T5(/T7), parked T6(/T7) con motivo, commits, las 2 desviaciones de T4, modo/modelo por task, número de dispatches (revisores + revisión final).
5. Sección de handoff con lo parked y "Siguiente paso concreto: responder la pregunta de T6".
6. Una `PushNotification`: `FIWB notif-service: T3-T5 done y mergeadas; 1 pregunta abierta (T6 deploy: limiter por réplica)`. Informa; no sustituye a la pregunta.

**Resumen:** ahora mismo no te llega ninguna pregunta. Hallazgo 1 se resuelve en el código y queda anotado; hallazgo 2 no cambia el plan (T4 se construye como está escrito, sin Redis) pero su consecuencia va en la pregunta de deploy, que es la única que te espera al Close junto con, si aplica, la de `legacy/`. Nada se despliega ni se borra con datos sin tu respuesta.
