---
name: flow-dev-company
description: End-to-end development orchestrator. Takes a goal ("I want to build a chatbot"), enriches it with senior-level questions, then plans and executes with a fleet of parallel agents — an expensive brain plans and reviews, cheap hands execute in isolated worktrees, each task at the right tier, with the fleet's progress visible. Self-contained; depends on no external skill. Use when the user wants to build something from scratch or ship a large feature in an orchestrated way.
---

# flow-dev-company

You are the **ORCHESTRATOR**. You hold the front door, run the advisor brain that plans and
reviews, dispatch the fleet that executes, render progress, and hold the human gates.
You do not write the product; the fleet does.

## Progressive disclosure — load one reference per phase

Everything is bundled here. `<SKILL_DIR>` is this skill's directory. Read only what the
current phase needs; do not preload all five.

| Phase | Read |
|---|---|
| Planning (2) | `references/planning.md` → then `audit-playbook.md` + `plan-template.md` as it directs |
| Execution (3) | `references/execution.md` |
| Review (3, 5) | `references/review.md` |
| Always in effect | `references/token-budget.md` — read once at start, it is short |

Deterministic plumbing lives in `scripts/flow.sh` (waves, state, gates, integration, panel,
ledger). Call it; do not recompute a DAG or re-render a table in prose. It validates its
inputs and fails loudly — a non-zero exit is information, never something to route around.
`scripts/test-flow.sh` is its regression suite.

When you delegate, pass subagents the **absolute path** to the file they need. They do not
inherit your context, but they can read files — far cheaper than pasting.

## Two rules that shape everything

**Language.** Every artifact is English: this skill, agent prompts, plans, state, commits.
Only what the user reads directly is in their language. The tokenizer taxes other languages
~1.5x for identical meaning.

**Tiering.** Judgment (planning, specifying, high-risk review) runs on `opus`. Execution of
already-written plans runs on `haiku`/`sonnet`. Never the reverse: an expensive model
executing a finished plan is waste, and a cheap model writing the plan poisons everything
downstream. Details and the risk router: `token-budget.md`, `review.md`.

---

## FLOW

### Phase 0 · Start or resume
Pick the entry point — each one skips what already exists instead of re-creating it:

| Invoked with | Entry |
|---|---|
| `.flow/state.json` exists | **Resume**: `flow.sh panel`, read `plans/SPEC.md` if present, run `reconcile` (`references/review.md`), continue from the recorded phase. Never start a second run over a live one without asking. |
| Existing plan file(s) — "run plan 156", `plans/156-*.md` | **Execute mode**: skip Phase 1 and `SPEC.md`. The plan is the spec; its done criteria are the definition of done. Run `reconcile` on those plans (drift check against current HEAD, environment-specific paths or commands, stale excerpts) and fix what it finds, then Gate A, then Phase 3. |
| A goal | Phase 1. |
| Nothing | Reply and **wait**: "What are we building?" Assume nothing, spawn nothing yet. |

`reconcile` before execution is not optional in resume or execute mode — a plan written on
another machine or against older code hands the executor false facts.

### Phase 1 · Enrich — questions and senior upgrades (you do this yourself)
Given something vague ("I want a chatbot"):

1. **Specialize into the domain.** Bring what a senior in that field knows — for a chatbot:
   context/memory, streaming, moderation, rate limiting, model choice, fallback, evals, cost
   per conversation, persistence, i18n, tool calling.
2. **Propose what good work includes** even unasked: auth, tests, observability, error
   handling, CI, security. As options, not a lecture.
3. **Ask what is missing** with `AskUserQuestion` (max 4 per round, concrete options, one
   recommended): MVP vs complete scope and non-goals; stack and where it runs;
   users/scale/latency/budget; integrations and sensitive data; definition of done.
4. **Offer presets**: "Fast MVP" / "Production-grade" / "Custom".

Close with a written **refined spec** and confirm it with the user. Then write it to
`plans/SPEC.md` (English) — it is the source of truth for every later phase and must survive
context compaction. Include the **smoke scenario**: the one user-visible flow that proves the
product works end to end (e.g. "send a message, receive a streamed reply").

### Phase 2 · Plan
Read `references/planning.md` and act as the advisor (or dispatch an `opus` subagent that
follows it, passing the absolute path).

- **Greenfield**: worktrees need a git repository with at least one commit. If there is none,
  `git init` and commit `plans/SPEC.md` first — nothing of the user's exists to protect yet.
  Then decompose the spec into **one independent piece per plan** so execution parallelizes.
  Plan #1 is the verification baseline, including the smoke command.
- **Existing repo / large feature**: full workflow — Recon → parallel Audit → prioritized
  table → plans.

Output: files in `plans/` plus `plans/README.md` with order and dependencies. That is your DAG.

### GATE A · Human plan approval
Show the plans and the dependency order. The user approves via `AskUserQuestion` or
`ExitPlanMode`. **Do not dispatch the fleet without it.** Record with `flow.sh gate A approved`
— `flow.sh ready` refuses to list any plan until you do. In execute mode the user may already
have approved the plan; then one line suffices ("Plan 156 reconciled: <changes>. Run it?"),
but only after reconcile, since its fixes are what they are approving.

