Voy a recorrer la skill `fuck-it-we-ball` tal como se ejecutaría desde este mensaje, sin tools: qué haría en cada fase, qué te preguntaría y con qué texto exacto.

## Precondición (una línea de aviso)

Mi cwd actual es un scratchpad (`/tmp/claude-1000/…/scratchpad/n7`, sin git), no `notif-service`. La corrida real tiene que lanzarse desde la raíz del repo; todo lo que sigue asume que estoy ahí, en `main`.

## Paso 0 — Anuncio y búsqueda de fuente

Primera línea que imprimo:

```
Modo FIWB activo — fuente: enunciado libre (sin plan) · 0 tasks · modo inicial: —
```

Tu argumento es texto libre, así que es el enunciado de trabajo. Aunque me dices que no hay nada, `investigate-before-asking` sigue vigente: compruebo la cadena igual (es barato y evita arrancar sobre una premisa falsa):

1. Contexto de sesión → no hay plan aprobado (este es el primer mensaje).
2. `ls docs/superpowers/plans/*.md docs/plans/*.md` + grep de `- [ ]` → nada.
3. `SESSION_HANDOFF.md` con secciones `[open]`/`[closed-pending]` de este proyecto/rama → nada.
4. Lista de tasks del harness → vacía.

Resultado esperado: **sin fuente**. Y aquí está el punto que tu "arranca ya que tengo prisa" no cambia: escribir código sin plan es exactamente el fallo que esta fase evita. Hago **una** `AskUserQuestion` y no ejecuto nada más hasta que respondas:

```
No hay plan ni tasks pendientes en <raíz absoluta de notif-service> (busqué: contexto,
docs/superpowers/plans, docs/plans, SESSION_HANDOFF.md).
¿Preparo el trabajo antes de ejecutar?
  1. Forging → writing-plans → ejecutar (Recomendado)   — brainstorming/grilling según el estado, plan etiquetado, luego la corrida
  2. Solo writing-plans, ya tengo el spec               — salta el diseño; el plan sale del enunciado tal cual
  3. Dame la lista de tasks y decido yo                 — sin ejecutar nada
  4. Abortar
```

Con prisa, tu atajo es contestar **2**. Pero te aviso qué te ahorras y qué no: tu enunciado deja abiertas al menos cuatro decisiones que alguien tiene que tomar antes de escribir código, y con la opción 2 las toma `writing-plans` (yo) en vez de ti:

- **Dónde vive la dead-letter** (¿tabla/colección en el store que ya usa el servicio, fichero, o un store nuevo?). Si la respuesta es "algo que el repo no tiene" (Redis, BullMQ…), es una dependencia externa nueva ⇒ desviación arquitectónica ⇒ pregunta obligatoria en cualquier caso.
- **Si los reintentos sobreviven un reinicio del proceso** (timers en memoria vs `nextAttemptAt` persistido).
- **Parámetros del backoff** (base, factor, tope, jitter) y si "5 intentos" incluye el primer envío.
- **Qué errores son reintentables** (5xx/timeout/red) vs permanentes (4xx, destinatario inválido → dead-letter directa).

Opción 4 o sin respuesta ⇒ termino e informo de las fuentes buscadas.

## Paso 0b — Si eliges 1: forging → writing-plans

Invoco `forging` con el enunciado (nunca brainstorming/grilling a pelo). Con un requisito así de acotado, forging va a grilling y te hará preguntas del tipo (redacción orientativa; la literal la genera forging sobre el código real):

```
¿Dónde persisten hoy las notificaciones en notif-service? La dead-letter debería ir al mismo store.
  1. <store detectado en el repo> (Recomendado)   2. Fichero JSONL   3. Otro
```
```
¿Un reintento pendiente debe sobrevivir a un reinicio del proceso?
  1. Sí, persistir nextAttemptAt y rehidratar al arrancar (Recomendado)   2. No, timers en memoria
```

Después invoco `superpowers:writing-plans` con el argumento literal:

```
Etiqueta cada task con [asap] si es urgente, [sev:high|med|low], [depends: Tn] y [unblocks: Tn]
```

El plan se escribe en `docs/superpowers/plans/2026-08-28-retry-backoff-dead-letter.md` antes de tocar una sola línea de código. Si eliges **2**, salto forging y writing-plans parte del enunciado tal cual, con mis supuestos escritos en el plan.

## Paso 1 — Orden (tabla antes de ejecutar nada)

Con el plan escrito, calculo tiers. Tu prisa no es `[asap]` (no hay prod rota, deadline explícito ni seguridad), así que todo cae en tier 3 y el orden lo decide gravedad y dependencias. Tabla **ilustrativa** de cómo quedaría un plan típico de 5 tasks (la real sale del plan real):

