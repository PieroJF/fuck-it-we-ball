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
