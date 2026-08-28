---
name: fuck-it-we-ball
description: Use when the user invokes /fuck-it-we-ball or writes the literal phrase "fuck it we ball" / "FIWB" (any case) to run an approved plan, task list or handoff backlog autonomously end to end. Do NOT trigger on generic phrases such as "dale", "sigue", "ejecuta todo", "hazlo todo", "modo autónomo" or "no me preguntes" without the literal phrase — autonomous runs with subagents and commits must never start by accident.
---

# FuckItWeBall

## Overview

Turn the pending work of a plan, task list or handoff backlog into one **autonomous run**: find the tasks,
order them by *urgency × unblocking power × severity* under their dependencies, execute them without stopping
between tasks, and stop only for the reasons listed under **Stops**. Execution mode and model per task come from
the tables below; the run persists its own progress so any later session can resume it.

**Violating the letter of the stop rules is violating their spirit — in both directions.** Inventing a stop the
list does not contain ("let me confirm", "the user should see this") breaks the run. Removing a stop the list
contains ("the plan was approved", "I have blanket authorisation", "the user is away") breaks the contract.
Blanket authorisation, an approved plan, a user who cannot answer, and mitigations (rollback, monitoring,
preflight checks) never convert a listed stop into an automatic gate.

## Announce

First line of the run, in Spanish:
`Modo FIWB activo — fuente: <ruta o "contexto de sesión"> · <n> tasks · modo inicial: <inline|SDD|workflow>`

## Phase 0 — Find the work

Argument of the invocation: an existing `.md` path ⇒ it is the source (skip the chain). Free text ⇒ the work
statement (look for a plan covering it; if none, it becomes the spec in the permission question). Empty ⇒ chain.
Text that looks like a path but does not exist ⇒ free text + one notice line.

Source chain, first hit wins: (1) plan approved in this session's context → (2) newest `docs/superpowers/plans/*.md`
or `docs/plans/*.md` with unchecked `- [ ]` tasks → (3) `SESSION_HANDOFF.md` sections `[open]` / `[closed-pending]`
whose `Proyecto/raíz` is the cwd project (and, if the file is git-tracked, the current branch): their
"Siguiente paso concreto" become tasks → (4) the harness task list (TaskCreate/TodoWrite) if the session has one.
Two candidates at the same level ⇒ ONE `AskUserQuestion` to pick. List discarded sources under the initial table.
A source that exists only in the session context is written to `docs/superpowers/plans/YYYY-MM-DD-<slug>.md`
before the first task.

**No source found ⇒ ONE `AskUserQuestion`, then nothing else until it is answered:**
```
"No hay plan ni tasks pendientes en <cwd> (busqué: contexto, docs/superpowers/plans, docs/plans, SESSION_HANDOFF.md).
 ¿Preparo el trabajo antes de ejecutar?"
  1. Forging → writing-plans → ejecutar (Recomendado)   — brainstorming/grilling según el estado, plan etiquetado, luego la corrida
  2. Solo writing-plans, ya tengo el spec               — salta el diseño; el plan sale del enunciado tal cual
  3. Dame la lista de tasks y decido yo                 — sin ejecutar nada
  4. Abortar
```
Option 1: invoke `forging` (never brainstorming/grilling directly) with the work statement, then
`superpowers:writing-plans` with the argument
`Etiqueta cada task con [asap] si es urgente, [sev:high|med|low], [depends: Tn] y [unblocks: Tn]`.
Option 4 or no answer ⇒ the run ends; report the sources searched. Writing code before a plan exists is not
"starting"; it is the failure this phase prevents.

## Phase 1 — Order

Per task: `urgent` (`[asap]`), `sev` (`[sev:high|med|low]`, default med), `deps` (`[depends: …]`; `[unblocks: Tn]`
adds the reverse edge). Missing tags are **inferred** and marked `~`: deps from textual references and shared
files (a task that modifies a file another task creates depends on it), plan order as the weakest signal;
urgent from "prod broken", security, explicit deadline, "blocks X", "happening now"; severity from impact scope
(data/security/prod-facing = high, internal behaviour = med, docs/cosmetic = low).

