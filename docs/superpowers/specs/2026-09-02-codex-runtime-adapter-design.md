# FIWB Cross-Runtime Adapter Design

## Purpose

Keep the proven Claude Code behavior of `fuck-it-we-ball` while making every mandatory instruction executable in Codex. Runtime differences must never weaken hard stops, persistence, review, or the one-question rule.

## Confirmed constraints

- Claude Code 2.1.251 remains supported without behavioral regression.
- Codex CLI 0.152.1 and the Codex desktop collaboration tools are the second supported runtime.
- Runtime selection is capability-based. The skill must not assume that a tool or model alias exists merely because a runtime usually provides it.
- The current RED/GREEN evidence remains historical Claude evidence until a separate Codex harness passes.
- Existing uncommitted changes to `SKILL.md` are preserved and incorporated, never discarded.

## Decision log

### 1. Runtime dispatch adapter — compatibility

Elegido: define a compact adapter before Phase 0, backed by a marked JSON contract that tests can parse structurally. Claude uses `Agent`, `AskUserQuestion`, `TaskCreate/TodoWrite`, and `Workflow` when present. Codex uses `spawn_agent`, a single plain-text question at the end of a turn, and no harness task-list source unless one is actually exposed.

Por qué: tool names are runtime contracts, not prose synonyms.

### 2. Model mapping — compatibility

Elegido: preserve semantic roles instead of provider names.

| Role | Claude | Codex |
|---|---|---|
| implementation | `sonnet` | `gpt-5.6-terra` |
| high-judgment/final review | `opus` | `gpt-5.6-sol` |
| trivial/mechanical | `haiku` | `gpt-5.6-luna` |

Every dispatch uses the maximum supported effort requested by the host instructions, currently `xhigh`.

### 3. Workflow fallback — orchestration

Elegido: WORKFLOW is eligible only when the Claude Workflow tool is callable. Otherwise the same batch uses SDD. The absence of Workflow is a routing condition, not a stop and not permission to run everything inline.

### 4. Questions — interaction

Elegido: use `AskUserQuestion` when callable. Otherwise ask exactly one plain-text question, present only viable options with the recommendation first, end the turn, and resume from the persisted run-log after the answer.

### 5. Context handling — lifecycle

Elegido: use numeric 70/80 percent thresholds only when the host exposes measured context telemetry. Codex must never invent a percentage; it persists after every task and creates a handoff when compaction or a host limit prevents safely starting another task.

### 6. Deploy precedence — safety

Elegido: while FIWB is active, its deploy hard stop overrides the generic global instruction to deploy immediately. Before merge or push, inspect whether that action triggers production deployment; if it does, park it as the deploy question.

### 7. Git base — lifecycle

Elegido: capture `BASE_BRANCH` and `BASE_SHA` before creating a FIWB branch. Close returns to and fast-forwards the captured base only when doing so cannot trigger a parked hard stop.

### 8. Distribution — maintenance

Elegido: keep one runtime-neutral `SKILL.md` in both `.agents` and `.claude`, document both invocation syntaxes, and enforce byte-identical copies with a contract test.

### 9. Project context lookup — dependency

Elegido: make `project-context` locate `infrastructure_directory.md` through an OS-aware ordered candidate list and a bounded filename search. On Windows it resolves Git Bash explicitly, including `C:\Program Files\Git\bin\bash.exe` when `bash` is absent from `PATH`. It must still read the selected file with Bash `cat`, verify that the command succeeds, and report when no candidate or Bash reader exists.

## Verification contract

1. Deterministic PowerShell contract tests parse the marked JSON adapter, verify that it precedes Phase 0, reject negated/wrong-order fixtures, fail against the current implementation, and pass after the adapter is added.
2. Codex behavioral probes cover dispatch, no-plan interaction, hard stops, unavailable Workflow, and merge-triggered deployment.
3. A disposable repository smoke test proves persistence without touching production or deleting real data.
4. The existing Claude trigger and scenario harness is rerun after synchronization.
5. Both global instruction files, both project-context copies, README invocation syntax, frontmatter, and installed skill parity are covered.
