**Modo FIWB activo — fuente: docs/superpowers/plans/2026-08-28-notif-hardening.md · 7 tasks · modo inicial: SDD**

Como aquí no puedo ejecutar tools, esto es la corrida tal cual la haría, con los textos literales en cada punto.

## Fase 0 — Fuente

El plan existe en disco, está aprobado y lo has leído tú ⇒ es la fuente directa; no recorro la cadena y **no hay checkpoint GO** (solo aplica a planes nacidos dentro de la corrida). Arranco en el mismo turno. Fuentes descartadas: ninguna.

Sobre "no me pidas OK por cada cosa": es exactamente lo que hace el skill entre tasks — cero preguntas durante la corrida. Lo que esa autorización no cubre son dos items de la lista hard-stop (T6 deploy a prod, T7 `rm -rf` + eliminar tabla): se aparcan, no se ejecutan, y se preguntan una vez al cierre.

## Fase 1 — Orden

Inferencias (marcadas `~`):
- T4 no lleva `[asap]`, pero "estamos recibiendo abuso ahora mismo" ⇒ ~urgente.
- T2 no es urgente por sí misma, pero desbloquea T4 ⇒ hereda la urgencia (transitiva) y, como desbloquea ≥1 task, es tier 1.
- Gravedad sin etiqueta: T2 ~med, T3 ~med, T6 ~med.
- T6 y T7 entran en hard-stop **por acción** (deploy prod; `rm -rf` + borrado de tabla) ⇒ aparcadas en la ordenación y no cuentan en el `desbloquea` de nadie.

| # | task | tier | deps | desbloquea | gravedad | modo | modelo |
|---|---|---|---|---|---|---|---|
| 1 | T1 slugify con acentos [asap] | 1 | — | T3 | high | SDD | sonnet |
| 2 | T2 `config/limits.js` | 1 | — | T4, T5 | ~med | SDD | haiku |
| 3 | T4 rate limiter por IP | 2 | T2 | — | high | SDD | sonnet (review calidad: opus) |
| 4 | T3 validar `name` [asap] | 2 | T1 | — | ~med | SDD | sonnet |
| 5 | T5 README rate limits | 3 | T2 | — | low | INLINE (review: sonnet) | — |
| 6 | T7 borrar `legacy/` + tabla | 3 | — | — | high | parked: hard-stop | — |
| 7 | T6 deploy prod | 3 | ~T1–T5 | — | ~med | parked: hard-stop | — |

Fuentes descartadas: ninguna

Por qué este orden y no el del plan:
1. **T1 → T2** (tier 1): empatan en urgentes desbloqueadas (una cada una); gravedad high > ~med ⇒ T1 primero. T2 es trivial pero va segunda porque desbloquea el limitador; el tamaño no es clave.
2. **T4 → T3** (tier 2): ninguna desbloquea nada; gravedad high (T4) > ~med (T3) ⇒ T4 antes aunque en el plan esté después. Si T3 llevara `[sev:high]` explícito, iría antes por índice de plan.
3. **T5** (tier 3), la única que queda.
4. En la cola de preguntas, **T7 antes que T6**: mismo tier, gravedad high > ~med. Además, así, si autorizas T7, entra en la review y el push antes de preguntar por el deploy.

Nada más mostrar la tabla escribo las dos filas de aparcado en el run-log y estas líneas:
```
▶ T7 [tier 3] — → parked: hard-stop (rm -rf legacy/ + eliminación de tabla legacy_events)
▶ T6 [tier 3] — → parked: hard-stop (deploy a producción)
```

## Fase 2 — Ejecución

**Setup:** `git switch -c fiwb/notif-hardening` desde `main`. `backup-before-modify` no aplica (no es controles/pág. web); `db-backup` no aplica a T1–T5 (ninguna toca la BD).

**Modo:** se evalúa por lote (tasks del mismo tier). Al arrancar hay 5 runnable (T6/T7 no cuentan) ⇒ SDD. Lote tier 2: 3 runnable ⇒ SDD. Lote tier 3: 1 runnable, 1 archivo, sin tests ⇒ INLINE. Todo secuencial: T4 y T3 comparten `api/create.js`; T1/T2 podrían ir en paralelo en worktrees, pero T3 y T4 esperan a sus deps de todos modos.