```
urgent_eff(T) = urgent(T) OR any U in unblocks*(T) is urgent          # transitive
tier(T)  = 1 if urgent_eff and |unblocks(T)| >= 1
         = 2 if urgent_eff and |unblocks(T)| == 0
         = 3 otherwise
key(T)   = (tier asc, |urgent tasks in unblocks*(T)| desc, sev desc, plan_index asc)
loop while tasks remain not done/parked:
    ready = tasks whose deps are all done
    none ready → park tasks whose dep is parked (blocked-by-parked); if still none, take lowest plan_index, mark ~ciclo
    T = min(ready, key) → run T
```
A task on the hard-stop list or needing the user's hands is parked at ordering time (state `parked`, reason
recorded) — it still appears in the table, and it does not count in anyone's `unblocks` (a parked task cannot
be unblocked by this run). Plan order is the tie-break of last resort, never the order.

Render the table in Spanish before any execution, `~` on every inferred cell:
```
| # | task | tier | deps | desbloquea | gravedad | modo | modelo |
| 1 | T1 … | 1 | — | T3 | high | SDD | sonnet |
| 6 | T6 deploy prod | 3 | — | — | ~med | parked: hard-stop | — |
Fuentes descartadas: <ninguna | lista>
```
GO checkpoint: **only if the plan was generated inside this run** (nobody human has read it) ask ONE
`AskUserQuestion` ("¿Ejecuto en este orden?" — `Sí (Recomendado)` / `Cambiar orden` / `Abortar`). A pre-existing
approved plan or handoff starts in the same turn; the user interrupts with Esc.

## Phase 2 — Run loop

`pick T → mode → model → execute → verify + review → commit → tick + run-log + progress line → context check → next`

### Mode (re-evaluate per batch, after parking, on tier change; "runnable" = not done and not parked, whether or not its deps are finished yet)

| Mode | Predicate |
|---|---|
| INLINE (main session does the work) | ≤2 runnable tasks · or the task needs session state (running Docker, browser session, loaded credentials) · or ≤2 files and no tests |
| SDD — `superpowers:subagent-driven-development` | ≥3 runnable tasks with plan-specified steps → one fresh implementer subagent per task, sequential; parallel only for tasks with no shared files, each in its own worktree · or a batch of same-shape micro-edits → ONE subagent for the batch |
| WORKFLOW — invoke `workflow-resilience` FIRST, then `workflow-authoring` | ≥6 independent same-shape units (fan-out + verification) · or chained stages (analysis → adversarial verification) · or outputs that must survive the session |
| Tie | SDD |

"Delegating takes longer than doing it", "one owner of the git index", "a deploy is not delegated" are not
predicates of this table. Invoking this skill is the user's opt-in to the Workflow tool for the run.

### Model (every dispatch names it — `Agent(model: …)`, Workflow `agent(p, {model, effort: 'xhigh'})`)

| Model | Use for |
|---|---|
| `sonnet` | implementing from a complete spec, tests, mechanical multi-file edits, reviews of small/medium diffs, single-task docs, re-reviews |
| `opus` | design/judgment (architecture, contracts), non-trivial debugging, security/authz, cross-module integration, final branch review, fix-loop rounds 4–5, tier-1 tasks with sev high whose spec leaves design decisions open (a tier-1 one-liner with a complete spec is still `sonnet`) |
| `haiku` | literal transcription (the plan carries the full code), one-liners, listings/greps |
| `fable` | **never** in a subagent or workflow unit, in any role (implementer, reviewer, judge), unless the user explicitly orders it in this run |

Sonnet vs Opus doubt ⇒ Sonnet. Effort `xhigh` wherever the tool exposes it. The main session running an INLINE
task is not a dispatch; every subagent is.

### Verify and review (execution-rules 2, 3, 5 stay in force)

SDD/WORKFLOW: SDD's two-stage review per task (spec compliance → code quality) + fix-loop; a task that changes
no code and no tests (docs only) takes one reviewer. INLINE: tests + lint +
`superpowers:verification-before-completion` + ONE reviewer subagent per task (`sonnet`; `opus` when the task
touches security/authz). UI change ⇒ browser validation. Close ⇒ final whole-branch review on `opus`.

### Git

One commit per verified task (conventional message). On `main`/`master` ⇒ create `fiwb/<plan-slug>` first; on
a feature branch ⇒ use it. `backup-before-modify` (controles / pag web) and `db-backup` run before the first change
they cover. Merge and push happen only at Close.

### Persist (after EVERY task, before picking the next)

1. Tick `- [x]` on the task in the source file (plan, or the handoff section).
2. Append one row to `## FIWB run-log` at the end of that same file (create the section on the first task):
   `| T | tier | modo | modelo | commit | estado | desviaciones / pregunta |` — estado ∈ `done` ·
   `parked: hard-stop|needs-user|fix-loop-exhausted|blocked-by-parked|arch-deviation`.