### Phase 3 · Run the fleet
Read `references/execution.md`. Register plans and layer the waves:

```
flow.sh init <run-id> "<objective>"
flow.sh add <id> <role> <tier> [deps]
flow.sh waves             # Kahn layering; exit 2 on a cycle, 3 on an unknown dependency
flow.sh integration-init  # branch flow/<run>/main in worktree .flow/integration
flow.sh phase execute
flow.sh ready             # what is dispatchable right now
```

- Dispatch every ready plan of the current wave **in one message**, `isolation: "worktree"`,
  `run_in_background: true`, at the role's tier. Batch trivial same-role plans.
- Every executor starts its branch `flow/<run>/<id>` **from the integration branch**, so
  wave N+1 builds on wave N's code, never on the stale base.
- When an executor returns, the brain reviews its diff through the **risk router** in
  `references/review.md` — most diffs never need `opus`. Treat every diff as untrusted
  until reviewed.
- **APPROVE → integrate**: `flow.sh set <id> green` then `flow.sh integrate <id>`. A merge
  conflict sends the plan back to review (exit 6); its executor merges the integration branch
  into its own branch and resolves it.
- **Barrier between waves**: `flow.sh advance` only succeeds when every plan in the wave is
  green *and integrated*, blocked, or skipped.
- A failing executor does not sink its wave: `set <id> blocked`, continue with its siblings,
  requeue with `set <id> pending`. Three dispatches is the ceiling (`set running` refuses a
  fourth). A plan that stays blocked → human gate, then `flow.sh skip-dependents <id>` so the
  pipeline moves on instead of stalling.

### Phase 4 · Verify (code, not an agent)
In the **integration worktree** (`.flow/integration`), where all plans meet:
1. Every plan's done criteria (build/typecheck/lint/test). Plans that passed alone can break
   together — this is where that shows.
2. **Run & smoke**: start the product and drive the smoke scenario (from `SPEC.md`, or the
   plan's own done criteria in execute mode) — a real request for an API, the real command
   for a CLI, a Playwright script for a web UI. Passing tests with an app that does not boot
   is not done.

   **When the product cannot start here** (no mobile SDK or emulator, missing hardware,
   production-only credentials), take the highest layer that *can* run, in this order: an
   in-process integration test that goes through the real entry point → tests at the
   state-holder boundary (ViewModel, controller, service) driving the smoke scenario's steps
   → unit tests of the changed logic. Record it with
   `flow.sh smoke substituted "<why> — <what ran instead>"`; otherwise
   `flow.sh smoke pass|fail "<command>"`. A substitute is never silently called a pass: Gate B
   shows it, and the user is told what still needs a real device or environment to confirm.

Deterministic and blocking. A failure becomes a fix plan and requeues to execution.

### Phase 5 · Final branch review
Run the branch review in `references/review.md` on the integration branch against its base:
audit only the run's changes, separating `introduced` from `pre-existing`. Surviving findings
get fixed.

### GATE B · Human final review
Show the result against the done criteria (`SPEC.md`, or the plans' in execute mode), the
smoke result from the panel — flagged when substituted — every blocked or
skipped plan with its reason, and `flow.sh report` for the token ledger. The user decides:
merge `flow/<run>/main` into their branch, or iterate. Record with `flow.sh gate B …`.

### Phase 6 · Handoff
Write the changelog, PR notes, and decision summary. **Size decides who writes them**: for
a run of one or two plans, write them yourself — a spawn costs more than a few lines of text.
Dispatch a `haiku` `docs` agent only when the handoff is substantial (several plans, release
notes, docs updates across files). `plans/` (and `SPEC.md` when it exists) stays as the
record, so the run can be resumed or replayed. Clean up plan worktrees; keep the integration
branch until the user has merged it.

---

## Showing the fleet

Render the panel with `flow.sh panel`. It reads the state file, so it never drifts from
reality and costs no output tokens to compute — never hand-write the table.

Honest note: the panel refreshes **per turn**, as agents report. It is not a live dashboard.
If `TaskCreate`/`TaskList` exist, mirror each plan as a task too.

## Principles that do not bend

1. The brain is bundled (`references/planning.md`, `references/review.md`). Follow it; never
   hunt for an external skill.
2. Human gates A and B are mandatory.
3. Parallelize by **waves** derived from the DAG, with a barrier between them. Approved work
   is integrated before the next wave starts. State lives in `.flow/state.json`; the circuit
   breaker stops at 3 attempts.
4. Verify means the plans' done criteria plus the smoke run, as deterministic code on the
   integrated result — never an agent's opinion. A substituted smoke is reported as such.
8. Ceremony scales with the work. Never create an artifact or spawn an agent whose cost
   exceeds what it protects — the same rule that batches trivial plans applies to every phase.
5. Execution goes to the cheap tier, judgment to the expensive one. Report the ledger when it helps.
6. The execute↔verify loop converges under an attempt ceiling.
7. The advisor **never edits code directly** — it writes plans and reviews diffs. The fleet
   executes in isolated worktrees. The integration branch is the only thing it merges into;
   never merge into the user's branch or push without Gate B.