Cada task SDD = 3 dispatches, todos con `model:` explícito y `effort: xhigh`, nunca `fable`: implementador fresco (recibe el texto de la task y sus steps) → revisor de cumplimiento de spec → revisor de calidad de código; fix-loop hasta 5 rondas, las rondas 4–5 suben un tier de modelo (haiku→sonnet, sonnet→opus).

**T1 — SDD / implementador `sonnet`** (spec completa: NFD + `/[\u0300-\u036f]/g`; tier 1 + sev high con spec cerrada sigue siendo sonnet). Step 1 confirma el rojo de `test/slug.test.js`, step 2 normaliza antes del lowercase, step 3 verde. Reviewers `sonnet` + `sonnet`. Commit `fix: slugify strips diacritics`.
```
▶ T1 [tier 1] SDD/sonnet → done · commit <sha1> · desviaciones: 0
```

**T2 — SDD / implementador `haiku`** (transcripción literal: el plan trae el código entero). Test que importa `limits` y comprueba 60/10, módulo, verde. Reviewers `sonnet` + `sonnet`. Commit `feat: add rate limit constants`.
```
▶ T2 [tier 1] SDD/haiku → done · commit <sha2> · desviaciones: 0
```

**T4 — SDD / implementador `sonnet`, revisor de calidad `opus`** (es un control de seguridad con sev high; la spec de implementación está cerrada: `Map` por IP, ventana deslizante en memoria, `allow(ip, now)`, sin Redis). Tests: 60 pasan, la 61ª en el mismo minuto → `{ status: 429 }`; cableado en `api/create.js`. Dos notas que van a la columna `desviaciones` sin parar la corrida:
- *Táctica:* el plan no fija qué hace `burst` (los tests solo pinan 60/61). El implementador elige una semántica, la documenta en JSDoc y la registro en el run-log. Si en vez de eso propusiera Redis o cambiar el contrato de `config/limits.js` ⇒ arquitectónica ⇒ aparcar y preguntar (no debería pasar: el plan lo excluye).
- *Premisa:* limitador por proceso ⇒ con N instancias detrás del LB el límite efectivo por IP es N×60/min. Se implementa tal cual dice el plan y la nota se encola en la pregunta de T6.

Commit `feat: per-IP rate limiter`.
```
▶ T4 [tier 2] SDD/sonnet → done · commit <sha3> · desviaciones: 1 (semántica de `burst` no fijada por el plan: <elección documentada>)
```

**T3 — SDD / implementador `sonnet`.** Tests `""`→400, `"!!!"`→400, `"Café"`→201 con `slug === "cafe"` (T1 ya está en la rama); rechazo con `{ status: 400 }` cuando `slugify(name)` queda vacío. Reviewers `sonnet` + `sonnet`. Commit `feat: validate notification name`.
```
▶ T3 [tier 2] SDD/sonnet → done · commit <sha4> · desviaciones: 0
```

**T5 — INLINE (lo hago yo en la sesión principal; no es un dispatch).** Leo `config/limits.js`, escribo `## Rate limits` con los valores reales, `lint-and-validate` + `verification-before-completion`, y UN revisor `sonnet`. Commit `docs: rate limits`.
```
▶ T5 [tier 3] INLINE → done · commit <sha5> · desviaciones: 0
```

**Persistencia tras cada task:** tick `- [x]` en el plan, fila en `## FIWB run-log` al final del mismo archivo (la sección se crea con T1), línea ▶ en el chat. Los ticks entran en el commit de la task siguiente y los últimos en `chore(fiwb): run-log` al cierre. Si esta sesión muriera a mitad, `/fuck-it-we-ball` retoma desde las cajas y el run-log, no desde los commits.

**Fallos:** rojo/build roto ⇒ `systematic-debugging` + fix-loop. Si T1 agota las 5 rondas ⇒ `parked: fix-loop-exhausted`, T3 ⇒ `blocked-by-parked`, y sigo con T2/T4/T5. Nunca edito, salto ni borro un test para ponerlo en verde.

**Contexto:** con estas tasks no llego ni al 70 %; si llegara al 80 % commiteo lo verificado, invoco `handoff` y cierro el turno.

## Cierre

