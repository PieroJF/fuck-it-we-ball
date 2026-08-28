Esto es lo que haría, en orden y con la redacción literal de cada interacción. Tu "arranca ya" no cambia el primer paso: sin plan escrito el skill prohíbe tocar código (es la fila "Sin plan escrito: código directo" de la tabla de racionalizaciones), así que lo único que aceleras es contestar rápido las dos preguntas que vienen.

## Turno 1 — ahora mismo

**Línea de anuncio (literal):**
```
Modo FIWB activo — fuente: contexto de sesión (enunciado libre, sin plan) · 0 tasks · modo inicial: por determinar (se fija tras writing-plans)
```

**Fase 0 — cadena de fuentes**, en este orden, sin saltarme ninguna aunque me digas que no hay nada:
1. Plan aprobado en el contexto de sesión → no hay.
2. `Glob docs/superpowers/plans/*.md` y `Glob docs/plans/*.md`, buscando `- [ ]` → ninguno.
3. `Read SESSION_HANDOFF.md`, secciones `[open]` / `[closed-pending]` con `Proyecto/raíz` = `notif-service` y rama `main` → no existe.
4. Lista de tasks del harness → vacía.

Nada de leer el sender ni el repo todavía: "nothing else until it is answered".

**Única interacción del turno — `AskUserQuestion` (literal, con tu cwd real sustituido):**
```
"No hay plan ni tasks pendientes en /ruta/a/notif-service (busqué: contexto, docs/superpowers/plans, docs/plans, SESSION_HANDOFF.md).
 ¿Preparo el trabajo antes de ejecutar?"
  1. Forging → writing-plans → ejecutar (Recomendado)   — brainstorming/grilling según el estado, plan etiquetado, luego la corrida
  2. Solo writing-plans, ya tengo el spec               — salta el diseño; el plan sale del enunciado tal cual
  3. Dame la lista de tasks y decido yo                 — sin ejecutar nada
  4. Abortar
```
Cierro el turno y espero. Recomiendo la 1 porque tu enunciado deja abiertas dos decisiones que no son tácticas: **dónde vive el estado de reintentos** y **a dónde va el dead-letter**. Si eso se resuelve solo dentro de la corrida y la respuesta es "hace falta Redis/BullMQ", sería una `arch-deviation` aparcada a mitad de camino; mejor cerrarlo antes.

## Si contestas 1 (recomendado)

**`forging`** con el enunciado. Primero lee el repo (módulo de envío, cómo surge hoy el fallo, si hay DB/store, patrón de config, layout de tests con `node --test`) y solo pregunta lo que el código no responde. Las preguntas exactas dependen de lo que encuentre; las probables, una por llamada, en este orden:

```
"¿Dónde persiste el estado de reintentos (nº de intento, próximo intento, último error)?"
  1. En la misma store que ya usa notif-service para las notificaciones (Recomendado)
  2. En memoria — se pierde al reiniciar el proceso
  3. Store nueva (Redis/BullMQ) — dependencia externa nueva
```
```
"¿Destino del dead-letter tras agotar intentos?"
  1. Tabla/colección `dead_letters` en la store existente, con payload + último error (Recomendado)
  2. Archivo JSONL en disco
  3. Solo log estructurado + evento emitido
```
```
"¿Qué cuenta como fallo reintentable y cómo contamos los 5?"
  1. Reintentar red/timeout/5xx; 4xx va directo a dead-letter. 5 intentos totales (1 + 4 reintentos) (Recomendado)
  2. Igual, pero 1 envío + 5 reintentos
  3. Reintentar todo fallo, sin distinguir
```
Los parámetros del backoff (base 1 s, factor 2, tope, jitter completo) los propongo como default en el spec, no los pregunto.

**`superpowers:writing-plans`** con el argumento literal:
```
Etiqueta cada task con [asap] si es urgente, [sev:high|med|low], [depends: Tn] y [unblocks: Tn]
```
El plan se escribe en `docs/superpowers/plans/2026-08-28-retry-backoff-dead-letter.md`.

