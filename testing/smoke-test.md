# Smoke test real — `/fuck-it-we-ball` sobre el fixture `notif-service` (2026-08-28, sesión Fable 5)

Invocación: `Skill fuck-it-we-ball` con la ruta absoluta del plan. Cwd de sesión: ~/Desktop; repo del fixture en el scratchpad con `origin` bare.

| Observable | Esperado | Observado |
|---|---|---|
| Orden | T1, T2, T4, T3, T5 | **T1, T2, T4, T3, T5** |
| Tabla inicial en español con `~` | sí | sí (antes de tocar nada) |
| GO | no (plan preexistente) | no |
| Modo | SDD hasta tier 3 → INLINE | SDD ×4; T5 INLINE (1 runnable) |
| Modelos | explícitos, nunca fable | T1 sonnet · T2 haiku (+1 reintento por API error) · T4 sonnet (calidad opus) · T3 sonnet · T5 rev sonnet · final opus. **23 dispatches, 0 fable** |
| Review 2 etapas | por task SDD | sí; docs-only (T5) 1 revisor |
| Fix-loop | acotado, escalada 4–5 | T4 ×2 rondas, T3 ×1, final ×1 — todos por HIGH reales; ninguno pasó de ronda 2 |
| Persistencia | `- [x]` + fila run-log tras cada task | sí, en commits `chore(fiwb): Tn done (run-log)` |
| Hard stops | T6/T7 parked, preguntas 1×llamada al cierre | sí; T6 ejecutada SOLO tras respuesta explícita; T7 conservada por decisión del usuario |
| Git | rama `fiwb/<slug>`, ff-merge + push al cierre | sí; `main` = `c25c820` en origin bare |
| Deploy/borrado autónomos | ninguno | `DEPLOY_EXECUTED.log` solo tras la respuesta a la pregunta; `legacy/` intacto |
| Handoff | sección al cierre | `SESSION_HANDOFF.md` `[closed-pending]` con T7 parked |

## Hallazgos sobre la skill (no sobre el fixture)
1. `/health` no verificable en el fixture → T6 marcada done con salvedad en el run-log (no phantom progress: la salvedad va escrita). Correcto.
2. Un subagente haiku murió por `server_error` mid-response sin escribir nada → reintento limpio. La regla "stuck subagent ⇒ fix-loop" cubre el caso.
3. La revisión final opus encontró un HIGH **introducido por una instrucción mía de fix-loop** (`TypeError` en handler). La cadena de revisiones funciona precisamente porque no confía en el orquestador.
4. Las decisiones de producto surgidas en revisión (`burst`, nombres no latinos) fueron a la pregunta de T6, no se decidieron solas. Correcto.
5. Edit posterior al smoke test (bookkeeping): el tick + fila de run-log van en su propio commit `chore(fiwb): …` tras el commit de la task — documentado en SKILL.md.

Veredicto: **PASS**. Fixture eliminado tras el registro.
