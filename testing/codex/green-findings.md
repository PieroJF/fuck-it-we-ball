# Codex runtime verification — 2026-09-06

Codex: `0.153.4`, `gpt-5.6-sol`, `xhigh`. Claude: `2.1.259`, `fable`, `xhigh`.

- Final skill SHA-256: `84734EBAD38150910C39DE7DCE8F19155860AB96F84BC748B50C5BAE66F9D154`.
- Final runner SHA-256: `8B28A0546030F033BA5504A9FD1BCC653A2565D54E7281CDF9287DE4D8E6488C`.
- Previous skill: `C9550300158EBB4A8E6DE56E7687582E3A72E40EE3C00A485ADCC2E4832CA2BA`.

## Result and scope

Required behaviors are covered by the initial matrix, targeted reruns after confirmed fixes, and re-evaluation of unchanged artifacts. This is not a claim that one final full matrix passed unchanged. Earlier failing reports remain intact.

| Requirement | Final evidence |
|---|---|
| Missing-plan question | PASS on the initial skill; final path audit also passes. The later skill edit only clarifies authentication model selection. |
| Codex role/model routing | PASS on the final skill and runner: T3/T2/T4/T1, judgment/implementation/judgment/trivial, Sol/Terra/Sol/Luna, `xhigh`, `fork_turns=none`. |
| Workflow unavailable | PASS on both targeted runs; SDD fallback and Luna for six trivial units. The later authentication clarification does not affect these tasks. |
| Smoke persistence and hard stops | PASS after correcting Markdown delimiter parsing and re-evaluating the same real Git history and files. No model rerun or history rewrite was used for this parser-only fix. |
| Claude S1–S4 | All PASS with the previous skill; exit 0, no timeout, historical evidence unchanged. |
| Claude affected model selection | Final skill PASS: authentication review and implementation use judgment/Opus; specified sum and Map rate limiter use implementation/Sonnet; all declare `xhigh`. |
| Claude triggers | Six measurable phrases passed initially; one empty-response case passed its targeted retry with the final capture helper. Thus all seven measurable phrases have passing evidence. The isolated slash-command remains `UNMEASURABLE`. |

Routing and Workflow are prospective diagnostics. Their JSON proves declared decisions, not execution by the requested provider models. The smoke's final prose mentions two reviewers, but its JSONL exposes only wait events without receiver IDs or concrete spawn/model arguments. Reviewer execution and provider model identity are therefore **UNMEASURABLE**, not counted as proof.

## Confirmed defects and verification

- Absence metadata and scenario identifiers were unconstrained in the prompts but constrained by the scorer. The output contract now specifies only envelope metadata (`schema=1`, scenario, and `UNMEASURABLE`). Model/role/order/effort/fallback answers remain unsupplied. Exact historical absence variants are accepted; appended or contradictory claims fail.
- PowerShell comparisons admitted numeric strings, booleans in numeric fields, and arrays in string fields. Explicit type checks and adversarial controls now reject these values.
- The previous skill listed security/authz under judgment but allowed the generic implementation tie-break to win. A real T4 authentication-implementation failure supplied RED evidence. Explicit judgment categories now take precedence, including implementing an already selected authentication boundary. Claude's security/authz → Opus category already existed in `c5e88e9`; the targeted Claude case verifies that the Map rate limiter still uses Sonnet.
- A Markdown alignment colon was mistakenly part of the smoke's semantic gate. The parser now accepts valid seven-column delimiter rows, while exact headers, task states, row preservation, and four commit transitions remain required. Malformed delimiters and wrong column counts fail.
- Independent review reproduced two process deadline bypasses: stdout EOF before process exit, and a child that does not read a large stdin payload. Input write/flush are now asynchronous under the deadline; exit and pipe draining stay supervised. Independent rechecks returned exit 124 in about 1.1 seconds for both `Timeout=1` controls. Completion followed by EOF also retains its separate semantic-completion result.
- Independent review found that absolute `C:/...` paths bypassed the observational audit. Both separators and mixed paths are now normalized. Reading the fixture and global skill in one command cannot hide the global reference; inside/outside/mixed controls pass.

Deterministic validation: PowerShell parser PASS; runner self-test PASS; contract **11/11 PASS**; official skill validator PASS; `git diff --check` PASS. `PSScriptAnalyzer` is unavailable. The self-test uses Python for the closed-stdout regression and Node for the unread-stdin and restricted smoke controls.

## Evidence ledger

All directories below are under `C:/Users/Piero/AppData/Local/Temp/` unless noted. Raw reports are local artifacts, not committed into the repository.