**Fase 1 — tabla en pantalla antes de ejecutar.** Forma probable (la real sale del plan; `~` = inferido). No hay `[asap]` — "tengo prisa" no es un deadline ni prod roto — así que todo es tier 3 y el orden lo dan deps → gravedad → índice:

```
| # | task | tier | deps | desbloquea | gravedad | modo | modelo |
| 1 | T2 estado de reintentos en la store (+migración local) | 3 | — | T3, T4 | high | SDD | sonnet |
| 2 | T4 dead-letter al 5º intento | 3 | T2 | T5 | high | SDD | sonnet |
| 3 | T1 backoffDelay(attempt) puro + tests | 3 | — | T3 | ~med | SDD | sonnet |
| 4 | T3 scheduler que reintenta los vencidos | 3 | T1, T2 | T5 | high | SDD | sonnet |
| 5 | T5 integrar en la ruta de fallo del sender + test de integración | 3 | T3, T4 | — | high | SDD | opus |
| 6 | T6 README + variables de entorno | 3 | — | — | ~low | SDD | sonnet |
Fuentes descartadas: ninguna
```

**GO checkpoint** — obligatorio porque el plan nació en esta corrida (nadie humano lo ha leído):
```
"¿Ejecuto en este orden?"   Sí (Recomendado) / Cambiar orden / Abortar
```

**Fase 2 — corrida sin más paradas.** Modo SDD (≥3 tasks con pasos especificados; ninguna es "misma forma" para WORKFLOW). Yo no implemento nada: un subagente `Agent(model: sonnet, effort xhigh)` fresco por task, secuencial (comparten archivos). Nunca `fable` en subagente.
- Git: estás en `main` ⇒ `git checkout -b fiwb/retry-backoff-dead-letter` antes del primer cambio. Si T2 añade migración sobre una DB real, `db-backup` antes.
- Por task: implementador → `node --test` + lint → revisión en dos etapas (cumplimiento del spec → calidad) → fix-loop hasta 5 rondas (4–5 suben a opus) → un commit (`feat(retry): estado de reintentos con nextAttemptAt`, etc.) → `- [x]` en el plan → fila en `## FIWB run-log` → línea en chat:
  ```
  ▶ T2 [tier 3] SDD/sonnet → done · commit 3f9a1c2 · desviaciones: 0
  ```
- Stops que podrían saltar aquí (aparcan la task y encolan UNA pregunta para el Close, la corrida sigue): el implementador concluye que hace falta una store nueva → `parked: arch-deviation`; el tope de 5 no cuadra con un contador que ya exista en el modelo → tacticalidad si no cambia el contrato, pregunta si sí. Ningún `deploy`, nada de tocar prod.

**Close:** revisión de toda la rama en `opus` + fix-loop. Antes de fusionar compruebo si `main` tiene CD (`.github/workflows` con deploy en push): si lo tiene, la fusión **es** un deploy ⇒ queda aparcada y te la pregunto; si no, ff-merge a `main` + `git push` directo (sin PR). Después, preguntas encoladas una por llamada por tier, recap en español (done/parked, commits, desviaciones, modo/modelo por task, nº de dispatches) y sección de handoff con lo que quedó aparcado.

## Si contestas otra cosa

- **2:** salto forging; `writing-plans` decide persistencia y destino del DLQ a partir de lo que vea en el repo. Sigue la misma tabla y el mismo GO. Riesgo: si la lectura exige dependencia nueva, aparece como `arch-deviation` a mitad de corrida en vez de resolverse en 30 segundos ahora.
- **3:** te devuelvo la lista de tasks etiquetada; no ejecuto nada.
- **4 o sin respuesta:** termina la corrida con la lista de fuentes buscadas.

## Resumen

Desde este instante: anuncio, cuatro búsquedas de fuente, una pregunta de permiso y espero. Con la opción 1 tendrás 2–3 preguntas de diseño de forging, una de GO, y a partir de ahí cero interrupciones hasta el Close salvo que salte un stop de la lista. El progreso queda en las cajas y el run-log del plan: si se corta el contexto, `/fuck-it-we-ball` retoma desde ahí.
