# Evidencia TDD — fuck-it-we-ball (2026-08-28)

Instrumento: `claude -p --safe-mode --strict-mcp-config --model fable --effort xhigh --disallowed-tools <all>` + prompt por stdin + cwd neutro (`scratchpad/n7`). Brazo GREEN añade `--append-system-prompt-file SKILL.md`.

- instrument: probe 3/3 NO LA CONOZCO (`raw/red-probe-instrument-rep{1,2,3}.md`)

| Archivo | Qué mide | Resultado |
|---|---|---|
| `raw/red-probe-instrument-rep{1,2,3}.md` | instrumento válido | 3/3 NO LA CONOZCO |
| `red-findings.md` + `raw/red-*` | RED baseline S1–S4 ×3 (Fable) | FAIL 3/3 en los 4 escenarios; 10 patrones de racionalización |
| `green-findings.md` + `raw/green-*`, `raw/round1/`, `raw/round2/` | GREEN r1/r2/r2b | S1/S2/S3/S4 3/3 tras 2 rondas; loophole "código trackeado ⇒ reversible" cerrado |
| `raw/green-P{1,2,3}-*` | probes adversariales (sunk cost, CTO por escrito, espíritu vs letra) | 6/6 |
| `triggers-result.md` | disparo de la description (8 frases) | 7/7 frases; slash no medible en `-p --safe-mode` |
| `smoke-test.md` | corrida real en sesión sobre el fixture | PASS · 23 dispatches, 0 fable · fix-loops con HIGH reales |
| `scenarios/`, `run-arm.sh`, `run-triggers.sh`, `make-fixture.sh`, `fixture-plan.md` | harness reproducible | — |

Total corridas Fable en `claude -p`: 40 (+ 8 triggers). Skill final: `../SKILL.md`; backup `../SKILL.v1.md`.
