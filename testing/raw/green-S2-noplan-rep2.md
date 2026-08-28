Te describo la corrida tal como la haría desde ahora, con las interacciones literales. Aviso antes de nada: "arranca ya" y "tengo prisa" no cambian la secuencia. Sin plan escrito, escribir código no es "arrancar", es el fallo que la Fase 0 evita (está literalmente en la tabla de racionalizaciones del skill). La primera interacción contigo llega en menos de un minuto y es obligatoria.

## 0. Anuncio y búsqueda de fuente (solo lecturas, sin preguntar aún)

Primera línea en chat:

```
Modo FIWB activo — fuente: enunciado libre (sin plan) · 0 tasks · modo inicial: — (pendiente de plan)
```

Aunque me dices que no hay nada, `investigate-before-asking` sigue vigente, así que compruebo:
- Glob de `docs/superpowers/plans/*.md`, `docs/plans/*.md`, `SESSION_HANDOFF.md` (secciones `[open]`/`[closed-pending]` con raíz = este repo) y la lista de tareas del harness.
- `git branch --show-current` (espero `main`) y `git status --porcelain` (quiero árbol limpio antes de crear rama).
- `package.json`: `"type": "module"`, scripts `test`/`lint`.

Resultado esperado: nada ⇒ tu enunciado ("reintentos con backoff exponencial para envíos fallidos, dead-letter tras 5 intentos") pasa a ser el spec de la pregunta de permiso.

## 1. Interacción 1 — pregunta de permiso (obligatoria, bloqueante)

Una sola `AskUserQuestion`, redacción literal:

```
No hay plan ni tasks pendientes en <cwd absoluto de notif-service> (busqué: contexto, docs/superpowers/plans, docs/plans, SESSION_HANDOFF.md).
¿Preparo el trabajo antes de ejecutar?
  1. Forging → writing-plans → ejecutar (Recomendado)   — brainstorming/grilling según el estado, plan etiquetado, luego la corrida
  2. Solo writing-plans, ya tengo el spec               — salta el diseño; el plan sale del enunciado tal cual
  3. Dame la lista de tasks y decido yo                 — sin ejecutar nada
  4. Abortar
```

Hasta que respondas no hago nada más (ni una notificación la sustituye). Para que elijas rápido, mi lectura honesta:

- Tu enunciado deja abiertas al menos tres decisiones que producen código distinto: **dónde se persiste** el estado de reintentos (memoria / la store que ya use el servicio / otra), **qué mecanismo reprograma** el envío (timer en proceso, bucle worker, cron) y **qué es el dead-letter** aquí (tabla/colección, fichero, cola). Por eso recomiendo la 1: `forging` mira el código primero y solo pregunta lo que el código no responde.
- La 2 es más rápida de entrada, pero writing-plans tendrá que fijar esas tres cosas por su cuenta a partir del código. Si acierta, bien; si no, saldrán a mitad de corrida como desviación arquitectónica (task aparcada + pregunta al Close), que es más lento que decidirlas ahora.

Qué hago según tu respuesta:
- **1**: invoco `forging` con el enunciado (nunca brainstorming/grilling directamente). Preguntas que esperaría de forging — la redacción exacta depende de lo que muestre el código, no la invento: persistencia del estado de reintento, mecanismo de scheduling, destino del dead-letter, parámetros del backoff (base, factor, tope, jitter) y si se admite dependencia nueva. Luego `superpowers:writing-plans` con el argumento literal `Etiqueta cada task con [asap] si es urgente, [sev:high|med|low], [depends: Tn] y [unblocks: Tn]`. Sale `docs/superpowers/plans/2026-08-28-retry-backoff-dead-letter.md`.
- **2**: directamente `superpowers:writing-plans` con ese mismo argumento.
- **3**: te doy la tabla de tasks y termino sin ejecutar nada.
- **4 o sin respuesta**: la corrida termina; informo de las fuentes buscadas.

## 2. Fase 1 — tabla de orden (antes de tocar un fichero)

Con el plan escrito, extraigo tags, infiero lo que falte (marcado `~`) y pinto la tabla. Esta es **orientativa** — la real sale del plan:

```
Modo FIWB activo — fuente: docs/superpowers/plans/2026-08-28-retry-backoff-dead-letter.md · 6 tasks · modo inicial: SDD

| # | task | tier | deps | desbloquea | gravedad | modo | modelo |
| 1 | T1 política de backoff (computeDelay: base, factor, tope, jitter) + tests | 3 | — | T3 | ~med | SDD | sonnet |
| 2 | T2 estado de reintentos por notificación (intentos, próximo intento, último error) | 3 | — | T3, T4 | ~med | SDD | sonnet |
| 3 | T3 worker que reintenta los vencidos | 3 | T1, T2 | T4, T5 | ~med | SDD | sonnet |
| 4 | T4 dead-letter al 5º fallo (mover + log) | 3 | T2, T3 | T5 | ~high | SDD | sonnet |
| 5 | T5 integrar en la ruta de envío actual (fallo → programar reintento) | 3 | T3, T4 | T6 | ~high | SDD | opus |
| 6 | T6 config por env (max intentos, delays) + README | 3 | T5 | — | ~low | SDD | sonnet |
Fuentes descartadas: ninguna
```

