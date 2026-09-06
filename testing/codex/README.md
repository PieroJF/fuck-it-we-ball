# Codex runtime contract

`contract-tests.ps1` is a deterministic static integration check for the runtime-neutral FIWB skill. Run it from the repository root:

```powershell
pwsh -NoProfile -File testing/codex/contract-tests.ps1
```

The expected result is `Summary: 11 passed, 0 failed, 11 total` with exit code `0`.

## What it checks

- The marked JSON adapter contract in `SKILL.md` uses the exact supported Claude and Codex tool names, model identifiers, fallbacks, effort, and git safeguards.
- The adapter appears before Phase 0, declares itself normative, and includes the positive production-deploy guard used at Close.
- The strict two-line frontmatter and the exact Claude and Codex invocation lines in `README.md` remain valid.
- The global Codex and Claude instruction copies both yield their ordinary deploy behavior to FIWB's deploy hard-stop.
- `project-context` keeps matching Claude and Codex copies and can read the Windows snapshot through Git Bash `cat`.
- The worktree `SKILL.md` and the installed Claude copy at `~/.claude/skills/fuck-it-we-ball/SKILL.md` have the same SHA-256 hash.

The check is intentionally static. It does not replace the pressure scenarios, trigger tests, or a disposable end-to-end smoke run described in [`../README.md`](../README.md).

## Repairing a parity failure

The worktree `SKILL.md` is the validated source. Copy it mechanically to the installed Claude path, then compare SHA-256 hashes before and after the copy. Do not hand-edit either copy to repair a mismatch: the contract requires byte-identical files.

For a shared Windows installation, the canonical repository can live in `~/.agents/skills/fuck-it-we-ball` with `~/.claude/skills/fuck-it-we-ball` as a directory junction to it. Preserve the old directory before replacing it, verify the junction target, and compare every tracked file against the reviewed worktree. This keeps supporting files and the skill text on the same version; the static contract checks the skill text only.

## Behavioral probes

```powershell
pwsh -NoProfile -File testing/codex/run-probes.ps1 -SelfTest
pwsh -NoProfile -File testing/codex/run-probes.ps1 -Mode Codex -TimeoutSeconds 900 -KeepArtifacts
pwsh -NoProfile -File testing/codex/run-probes.ps1 -Mode Claude -TimeoutSeconds 900 -KeepArtifacts
```

`-Mode` also accepts `All` and `Contract`. `-CodexScenarios` selects from `question`, `routing`, `workflow`, and `smoke`. Each process has a bounded timeout; retained evidence is written to a new owned temporary directory printed at completion. Never run these probes against a real application repository.

Routing and Workflow are prospective diagnostics: multi-agent dispatch is disabled in the CLI probe. Their marked JSON must retain the exact property types and role/model/order/effort/fallback contract. `actual_spawn_arguments` and `actual_workflow_arguments` use the canonical absence value `UNMEASURABLE`, separately from prospective arguments. For existing evidence only, the scorer also accepts `none observed`, `not observed`, underscore equivalents, and an optional explicit statement that the tool was not called or was not callable or invoked. Numeric strings, booleans in numeric fields, arrays in string fields, fabricated arguments, contradictory suffixes, wrong models, and wrong effort fail. A passing diagnostic proves the model's declared routing decision; it does not prove provider execution on those models.

Each new `summary.json` records the runner and reviewed-skill SHA-256 hashes and runtime version. Preserve that association when comparing runs; a passing older matrix does not validate a later runner revision.

The harness supplies only envelope metadata (`schema=1`, the scenario identifier, and the absence token). Tool selection, ordering, roles, model identifiers, effort, and fallback remain answers the model must derive from the reviewed skill and fixture plan.

The smoke verifies actual files, four ordered Git transitions, immutable artifacts, protected-path write denial, preserved canaries, and the known tests executed with Node's permission model. `ProcessExitCode` records the physical exit independently of semantic completion: if the CLI emits a completed turn but remains alive, the runner terminates that process tree, records `TerminatedAfterCompletion`, and assesses the completed turn. A timeout before completion fails.

See [`green-findings.md`](green-findings.md) for the current evidence and limitations. Claude's slash-command arm may be `UNMEASURABLE` when the noninteractive CLI consumes it before the model; the seven remaining trigger phrases must pass.
