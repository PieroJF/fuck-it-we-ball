# Installed runtime discovery and publication

Completed 2026-09-09 on Windows. This supplements the isolated behavioral evidence in `green-findings.md`.

## Installed identity

- Implementation commit: `2459146f75fa1078060720a692ca7563895cf93f`.
- Canonical installation: `~/.agents/skills/fuck-it-we-ball`.
- Claude installation: `~/.claude/skills/fuck-it-we-ball`, a junction to canonical.
- Prepared worktree and canonical `main` matched before publication; all 71 tracked implementation files were byte-identical through both installations.
- Skill SHA-256: `84734EBAD38150910C39DE7DCE8F19155860AB96F84BC748B50C5BAE66F9D154`.
- Runner SHA-256: `8B28A0546030F033BA5504A9FD1BCC653A2565D54E7281CDF9287DE4D8E6488C`.
- Original installations, pre-existing edits and the integration stash remain preserved outside the active files. No backup or temporary evidence was published.

## Real catalog checks

Both processes received the normal explicit skill invocation followed by a read-only request to inspect runtime tools, Workflow fallback and authentication model selection. They were not authorized to execute a project, create a plan, modify files or dispatch agents.

| Runtime | Result | Evidence |
|---|---|---|
| Claude Code 2.1.259, 2026-09-06 | PASS, exit 0, 28.64s | Real startup catalog listed the skill and slash command; explicit invocation produced the installed Claude adapter contract, SDD fallback, and judgment/Opus/xhigh for authentication implementation. It honestly reported Agent unavailable under the deliberately limited `Skill,Read` tool allowlist. |
| Codex CLI 0.153.4, 2026-09-09 | PASS, exit 0, 48.38s | JSONL records a successful `Get-Content` of the canonical installed SKILL.md. Response identifies Codex, `collaboration.spawn_agent`, absent Workflow with SDD fallback, and judgment/Sol/xhigh/fork_turns=none for authentication implementation. |

The original Codex attempt on 2026-09-06 exited 1 because the account usage limit prevented the turn from running. Its failure remains preserved; it was not scored as a skill failure or as a passing probe. Only that blocked check was repeated after the user resumed the task.

Codex flags: `exec --ephemeral --sandbox read-only --skip-git-repo-check --json -C <isolated-directory> -o <final.txt> -`. Claude flags: `-p --strict-mcp-config --tools Skill,Read --allowedTools Skill,Read --permission-mode dontAsk --permission-prompts none --no-session-persistence --no-chrome --output-format stream-json --verbose`. Prompts were passed on stdin; output, errors, timing and JSONL events are retained in local validation artifacts.

These checks establish installed discovery and correct read-only contract interpretation. They do not claim actual reviewer/provider execution under the declared models. The separate behavioral smoke proves its recorded file/Git lifecycle, not hidden provider identity.

## Publication

On 2026-09-09, `git push origin main` advanced `PieroJF/fuck-it-we-ball` from `c5e88e9` to the verified implementation commit `2459146`. Fresh `git ls-remote` returned the exact implementation SHA. The installed contract suite was rerun on that date: 11/11 PASS; official structural validator and `git diff --check` PASS. This final documentation commit records the completed publication and closes T5 Step 6.