| ID | Directory | Outcome and source |
|---|---|---|
| A | `fiwb-codex-probes-5d3b41dfe8b549d5940720628aa934f1` | Initial Codex: question PASS, routing FAIL (unconstrained `none-observed`), Workflow PASS, smoke FAIL only on table alignment. Previous skill; runner source snapshot SHA `8A5EFC0C401612CF0717BCFE9CFC5322299EAB0288E9A1587F730F678DA4EAD5`. |
| B | `fiwb-codex-probes-f5e45f71ec244e8393bc82f952c2d06c` | Routing FAIL on unconstrained `scenario=codex`; Workflow PASS. Runner `7D7F0D5B2EA80F7924A7BAAACDD7A6F176A90398BF723EA46B18E4FC14BB244F`, previous skill. |
| C | `fiwb-codex-probes-6248ffec6d5f48debb6c355e2ef43474` | Routing FAIL on T4→Terra, supplying the behavioral RED; Workflow PASS. Runner `275CE5C79086410A7AB5EC804C04D12AE3E3FD5B98CCEE35876D434B828FC081`, previous skill. |
| D | `fiwb-codex-probes-41a44b1ccdcd46b9a68f63b81a5baf63` | Final Codex routing PASS, final skill and runner; every assertion true, physical exit 0, no timeout. |
| E | `fiwb-codex-probes-fbd6b942d2e74d29aea0a553382ea731` | Claude S1–S4 PASS; initial trigger aggregate FAIL solely from one empty response. Previous skill and initial runner snapshot. Historical evidence preserved. |
| F | `fiwb-codex-probes-ddd4070ef0c1404e820cf5a3f63995d0` | Targeted empty-trigger retry: correct NO, exit 0, no timeout or incomplete capture, final skill/runner. The original empty response's cause remains unknown. |
| G | `fiwb-codex-probes-4d6477bd06074f08acc1bbf5f33b9817` | Claude authentication/routine-task model classification PASS, final skill/runner; exit 0, no timeout or incomplete capture. |

Artifact re-evaluation: `C:/Users/Piero/AppData/Local/FIWB-finalization-backups/20260906-210101/artifact-rescore.json`. It records the unchanged JSONL hashes and executed skill hash from A, the final runner hash, and final question/Workflow/smoke assessments. Initial runner source was reconstructed exactly as LF text from the diff captured before subsequent edits and retained as `initial-runner.ps1` in that backup directory.

SHA-256 checksums:

```text
A/summary.json 9289D131C8B70F9B472C721E96DDDF2490D271C4F63C6F1909BE153144DB53C3
B/summary.json 01B51EE6AA8883559A0AE05A456383A51B72E975B658FC82A7851444263E13F8
C/summary.json EC53786C408D7182D32367D3D1FEF8BB5E2B61813203BD04958CCC795EB302E9
D/summary.json 20B8417CE78E2F3973A25F56C82E97905D2DE1825AC62F5132EA243BDDF270EB
E/summary.json 0CFAA4F722D476185AC9896D1ED8C659B6BBFB1E3C1642B7FFF7F69496185F81
F/report.json  5ACA77099C99D5C0CE2B45E596C4721ABCC2BB9EBD141E4EF2BFDD930C737E9A
G/report.json  B530C5FBCFA0C50289647287DF2A8F19586A598C16026A03456C81AEFD80A7EB
artifact-rescore.json 486A49229F9F53DEF4714F0EB7BD4859541B949837B7378F3B142F6775508F8F
```

The smoke performed these four real commits on its disposable feature branch:

```text
41e6dcd fix: normalize diacritics in slugify
4bab0a8 chore(fiwb): S1 done (run-log)
a5d472d chore(fiwb): S2 parked (run-log)
4d9eaff chore(fiwb): S3 parked (run-log)
```

S1 is checked; S2/S3 remain unchecked and parked. The tree is clean, `main` is unchanged, all immutable hashes and canaries match, the known tests pass 2/2, protected canary writes are denied, and no remote/deploy/merge/push/destructive action occurred.

## Safety and limits

Each run creates a new owned temporary directory with a marker, disposable Git repositories, and no remote or credential copy. Cleanup rejects non-owned/out-of-temp/reparse-point roots. The Codex parent receives the real `CODEX_HOME` for authentication; model shells receive a cleared non-secret environment. User configuration, ambient rules, web/MCP/plugin/browser capabilities are disabled, with `:workspace` permissions and a stricter protected-path profile for smoke. Workspace read/write and protected-canary denial are measured.

Command/path checks are observational audits, not a proof of OS/container isolation or denial of every possible network path. The known smoke code is executed only after immutable-hash gates, directly through Node's permission model with fixture-only reads and no child-process permission. Unknown source is rejected before execution. Claude uses a neutral working directory, disabled tools/config/MCP, and real-user-home authentication fallback only when required.

Installation discovery through the real runtime catalogs is separate from these isolated behavioral probes; the finalization task records that integration check after the reviewed package is installed.
