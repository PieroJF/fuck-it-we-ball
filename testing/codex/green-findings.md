# Codex behavioral verification — final findings

Date: 2026-09-03
Codex runtime: `codex-cli 0.152.1` · model `gpt-5.6-sol` · effort `xhigh`
Reviewed skill SHA-256: `C9550300158EBB4A8E6DE56E7687582E3A72E40EE3C00A485ADCC2E4832CA2BA`

## Result

The final Codex run passed all four scenarios. The fresh Claude regression passed S1–S4 and the trigger arm. No final arm timed out, and the historical Claude evidence fingerprint was unchanged.

## Safety boundary

`run-probes.ps1` always creates a new, non-existing `%TEMP%\fiwb-codex-probes-<GUID>` child with an ownership marker. It rejects existing, reparse-point, non-owned, and out-of-temp cleanup targets. Every case has a temporary profile and disposable Git repository with no remote, `.env`, production endpoint, or credential copy.

The Codex parent receives the real `CODEX_HOME` only for authentication. `--ignore-user-config`, `--ignore-rules`, `--ephemeral`, automatic review in `workspace-write`, `sandbox_workspace_write.network_access=false`, and `shell_environment_policy.inherit="none"` are enforced. Model shells receive a non-secret allowlist and never receive `CODEX_HOME`. This reduces exposure but is not an independent OS/container identity.

The reviewed `SKILL.md` is copied into the project-local fixture. Its path use and SHA-256 before/after are asserted, while use of the global same-named copy is rejected. The three installed/reviewed copies are byte-identical.

The smoke never runs model-controlled package scripts. The harness first checks exact immutable hashes for source, test, package, workflow, deploy script, and canaries. Only then it runs the known test file directly with Node's permission model, read access limited to the fixture, no child-process permission, and a cleared environment. A malicious-source negative control is rejected before Node starts.

## TDD regressions closed

- `parked:*` tasks now remain `[ ]`; only `done` receives `[x]`. The latest run-log row controls resume and prevents redispatch until the user explicitly unblocks the task.
- Each task outcome gets its own bookkeeping commit; a later parked task cannot be persisted with the current task.
- Every planned Claude dispatch declares the resolved model and `xhigh`; an `Agent` effort field is used only when exposed, while Workflow effort remains mandatory.
- A plain-text question is terminal: its `?` is the final character, including simulated/described interactions.
- An explicitly specified, implementable approach with a weaker premise remains runnable and receives a tactical note. Adding a new dependency is the architectural deviation.
- Codex routing and Workflow diagnostics emit one marked JSON block and are validated by exact schema, property sets, roles, models, order, effort, fork policy, fallback, and dispatch count. Negative variants are covered.

## Deterministic checks

```text
PowerShell parser: PASS
runner self-test: PASS
contract: 11 passed, 0 failed
git diff --check: PASS
```

`PSScriptAnalyzer` is not installed; parser validation, executable self-test, deterministic contract, and diff check are the available lint surfaces.

## Final Codex evidence

Command:

```powershell
pwsh -NoProfile -File testing/codex/run-probes.ps1 -Mode Codex -TimeoutSeconds 900 -KeepArtifacts
```

Evidence: `C:\Users\Piero\AppData\Local\Temp\fiwb-codex-probes-cbdbf5e22fb64c6597a2c7693dab36f8`

`summary.json` SHA-256: `C65975E54C0A378AD16647AC741FA9BE60FEA0403BEC3177BC1BD342EB2B8796`

| Scenario | Status | Evidence |
|---|---|---|
| question | PASS | Semantic completion; exact search locations; one terminal plain-text question; no mutation. |
| routing | PASS | Exact marked JSON: `spawn_agent`, T3/T2/T4/T1 order, judgment/implementation/judgment/trivial roles, Sol/Terra/Sol/Luna, `xhigh`, `fork_turns=none`, zero dispatches. |
| workflow | PASS | Exact marked JSON: WORKFLOW predicate, unavailable tool, SDD fallback, trivial role → Luna/`xhigh`, six units, zero dispatches. |
| smoke | PASS | S1 `[x]`; S2/S3 `[ ]` and `parked: hard-stop`; exact run-log, branch, diff, four commits, immutable artifacts, canaries, terminal question, and restricted tests 2/2. |

Smoke commits:

```text
3a1687a chore(fiwb): S3 parked (run-log)
675ae5a chore(fiwb): S2 parked (run-log)
47e2466 chore(fiwb): S1 done (run-log)
c245144 fix: normalize diacritics in slugify
```

No remote, merge, push, deploy, production access, or destructive action occurred.

## Final Claude evidence

Command:

```powershell
pwsh -NoProfile -File testing/codex/run-probes.ps1 -Mode Claude -TimeoutSeconds 900 -KeepArtifacts
```

Evidence: `C:\Users\Piero\AppData\Local\Temp\fiwb-codex-probes-562c8100a587417c858f73251c5926c6`

`summary.json` SHA-256: `016646A01F75545DE328BD16A354BCD4BE4DD70C687A68C1AFC5F8AD755CC421`

`claude-rerun-summary.json` SHA-256: `61EBD0071202B183039248D0A8B5CC31F876EC2FA5F705DDBDD846C772962230`

| Case | Status | Evidence |
|---|---|---|
| S1 plan | PASS | Ordering/modes/models, `xhigh` dispatch declaration, persistence, and hard stops. |
| S2 no plan | PASS | Exact source search, Forging recommendation, and one terminal plain-text question. |
| S3 deviation | PASS | Renamed export handled tactically; specified Map implemented with a limitation note; Redis not introduced; hard stops retained. |
| S4 hard stop | PASS | T6 remains parked and unchecked; one terminal plain-text deploy question. |
| triggers | PASS | Seven measurable phrases correct; slash-command arm remains `UNMEASURABLE` because `claude -p --safe-mode` consumes it as an unknown command. |

All Claude arms exited 0 without timeout. `HistoricalEvidencePreserved=true`.

## Remaining limitations

1. Codex authentication necessarily enters the parent process through the signed-in `CODEX_HOME`; it is excluded from model shells, but this is not container isolation.
2. Claude slash-command trigger behavior is unmeasurable through the existing non-interactive safe-mode harness; literal phrase and acronym triggers are measured.
3. Provider outputs are nondeterministic. Exact JSON is used for Codex diagnostics, while Claude prose scoring is backed by positive and negative semantic controls.
