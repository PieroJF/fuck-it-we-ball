# Codex contract RED

Date: 2026-09-02

The deterministic contract test is written before the runtime adapter. It checks whether the current installed skill names executable Codex tools and models, defines fallbacks for missing capabilities, resolves deploy precedence, locates project context on Windows, and keeps installed copies synchronized.

Expected RED: the current Claude-oriented implementation must fail multiple assertions. Exact observed output is appended only after running `contract-tests.ps1`.

## Observed baseline

Command:

```powershell
pwsh -NoProfile -File testing/codex/contract-tests.ps1
```

Result after strengthening the harness from independent review: exit code `1`; `2 passed, 9 failed, 11 total`. The two passing checks validate the harness itself and the existing frontmatter; the nine failures are the intended implementation RED.

```text
[FAIL] runtime-contract-valid - The marked JSON contract has exact supported tools, models, fallbacks, effort, and git guards.
[FAIL] runtime-contract-order - The normalized adapter contract appears before Phase 0.
[FAIL] runtime-adapter-prose - Human-readable runtime instructions make the structural contract normative.
[FAIL] close-auto-deploy-guard - Close contains the exact positive production-side-effect guard.
[PASS] contract-negative-fixtures - The validator rejects negated values, wrong order/roles, wrong casing/types, and negated deploy prose.
[PASS] frontmatter-valid - Frontmatter conforms to the strict supported YAML subset and rejects malformed syntax.
[FAIL] readme-dual-invocation - README contains exact positive invocation instructions for Claude and Codex.
[FAIL] codex-global-deploy-precedence - Codex global deploy behavior explicitly yields to FIWB.
[FAIL] claude-global-deploy-precedence - Claude global deploy behavior explicitly yields to FIWB.
[FAIL] project-context-windows-locator - Both project-context copies declare the verified candidate and bounded fallback, and Git Bash cat reads it.
[FAIL] installed-copy-parity - The .agents and .claude installed skill copies are byte-identical.
Summary: 2 passed, 9 failed, 11 total
```

## Scope of this evidence

These checks validate static integration contracts only. They do not replace behavioral pressure scenarios or a disposable end-to-end Codex smoke test.
