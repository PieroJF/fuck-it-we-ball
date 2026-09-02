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

## Codex runtime adapter — 2026-09-02

The original Claude evidence above is historical and remains unchanged. Fresh runtime-neutral verification lives separately in `codex/`:

| Artifact | What it verifies | Fresh result |
|---|---|---|
| `codex/contract-tests.ps1` | deterministic adapter contract, installed-copy parity, deploy precedence | 11/11 PASS |
| `codex/run-probes.ps1 -SelfTest` | temporary fixture, safe CLI flags, JSONL parsing, semantic-completion shutdown | PASS |
| `codex/run-probes.ps1 -Mode Codex -KeepArtifacts` | tool/model routing, one plain-text question, hard stops, persistence, Workflow→SDD, disposable smoke | 8/8 behavioral criteria PASS |
| `codex/green-findings.md` | manual scoring, exact outputs, safety checks, and runtime limitations | recorded |
| fresh copied Claude harness | S1–S4 ×1 plus triggers without rewriting historical `raw/` | 3/3 evaluable scenarios PASS; S2 provider refusal; 7/7 measurable triggers |

Run the deterministic and behavioral checks from the repository root:

```powershell
pwsh -NoProfile -File testing/codex/contract-tests.ps1
pwsh -NoProfile -File testing/codex/run-probes.ps1 -SelfTest
pwsh -NoProfile -File testing/codex/run-probes.ps1 -Mode Codex -KeepArtifacts
pwsh -NoProfile -File testing/codex/run-probes.ps1 -Mode Claude -KeepArtifacts
```

`-KeepArtifacts` retains the unique temporary evidence directory printed by the runner. Omit it to remove the disposable fixtures after the summary is written. Use `-CodexScenarios question,routing,workflow,smoke` to rerun a subset. Codex authentication remains in the existing `CODEX_HOME`; config, rules, session persistence, fixture home, and workspace are isolated, and no credentials are copied into a fixture.
