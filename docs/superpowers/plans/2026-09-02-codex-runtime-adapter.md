# FIWB Codex Runtime Adapter Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `fuck-it-we-ball` executable and regression-tested in both Claude Code and Codex without weakening its safety contract.

**Architecture:** Add a capability-based runtime adapter to the existing skill, then align global precedence and project-context discovery. Deterministic contract tests guard tool/model/safety invariants; behavioral probes and disposable smoke tests validate actual agent behavior.

**Tech Stack:** Markdown agent skills, PowerShell 7, Bash, Claude Code 2.1.251, Codex CLI 0.152.1, Git.

**Spec:** `docs/superpowers/specs/2026-09-02-codex-runtime-adapter-design.md`

## Global Constraints

- Preserve all existing Claude RED/GREEN behavior and hard stops.
- Never execute production deploys, real deletion, payments, messages, credential changes, or force pushes in tests.
- Preserve the pre-existing uncommitted `SKILL.md` edits.
- Use capability detection, not runtime-name guesses, for optional tools.
- Ask one user decision per turn/call with the recommendation first.
- Do not estimate context usage when the host exposes no measurement.

---

### Task 1: Codex contract RED [asap] [sev:high] [unblocks: T2, T3, T4]

**Files:**
- Create: `testing/codex/contract-tests.ps1`
- Create: `testing/codex/red-findings.md`

**Interfaces:**
- Consumes: current `SKILL.md`, `~/.codex/AGENTS.md`, `~/.agents/skills/project-context/SKILL.md`, and the `.claude` FIWB copy.
- Produces: deterministic failing assertions named in `red-findings.md`.

- [x] **Step 1: Write contract assertions**

Parse a marked JSON adapter and assert its position before Phase 0, exact tool/model roles, `xhigh`, question fallback, conditional task-list source, Workflow-to-SDD fallback, measurable-context fallback, captured git base, and auto-deploy guard. Validate both global instruction files, both project-context installations, README invocation syntax, frontmatter, and skill parity. Include positive and adversarial fixtures proving that negated values and wrong ordering are rejected.

- [x] **Step 2: Run RED**

Run:

```powershell
pwsh -NoProfile -File testing/codex/contract-tests.ps1
```

Expected: non-zero exit with multiple named failures caused by the unadapted skill.

- [x] **Step 3: Record exact RED output**

Write the observed assertion names and counts to `testing/codex/red-findings.md`. Do not claim behavioral coverage from these static tests.

- [x] **Step 4: Commit the verified RED harness and planning artifacts**

```powershell
git add docs/superpowers testing/codex
git commit -m "test(fiwb): add Codex runtime contract RED"
```

### Task 2: Capability-based runtime adapter [asap] [sev:high] [depends: T1] [unblocks: T4, T5]

**Files:**
- Modify: `SKILL.md`
- Test: `testing/codex/contract-tests.ps1`

**Interfaces:**
- Consumes: host tool inventory and available model identifiers.
- Produces: normalized question, dispatch, workflow, task-source, context, and git-close behavior.

- [x] **Step 1: Confirm RED still fails for adapter assertions**
- [x] **Step 2: Add the minimal runtime adapter and its marked JSON contract before Phase 0**
- [x] **Step 3: Make Mode, Model, Source, Stops, Context, Close, Precedence, red flags, and quick reference use normalized capabilities**
- [x] **Step 4: Run contract tests; adapter-related assertions must pass**
- [x] **Step 5: Run skill quick validation and review the diff**

### Task 3: Global safety precedence and project context [sev:high] [depends: T1] [unblocks: T5]

**Files:**
- Modify: `C:/Users/Piero/.codex/AGENTS.md`
- Modify: `C:/Users/Piero/.claude/CLAUDE.md`
- Modify: `C:/Users/Piero/.agents/skills/project-context/SKILL.md`
- Modify: `C:/Users/Piero/.claude/skills/project-context/SKILL.md`
- Test: `testing/codex/contract-tests.ps1`

