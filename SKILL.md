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

Deterministic plumbing lives in `scripts/flow.sh` (waves, state, panel, ledger). Call it;
do not recompute a DAG or re-render a table in prose.

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

### Phase 0 · Start
If invoked with a goal, take it. If empty, reply and **wait**: "What are we building?"
Assume nothing, spawn nothing yet.

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

Close with a written **refined spec** and confirm it with the user.

### Phase 2 · Plan
Read `references/planning.md` and act as the advisor (or dispatch an `opus` subagent that
follows it, passing the absolute path).

- **Greenfield**: decompose the refined spec into **one independent piece per plan** so
  execution parallelizes. Plan #1 is usually the verification baseline.
- **Existing repo / large feature**: full workflow — Recon → parallel Audit → prioritized
  table → plans.

Output: files in `plans/` plus `plans/README.md` with order and dependencies. That is your DAG.

### GATE A · Human plan approval
Show the plans and the dependency order. The user approves via `AskUserQuestion` or
`ExitPlanMode`. **Do not dispatch the fleet without it.** Record with `flow.sh gate A approved`.

### Phase 3 · Run the fleet
Read `references/execution.md`. Register plans and layer the waves:

```
flow.sh init <run-id> "<objective>"
flow.sh add <id> <role> <tier> [deps]
flow.sh waves          # Kahn layering; exits 2 on a dependency cycle
flow.sh ready          # what is dispatchable right now
```

- Dispatch every ready plan of the current wave **in one message**, `isolation: "worktree"`,
  `run_in_background: true`, at the role's tier. Batch trivial same-role plans.
- **Barrier between waves**: `flow.sh wave-done` before `flow.sh advance`.
- When an executor returns, the brain reviews its diff through the **risk router** in
  `references/review.md` — most diffs never need `opus`. Treat every diff as untrusted
  until reviewed.
- A failing executor does not sink its wave: mark it blocked, continue with its siblings,
  requeue it. `flow.sh set` enforces the 3-attempt circuit breaker and escalates to a
  human gate.

### Phase 4 · Verify (code, not an agent)
Run each plan's done criteria (build/typecheck/lint/test). Deterministic and blocking.
A failure requeues to execution.

### Phase 5 · Final branch review
With everything integrated, run the branch review in `references/review.md`: audit only the
branch's changes, separating `introduced` from `pre-existing`. Surviving findings get fixed.

### GATE B · Human final review
Show the result against Phase 0's criteria, plus `flow.sh report` for the token ledger.
The user decides: merge or iterate.

### Phase 6 · Handoff
A `haiku` agent writes the changelog, PR notes, and decision summary. Offer to keep the
refined spec and `plans/` so the run can be replayed.

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
3. Parallelize by **waves** derived from the DAG, with a barrier between them. State lives in
   `.flow/state.json`; the circuit breaker stops at 3 attempts.
4. Verify means the plan's done criteria, run as deterministic code — never an agent's opinion.
5. Execution goes to the cheap tier, judgment to the expensive one. Report the ledger when it helps.
6. The execute↔verify loop converges under an attempt ceiling.
7. The advisor **never edits code directly** — it writes plans and reviews diffs. The fleet
   executes in isolated worktrees. Never merge or push without Gate B.