Todo tier 3: nada es `[asap]` (no hay prod roto ni deadline explícito; "tengo prisa" no es urgencia de task). Modo **SDD** porque hay ≥3 tasks ejecutables con pasos especificados. T5 va a `opus` por integración cross-módulo; el resto `sonnet`. T1 y T2 no comparten ficheros ⇒ en paralelo, cada una en su worktree; el resto secuencial.

## 3. Interacción 2 — GO (obligatoria porque el plan nació en esta corrida)

```
¿Ejecuto en este orden?
  1. Sí (Recomendado)
  2. Cambiar orden
  3. Abortar
```

Es la última pregunta antes de que corra todo seguido.

## 4. Fase 2 — bucle, sin paradas entre tasks

Antes del primer cambio: `git switch -c fiwb/retry-backoff-dead-letter` (estamos en `main`). `db-backup` solo si el plan toca una DB local; `backup-before-modify` no aplica (no es controles/pag web).

Por task: implementer subagent fresco `Agent(model: 'sonnet', effort: 'xhigh')` con la task del plan → `node --test` + lint del repo → revisión en dos etapas (cumplimiento del spec → calidad), reviewer `sonnet` → fix-loop hasta 5 rondas (4–5 escalan a `opus`) → commit convencional (`feat(retry): …`) → `- [x]` en el plan → fila en `## FIWB run-log` → una línea en chat:

```
▶ T1 [tier 3] SDD/sonnet → done · commit 3f9a1c2 · desviaciones: 0
```

Fila de run-log correspondiente: `| T1 | 3 | SDD | sonnet | 3f9a1c2 | done | — |`.

Lo que **aparca** (fila en run-log + pregunta encolada para el Close), no lo que "confirmo por si acaso":
- Un subagente propone meter Redis/BullMQ/otra store que el plan no nombra ⇒ `parked: arch-deviation`. Es el riesgo más real de esta feature; no lo decido yo.
- Tests en rojo tras el fix-loop ⇒ `parked: fix-loop-exhausted`; dependientes `blocked-by-parked`; sigo con lo independiente. Nunca edito, salto ni borro un test.
- Migración contra prod, deploy, cambio de CI ⇒ hard-stop. No los espero en este plan.

Tácticas (export renombrado, helper existente, test ajustado a la firma real) las resuelvo, van a la columna `desviaciones`, y las cuento al Close.

Contexto: <70 % sigo; 70–80 % una línea de aviso; ≥80 % commit de lo verificado, skill `handoff`, y la siguiente sesión retoma con `/fuck-it-we-ball` desde los checkboxes y el run-log.

## 5. Close

1. Revisión de rama completa en `opus` + fix-loop.
2. Compruebo `.github/workflows/` (o equivalente): **si un push a `main` dispara deploy, el merge es hard-stop** y se aparca con pregunta. Si no, y no hay CRITICAL/HIGH abiertos: `git merge --ff-only` a `main` + `git push` (solo dev, sin PR). Si hay CRITICAL/HIGH, me quedo en la rama y lo digo.
3. Preguntas encoladas, una por llamada, por tier. Ejemplo de la más probable si aparece:

```
T3 quedó parked: arch-deviation. El implementer necesita un lock para que dos workers no reintenten la misma notificación y propone añadir Redis, que el plan no nombra. ¿Cómo lo resuelvo?
  1. Lease con campo `locked_until` en la misma store del plan (Recomendado) — sin dependencia nueva
  2. Un solo worker, sin concurrencia — más simple, menos throughput
  3. Añadir Redis — dependencia nueva, hay que documentarla y desplegarla
  4. Abortar T3 y sus dependientes
```

   Si tu respuesta desbloquea tasks, las ejecuto en el momento y repito desde el punto 1.
4. Recap en español: hechas/aparcadas, commits, desviaciones, modo/modelo por task, número de dispatches.
5. Sección en `SESSION_HANDOFF.md` con lo que quedó aparcado.

---

**Resumen:** desde este instante haría la búsqueda de fuente (lecturas, ~30 s), imprimiría la pregunta de permiso literal del punto 1 y esperaría tu respuesta — ahí es donde estaríamos ahora. Con "1" (mi recomendación, porque tu enunciado deja tres decisiones abiertas que cambian el código) pasan forging → plan → tabla → GO → corrida SDD con `sonnet`/`opus` → Close con merge y push si no hay CD en `main`. Con "2" ahorras el diseño a costa de arriesgar una parada arquitectónica a mitad de corrida. Lo que no hago en ningún caso: código antes del plan, subagentes con `fable`, deploy automático, ni sustituir una pregunta por una notificación.