**Interfaces:**
- Consumes: FIWB active state and Windows/Linux infrastructure-directory candidates.
- Produces: unambiguous deploy precedence and a readable project-context source on both hosts.

- [x] **Step 1: Confirm the safety and locator assertions fail**
- [x] **Step 2: Add an explicit FIWB exception to the generic deploy rule in both global instruction files**
- [x] **Step 3: Add ordered Linux/Windows candidates plus a bounded fallback search to project-context**
- [x] **Step 4: Verify Bash `cat` reads the resolved Windows snapshot**
- [x] **Step 5: Run contract tests and compare the two global clauses**

### Task 4: Distribution and documentation [sev:med] [depends: T1, T2]

**Files:**
- Modify: `README.md`
- Modify: `C:/Users/Piero/.claude/skills/fuck-it-we-ball/SKILL.md`
- Create: `testing/codex/README.md`
- Test: `testing/codex/contract-tests.ps1`

**Interfaces:**
- Consumes: validated runtime-neutral skill text.
- Produces: byte-identical installed copies and documented `/fuck-it-we-ball` plus `$fuck-it-we-ball` usage.

- [x] **Step 1: Update README support, invocation, model, and test sections**
- [x] **Step 2: Synchronize the validated skill into `.claude/skills`**
- [x] **Step 3: Run parity and frontmatter validation**
- [x] **Step 4: Ensure git diff contains no unrelated user changes**

### Task 5: Behavioral verification and close [sev:high] [depends: T2, T3, T4]

**Files:**
- Create: `testing/codex/run-probes.ps1`
- Create: `testing/codex/green-findings.md`
- Modify: `testing/README.md`

**Interfaces:**
- Consumes: adapted skill and disposable fixture repositories.
- Produces: fresh Codex evidence plus Claude regression evidence.

- [x] **Step 1: Run Codex probes in an isolated temporary home/workspace**
- [x] **Step 2: Manually score tool/model routing, questions, hard stops, persistence, and Workflow fallback**
- [x] **Step 3: Run one disposable end-to-end smoke test with no production or real destructive action**
- [x] **Step 4: Rerun the existing Claude trigger/scenario regression harness**
- [x] **Step 5: Run final independent review, fix confirmed findings, and record exact results**
- [x] **Step 6: Commit each verified task separately and push directly only after every hard-stop guard is satisfied**

2026-09-06 evidence: `testing/codex/green-findings.md` records every snapshot, original failure, targeted recheck, and checksum. Final authentication routing passes on Codex and Claude; ordinary Claude sum/Map tasks remain Sonnet. The real smoke's four commits and 2/2 tests pass final artifact re-evaluation. Claude S1–S4 pass; one initially empty trigger response passes a targeted retry with the final capture helper. Requested provider-model execution remains unmeasurable in the diagnostic harness. Two independent-review findings (process deadlines and Windows path separators) are fixed and independently rechecked. Final independent review: APPROVE, zero Critical/Important/Minor findings; local `review-result.md` SHA-256 `7761EAF8FDD45F9B70A4743AB8D63CC9DABDE234D547DBA48695AB16E11F385B`. Direct publication remains tracked by Step 6.

## FIWB run-log

2026-09-09 closure: implementation `2459146f75fa1078060720a692ca7563895cf93f` published directly to `origin/main` and verified by `git ls-remote`. Both installed runtime discovery checks passed; the previously usage-limited Codex check passed its targeted retry. Canonical/Claude junction parity, contract 11/11, official validator and clean Git state were verified. See `testing/codex/installed-discovery-2026-09-09.md` for measured scope and publication evidence. T5 is complete.

| T | tier | modo | modelo | commit | estado | desviaciones / pregunta |
|---|---:|---|---|---|---|---|
| T3 | 3 | SDD | gpt-5.6-terra | external config + bookkeeping | done | 0 |
| T4 | 3 | SDD | gpt-5.6-terra | a22f3ba, a8e3229 | done | fix rounds 1–2: installed-copy EOL parity + false-positive coverage |
