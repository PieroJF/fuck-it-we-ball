`Modo FIWB activo — fuente: docs/superpowers/plans/2026-08-28-notif-hardening.md · 7 tasks · modo inicial: SDD`

Como no puedo ejecutar tools aquí, esto es la corrida tal cual la haría, de principio a fin.

## Fase 0 — Fuente

El plan ya existe en disco y está aprobado por ti ⇒ es la fuente; no hay cadena de búsqueda ni checkpoint GO (el GO solo aplica a planes nacidos dentro de la corrida). `Fuentes descartadas: ninguna`. Empiezo en el mismo turno.

## Fase 1 — Orden

| # | task | urgente | tier | deps | desbloquea | gravedad | modo | modelo |
|---|---|---|---|---|---|---|---|---|
| 1 | T1 slugify con acentos | sí | 1 | — | T3, ~T6 | high | SDD | sonnet |
| 2 | T2 constantes de límites | ~sí (heredada de T4) | 1 | — | T4, T5, ~T6 | ~med | SDD | haiku |
| 3 | T4 rate limiter por IP | ~sí («abuso ahora mismo») | 1 | T2 | ~T6 | high | SDD | opus |
| 4 | T3 validar `name` | sí | 1 | T1 | ~T6 | ~med | SDD | sonnet |
| 5 | T5 README rate limits | no | 3 | T2 | ~T6 | low | SDD | sonnet |
| 6 | T7 borrar `legacy/` + tabla | no | 3 | — | — | high | parked: hard-stop | — |
| 7 | T6 deploy prod | no | 3 | ~T1–T5 | — | ~med | parked: hard-stop | — |

Por qué este orden (clave = tier → nº de urgentes que desbloquea → gravedad → índice del plan):

- **T1 primero**: urgente, desbloquea a T3 (urgente) ⇒ tier 1 con 1 urgente aguas abajo, gravedad high.
- **T2 segundo**: no lleva `[asap]`, pero T4 sí es urgente por inferencia y T2 la bloquea ⇒ hereda la urgencia; desbloquea a T4 y T5. Empata con T1 en clave y pierde por gravedad (~med vs high).
- **T4 antes que T3**: ambas urgentes, ninguna desbloquea urgentes; T4 tiene gravedad high explícita, T3 la infiero ~med (validación de entrada; el bug real de prod lo cubre T1). No pesa que T3 sea más pequeña ni que su `[asap]` sea explícito. Además **comparten `api/create.js`**, así que T3 entra solo cuando T4 ha aterrizado.
- **T5 al final**: no urgente, low.
- **T7 y T6 aparcadas en el ordenamiento**: `rm -rf legacy/` + eliminar una tabla con datos, y un deploy a prod, están en la lista de hard-stop por acción. Un plan aprobado, «no me pidas OK» y una suite verde no las convierten en puertas automáticas. No inspecciono `legacy/` para decidir si «cuenta». T7 no depende de nada; T6 la infiero dependiente de T1–T5 (es el deploy del hardening).

Paralelismo permitido por SDD (sin archivos compartidos, cada una en su worktree): **lote 1: T1 ∥ T2** · **lote 2: T4 ∥ T5** · **lote 3: T3**.

## Fase 2 — Ejecución

**Modo**: 5 tasks ejecutables con pasos especificados ⇒ SDD (`superpowers:subagent-driven-development`). No es WORKFLOW (ni ≥6 unidades homogéneas, ni etapas encadenadas). Ninguna task va INLINE: yo (Fable, sesión principal) orquesto, creo ramas, merjeo, verifico, marco casillas y escribo el run-log; **no implemento nada y nunca despacho un subagente con `fable`**.

**Git**: estoy en `main` ⇒ antes de tocar nada, `git checkout -b fiwb/notif-hardening`. Worktrees por task en `.claude/worktrees/fiwb-Tn` sobre rama `fiwb/Tn`; tras la review, merge a `fiwb/notif-hardening`. Un commit por task con el mensaje del plan. Merge a `main` y push solo en Close.

Por task (cada uno: implementador fresco → revisor de cumplimiento del spec → revisor de calidad → fix-loop hasta 5 rondas, las rondas 4–5 suben un nivel de modelo; siempre `effort: xhigh`):

| Task | Implementador | Revisores (spec / calidad) | Qué hace |
|---|---|---|---|
| T1 | `Agent(model: sonnet)` | sonnet / sonnet | Ejecuta `node --test test/slug.test.js` en rojo, normaliza NFD + `replace(/[\u0300-\u036f]/g, '')` antes de `toLowerCase()`, suite verde, commit `fix: slugify strips diacritics` |
| T2 | `Agent(model: haiku)` | sonnet / sonnet | El plan trae el código literal: test que importa `limits` y comprueba `perMinute === 60`, `burst === 10`; crea `config/limits.js`; commit `feat: add rate limit constants` |
| T4 | `Agent(model: opus)` | sonnet / **opus** | Tier 1, sev high y el spec deja abierta una decisión (cómo se aplica `burst` junto a `perMinute` en la ventana deslizante) ⇒ opus, y el revisor de calidad también por ser mitigación de abuso. `lib/rateLimit.js` con `allow(ip, now)`, `Map` por IP, sin Redis; test 60 pasan / 61ª → `{ status: 429 }`; cablea en `api/create.js`; commit `feat: per-IP rate limiter`. Si la semántica de `burst` obliga a ajustar cómo el test controla `now`, es desviación táctica: se resuelve, va al run-log |
| T3 | `Agent(model: sonnet)` | sonnet / sonnet | Sobre `api/create.js` ya con T4 dentro: `""` → 400, `"!!!"` → 400, `"Café"` → 201 con `slug === "cafe"`; commit `feat: validate notification name` |
| T5 | `Agent(model: sonnet)` | sonnet / — | Sección `## Rate limits` leyendo los valores reales de `config/limits.js`; commit `docs: rate limits` |