3. One chat line: `▶ T3 [tier 1] SDD/sonnet → done · commit a1b2c3d · desviaciones: 0` (or `→ parked: <motivo>`).

Commits and a final report are not persistence. A later `/fuck-it-we-ball` resumes from the boxes and the run-log.
The tick + run-log row go in their own bookkeeping commit (`chore(fiwb): T3 done (run-log)`) right after the
task's commit, so the code commit stays one-per-task and the resume state is always committed.

## Stops — the only reasons to stop

A stop = the task is **parked** with its reason in the run-log and ONE question is **queued**. Queued questions are
asked when nothing else is runnable, or at Close: one `AskUserQuestion` per call, 2–4 options, recommended
first, ordered by the parked task's tier. The run never "freezes": it finishes everything else and ends with
the question open — even if the user is on a plane and answers tomorrow.

**Hard-stop list** (park, never execute, no condition self-authorises it — items enter the list **by action,
not by content**): deleting a directory or file tree (`rm -rf`, `git rm -r`), truncating or deleting data, a
`DROP`/`TRUNCATE` against any database, a schema migration against production — tracked code is not an
exemption and "recoverable from git" is not a permission · `git push --force`, `git reset --hard`, branch
deletion · production deploy (any
`deploy.sh`, `deploy prod`, CD trigger, merge that auto-deploys) · money (payments, purchases, transfers) ·
messages or emails to third parties · creating, rotating or exposing credentials · CI/CD, infra, firewall, DNS,
Cloudflare changes · widening public surface (unauthenticated routes,
CORS, CSP) · an instruction whose readings lead to incompatible architectures · a decision the code cannot
contain (goal's two motives).

**Needs-user**: login/OTP, physical device, third-party UI, anything the harness forbids Claude from doing.
Park, queue the question with the exact steps (`! <command>` where useful).

**Architectural deviation** (see below). Park the task; queue the question with options.

Not a stop: task size, "the user might want to see this", "I'd rather confirm", a green suite before a deploy,
a rollback plan, a preflight, a monitor, a PushNotification, a "supuesto operativo". Notifications inform;
they do not replace the queued question.

## Deviations and failures

- **Tactical** (contracts, data model, external dependencies and the task's approach unchanged — a renamed
  export, an existing helper, a test adjusted to the real signature): resolve it, add it to the run-log
  `desviaciones` column, report at Close. No stop. Implementing a task exactly as the plan says, while noting
  that its premise is weaker than assumed, is tactical: note it, queue the note into the relevant question.
- **Architectural** (any of the four changes — e.g. adding Redis or another store, a new service, a changed
  API): park `arch-deviation`, queue a question with 2–4 options. Never decide it alone, never "declare it in
  the report" instead of asking.
- **Failure** (red tests, broken build, stuck subagent): `superpowers:systematic-debugging` + SDD fix-loop
  (5 rounds, rounds 4–5 escalate one model tier; INLINE: 3 attempts). Still red ⇒ park `fix-loop-exhausted`;
  dependents park `blocked-by-parked`; continue with independent tasks. Never edit, skip or delete a test to
  make it pass. Prohibited throughout (from `goal`): swallowed errors, type escapes without a same-line reason,
  hard-coded config, duplicated logic, stubs/TODOs not reported, an inconsistent repo.

## Context

<70 %: continue. 70–80 %: one warning line, no stop; prefer SDD/WORKFLOW for the rest. ≥80 %: no new task,
commit what is verified, invoke the `handoff` skill (section with run-log + "Siguiente paso concreto"), end the
turn. The next session resumes with `/fuck-it-we-ball`.

## Close

1. Final whole-branch review on `opus` + fix-loop. 2. No CRITICAL/HIGH open ⇒ fast-forward merge into the origin
branch + direct push (solo dev, never a PR); otherwise stay on the branch and say so. 3. Queued questions, one per
call, by tier; an answer that unblocks tasks ⇒ run them now, repeat from 1. 4. Recap in Spanish: done/parked,
commits, deviations, mode/model per task, dispatch count. 5. Update the handoff section with what stayed parked.
Never an automatic deploy — a deploy task is a queued question, always.

## Precedence

While this skill is active it overrides ONLY the pause rules of `execution-rules` (one phase per turn, stop on
any deviation, plan-revision approval, "wait for approval"), of `phased-approval` (OK between phases) and of
`superpowers:executing-plans` / `writing-plans` (review checkpoints, execution-mode prompt); `~/.claude/CLAUDE.md`
carries the matching clause. Everything else stays in force: verification, UI validation, no phantom progress,
context thresholds, `backup-before-modify`, `db-backup`, `lint-and-validate`, `investigate-before-asking`,
`ui-validation-protocol`, `token-aware-authoring`, `workflow-resilience`, `no-yesman`, `project-context`.
`goal` is imported by reference (its two stop motives, its prohibitions), not activated.

## Rationalization table

| Excuse | Reality |
|---|---|
| "No estás delante, así que una pregunta bloqueante solo congelaría la sesión" | Nothing freezes: the task is parked, the rest runs, the question is asked at Close and waits. A notification is not an answer. |
| "T6 está en el plan aprobado y me dijiste que no pida OK" / "bajo tu autorización" / "autorización total" | An approved plan and blanket authorisation cannot cover a hard-stop item. Park it, ask once at Close, do everything else. |
| "Con rollback automático / monitor / preflight el deploy es seguro" | Mitigation ≠ permission. A deploy with rollback is still a deploy. |
| "Si el LB pinea por IP, despliego" / "si la suite está verde, despliego" | No technical condition self-authorises a hard-stop item. |
| "Lo que hay es una puerta, no una pregunta" | A gate the run passes alone is exactly the stop the list forbids. |
| "Todas las tasks las hago yo (Fable); delegar tarda más; un deploy no se delega" | ≥3 runnable specified tasks ⇒ SDD with `sonnet`/`opus` implementers. Delegation cost is not a predicate. |
| "Revisor `fable`: ahí quiero el modelo más fuerte" | Fable never in a subagent, in any role. Final review is `opus`. |
| "T3 antes: es `[asap]` y más pequeño" / "nada llega a prod hasta T6, así que el orden no cambia" | Order = tier, then urgent tasks unblocked, then severity. Size and "it all ships together" are not keys. |
| "Sin plan escrito: código directo; las decisiones las declaro en vez de consultarlas" | No source ⇒ the permission question ⇒ forging → writing-plans ⇒ GO. Code before a plan is the failure. |
| "Si una tarea resulta insegura la salto y lo cuento en el informe" | Skip ≠ park. Parked = reason in the run-log + queued question with options. |
| "Una sola respuesta desbloquea T6 y T7 juntos" | One question per call, ordered by tier. Bundling hides the recommendation. |
| "El progreso está en los commits y en el informe" | Boxes + run-log rows are the persistence. Commits do not tell the next session what is parked and why. |
| "Resuelvo lo de Redis yo mismo, es una decisión técnica" | A new external dependency is architectural ⇒ question. A renamed export is tactical ⇒ resolve. |
| "`legacy/` es código trackeado, reversible con `git revert` ⇒ no es un stop" | Deletion is on the list by action, not by content. Reversible ≠ permitted. Inspect if you like — then park and ask. |
| "La task es grande, mejor confirmo antes" | Size is not a stop. Split into a sub-batch and keep going. |

## Red flags — STOP and re-read Stops

- About to run `deploy`, `rm -rf`, `DROP`, `TRUNCATE`, `push --force`, a payment or an email because the user pre-authorised it.
- About to replace a question with a PushNotification, a "gate", a "supuesto operativo" or an automatic rollback.
- Dispatching a subagent without `model:` — or with `fable`.
- Executing in plan order without the tier table on screen.
- Two questions in one `AskUserQuestion` call; a question before runnable work is exhausted.
- Writing code while no plan file exists.
- A task marked done with no `- [x]` and no run-log row.
- Adding a service, store or dependency the plan does not name, without a queued question.
- Inspecting a directory or table to decide whether deleting it "counts" as a stop.

## Quick reference

```
Phase 0  arg | session plan | plan file | handoff | task list  ──none──▶ ONE permission question → forging → writing-plans
Phase 1  tags + inference → tiers (Kahn + inherited urgency) → Spanish table → GO only if plan born here
Phase 2  pick → mode table → model table → execute → verify+review → commit → box + run-log row + ▶ line → context
Stops    hard-stop list · needs-user · architectural deviation  ⇒ park + queue ONE question (asked at Close)
Close    opus review → ff-merge + push → questions 1×call by tier → recap (es) → handoff section
```