```
| # | task                                                        | tier | deps   | desbloquea | gravedad | modo | modelo |
| 3 | T3 dead-letter store (persistir tras 5 intentos)            | 3    | —      | T4         | ~high    | SDD  | sonnet |
| 1 | T1 computeDelay(attempt, {base, factor, cap, jitter}) + tests | 3  | —      | T2         | ~med     | SDD  | sonnet |
| 2 | T2 scheduler de reintentos (attempts, nextAttemptAt, rehidratación) | 3 | T1 | T4         | ~med     | SDD  | sonnet |
| 4 | T4 integrar en el pipeline de envío + clasificar errores    | 3    | T2, T3 | —          | ~high    | SDD  | opus   |
| 5 | T5 config por env + docs                                    | 3    | T4     | —          | ~low     | SDD  | sonnet |
Fuentes descartadas: ninguna
```

Modo **SDD** (≥3 tasks ejecutables con pasos especificados). Modelo: `sonnet` para implementar desde spec completo; `opus` en T4 por ser integración cross-módulo con gravedad alta. `fable` nunca en un subagente, en ningún rol.

Como el plan ha nacido dentro de esta corrida (nadie humano lo ha leído), checkpoint GO — segunda y última pregunta obligatoria:

```
¿Ejecuto en este orden?
  1. Sí (Recomendado)   2. Cambiar orden   3. Abortar
```

## Paso 2 — Bucle de ejecución (sin más paradas salvo las listadas)

Antes de la primera task: `git checkout -b fiwb/retry-backoff-dead-letter` (estoy en `main`). `backup-before-modify`/`db-backup` no aplican salvo que el plan toque un esquema local con datos.

Por cada task, en este orden:

1. **Implementador**: `Agent(model: sonnet|opus, effort: xhigh)` fresco con el texto completo de la task.
2. **Revisión en dos etapas** (SDD): revisor de cumplimiento de spec → revisor de calidad de código, ambos `sonnet`; fix-loop hasta 5 rondas, rondas 4–5 escalan a `opus`.
3. `node --test` en verde + lint. Nunca edito, salto ni borro un test para que pase.
4. Un commit por task verificada: `feat(retry): add exponential backoff delay calculator`, etc.
5. **Persistencia** (antes de elegir la siguiente): `- [x]` en el plan, fila en `## FIWB run-log` del mismo fichero, y una línea en chat:

```
▶ T3 [tier 3] SDD/sonnet → done · commit a1b2c3d · desviaciones: 0
```

6. Chequeo de contexto: <70 % sigo; 70–80 % aviso y sigo; ≥80 % commit de lo verificado + skill `handoff` + fin de turno (se retoma con `/fuck-it-we-ball`).

Lo que **no** me para: tamaño de la task, "mejor confirmo", suite verde. Lo que **sí** me para (aparco + encolo UNA pregunta, y sigo con el resto):

- Si una task necesita añadir un store/servicio/dependencia que el plan no nombra ⇒ `parked: arch-deviation`.
- Si los tests de integración necesitan credenciales reales del proveedor (SMTP, push) ⇒ `parked: needs-user`, con los pasos exactos para ti.
- Ningún ítem de hard-stop está previsto aquí (no hay deploy, ni datos borrados, ni migración en prod). Si el plan incluyera "desplegar", esa task se aparca desde la tabla, con autorización previa o sin ella.

Una desviación táctica (un helper existente, un export renombrado, un test ajustado a la firma real) la resuelvo y la anoto en la columna `desviaciones`.

## Paso 3 — Cierre

1. Revisión final de toda la rama en `opus` + fix-loop.
2. Sin CRITICAL/HIGH abiertos ⇒ `git merge --ff-only fiwb/retry-backoff-dead-letter` en `main` + `git push` directo (sin PR, solo dev). Si quedan, me quedo en la rama y lo digo.
3. Preguntas encoladas, una por llamada, por tier; si una respuesta desbloquea tasks, las ejecuto y repito desde 1.
4. Recap en español: done/parked, commits, desviaciones, modo/modelo por task, número de dispatches.
5. Sección de handoff con lo que quedó aparcado.

---

**Resumen:** desde este mensaje, lo único que ocurre antes de que respondas es la búsqueda de fuente y la pregunta de permiso — no hay código, ni rama, ni subagentes, porque no existe plan y la prisa no lo sustituye. Contestando **2** vas por el camino más corto (plan desde tu enunciado, con mis supuestos escritos sobre store, persistencia entre reinicios, parámetros de backoff y clasificación de errores); contestando **1** esas decisiones son tuyas vía forging. En ambos casos hay una segunda pregunta (GO sobre la tabla) y luego la corrida va sola hasta el cierre, con merge ff y push a `main`. Para que esto pase de verdad, lánzame dentro de la raíz de `notif-service` y responde a la primera pregunta.