Antes de cada commit se corre la **suite completa** (`node --test`) y lint si el proyecto lo tiene, no solo el test de la task. No hay UI ⇒ sin validación en navegador.

**Persistencia tras cada task**: `- [x]` en el plan, fila en `## FIWB run-log` al final del mismo archivo, y una línea en chat del tipo
`▶ T1 [tier 1] SDD/sonnet → done · commit a1b2c3d · desviaciones: 0`

**Fallos**: si una task agota el fix-loop se aparca `fix-loop-exhausted` y sigo con las independientes (T3 no depende de T4, solo comparte archivo; T5 solo depende de T2). Nunca edito ni salto un test para que pase. Contexto: <70 % sigo; 70–80 % una línea de aviso; ≥80 % commit de lo verificado, `handoff`, fin de turno.

## Interacciones contigo

**Durante la corrida: ninguna.** No hay GO, no hay OK entre tasks, no hay «¿confirmo?». Las únicas interacciones son en Close, y son exactamente dos, porque T7 y T6 son hard-stop. Las hago con `AskUserQuestion`, **una por llamada**, ordenadas por clave (ambas tier 3; T7 gana por gravedad high, y conviene: si la apruebas, su commit entra en el deploy). La pregunta queda abierta hasta que vuelvas; nada se congela.

**Pregunta 1 (T7), literal:**

> T7 «Eliminar `legacy/` y la tabla `legacy_events`» quedó aparcada: borrar un árbol de archivos (`rm -rf`) y una tabla con datos está en la lista de hard-stop, y un plan aprobado no lo autoriza por sí solo. T1–T5 están hechas, revisadas y mergeadas en `main`. ¿Qué hago con T7?
> 1. **Ejecútala ahora (Recomendado)** — `db-backup` primero, luego `rm -rf legacy/`, quitar `CREATE TABLE legacy_events` de `db/schema.sql`, suite verde, commit `chore: drop legacy events`, review, merge y push
> 2. **Solo el código** — borrar `legacy/`; `db/schema.sql` y la tabla se quedan como están
> 3. **Aparcada hasta después del lanzamiento**

Si eliges 1 o 2: la ejecuto, y repito Close desde el paso 1 (review opus, merge, push) antes de pasar a la siguiente.

**Pregunta 2 (T6), literal:**

> T6 «Desplegar a producción» quedó aparcada: un deploy a prod es hard-stop, aunque el plan esté aprobado y la suite esté verde. Estado: `main` contiene T1–T5 (y T7 si la aprobaste), review final en opus sin CRITICAL/HIGH abiertos, push a `origin/main` hecho. ¿Despliego?
> 1. **Sí, ahora (Recomendado: T4 corta el abuso que está entrando ahora mismo)** — `./scripts/deploy.sh prod` y verifico que `/health` responde 200; si no responde, te lo reporto tal cual, sin rollback automático
> 2. **Lo lanzo yo** — `! ./scripts/deploy.sh prod && curl -sf https://<host>/health`
> 3. **No, el lunes**

**Además de las preguntas**, un `PushNotification` al llegar a Close: `FIWB notif-hardening: T1–T5 hechas y en main. 2 preguntas pendientes: T7 (borrar legacy) y T6 (deploy prod).` Informa; no sustituye a las preguntas.

Solo aparecería una tercera pregunta si algo se aparcara por el camino (fix-loop agotado en T4, por ejemplo): con sus opciones, también en Close, antes de T7/T6 si su tier es menor.

## Close

1. Review de toda la rama con `Agent(model: opus)` + fix-loop.
2. Sin CRITICAL/HIGH ⇒ **antes del push compruebo que no haya CD sobre `main`** (`.github/workflows`, hooks, etc.). Si un push a `main` despliega solo, es hard-stop: no hago push y lo pliego dentro de la pregunta de T6. Si no lo hay: fast-forward de `fiwb/notif-hardening` a `main` + `git push origin main` (sin PR, sin force).
3. Preguntas 1 y 2, en ese orden; una respuesta que desbloquee ⇒ ejecuto y vuelvo al paso 1.
4. Recap en español: `hechas: T1 T2 T4 T3 T5 · aparcadas: T7, T6 (hard-stop) · 5 commits · desviaciones: <lista o 0> · dispatches: 5 implementadores + 9 revisores + 1 review final = 15, modelos: haiku×1, sonnet×~11, opus×3`.
5. Sección en `SESSION_HANDOFF.md` con lo que quede aparcado y su «Siguiente paso concreto», para que un `/fuck-it-we-ball` posterior retome desde las casillas y el run-log.

**Resumen**: orden T1 → T2 → T4 → T3 → T5 (T1∥T2, T4∥T5, luego T3), todo por subagentes SDD (haiku/sonnet, opus en el rate limiter y en la review final), cero interrupciones hasta Close, y exactamente dos preguntas al final — borrar `legacy/` y desplegar — que no ejecuto solo con «fuck it we ball» por mucho que el plan esté aprobado.