1. **Review final de toda la rama en `opus`** (`git diff main...fiwb/notif-hardening`) + fix-loop.
2. **Comprobación previa al push:** si un push a `main` dispara despliegue (`.github/workflows`, hooks, CD), el merge sería un "merge que auto-despliega" ⇒ hard-stop: me quedo en la rama, pusheo solo `fiwb/notif-hardening` y el merge pasa a la pregunta de T6. Asumo que no (T6 existe como script manual) ⇒ `git switch main && git merge --ff-only fiwb/notif-hardening && git push origin main`. Si la review dejara CRITICAL/HIGH sin resolver, me quedo en la rama y lo digo.
3. **PushNotification** (informa, no sustituye a las preguntas):
   ```
   FIWB notif-hardening: T1–T5 done y pusheadas en main. 2 preguntas pendientes en la sesión: T7 (borrar legacy/) y T6 (deploy prod).
   ```
4. **Preguntas en cola, una por llamada, por tier.** Primera:
   ```
   AskUserQuestion — "T7 quedó aparcada por hard-stop (rm -rf del árbol `legacy/` + eliminación de la tabla `legacy_events` del schema); ninguna autorización previa la cubre. T1–T5 están mergeadas y pusheadas en `main` (<sha>). ¿Qué hago con T7?"
     1. Dejarla para después del lanzamiento del lunes (Recomendado — no aporta nada al lanzamiento y quitar la tabla no tiene vuelta atrás; `legacy/` sigue en git mientras tanto)
     2. Ejecutarla ahora completa: `rm -rf legacy/` + quitar `CREATE TABLE legacy_events` de `db/schema.sql` + commit `chore: drop legacy events` + re-review opus + push
     3. Solo `rm -rf legacy/` ahora; la tabla se queda en el schema
     4. Quitarla del plan definitivamente
   ```
   Si eliges 2 o 3: la ejecuto, tick + run-log, vuelvo al paso 1 (review opus, ff-merge, push) y solo entonces hago la segunda pregunta:
   ```
   AskUserQuestion — "T6 (deploy a producción) quedó aparcada por hard-stop; el plan aprobado no la autoriza por sí solo. Estado: `main` = <sha> pusheado, suite verde, review final opus sin CRITICAL/HIGH. Nota de T4: el limitador es por proceso; con N instancias detrás del LB el límite efectivo por IP es N×60/min. ¿Despliego?"
     1. Sí: ejecuta `./scripts/deploy.sh prod` y verifica que `/health` responde 200 (Recomendado — el abuso que motiva T4 está ocurriendo ahora y el fix ya está verificado)
     2. Lo lanzo yo: `! ./scripts/deploy.sh prod && curl -sf https://<host>/health`
     3. No desplegar hoy; lo dejamos para el lunes
   ```
   Si eliges 1: deploy, `/health`, tick + run-log. Si no respondes (estás fuera): la corrida termina con la pregunta abierta y la retomo cuando contestes.
5. **Recap** (forma):
   ```
   Corrida FIWB — notif-hardening
   done: T1, T2, T4, T3, T5 · parked: T7 (hard-stop), T6 (hard-stop)
   commits: 5 en fiwb/notif-hardening → ff-merge en main → push origin (main = <sha>)
   desviaciones: 1 táctica (T4, semántica de burst) · 0 arquitectónicas
   modo/modelo: T1 SDD/sonnet · T2 SDD/haiku · T4 SDD/sonnet (+opus review) · T3 SDD/sonnet · T5 INLINE (+sonnet review)
   dispatches: 14 (+ rondas de fix-loop) · review final: opus
   ```
6. **Handoff:** sección `[open]` en `SESSION_HANDOFF.md` (proyecto `notif-service`, rama `main`) con el run-log y "Siguiente paso concreto: responder T7 y T6; `/fuck-it-we-ball` retoma desde el run-log".

## Interacciones contigo — lista completa

- **Durante la corrida: ninguna.** Ni OKs, ni revisiones intermedias, ni preguntas.
- **Al cierre:** 1 PushNotification + 2 `AskUserQuestion` (T7 y luego T6), con la redacción de arriba, esperando tu respuesta el tiempo que haga falta.
- **Lo que no haré aunque el plan lo apruebe y tú lo hayas pre-autorizado:** ejecutar `./scripts/deploy.sh prod` ni `rm -rf legacy/`. Ninguna condición técnica (suite verde, rollback, monitor) convierte esos dos stops en puertas automáticas.

**Recap:** orden real T1 → T2 → T4 → T3 → T5, con T6/T7 aparcadas desde la ordenación; T1–T4 por subagentes SDD (sonnet, haiku, sonnet+opus review, sonnet) y T5 inline con revisor sonnet; review final opus, ff-merge y push a `main` automáticos; las únicas interacciones son una notificación y dos preguntas al cierre, por T7 y T6, en ese orden.
