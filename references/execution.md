# Execution — waves, roster, dispatch, state

How the fleet runs. Read this at the start of Phase 3; you do not need `planning.md` or
`review.md` loaded at the same time.

Distilled from aaddrick/claude-pipeline (JSON state, quality gates),
barkain/claude-code-workflow-orchestration (wave scheduling, agent roster), and the
Planner→Executor→Reviewer architecture common to AgentMesh/CrewAI/AutoGen.

---

## 1. Waves — derive parallelism, don't guess it

Read the dependency graph in `plans/README.md` and layer it topologically (Kahn):

- **Wave 1** = every plan with no dependencies.
- **Wave N** = plans whose dependencies all sit in waves < N.

Rules:
- Plans in the same wave run in parallel — dispatched in **one message**, in background.
- **Barrier between waves**: wave N+1 does not start until every plan in wave N is settled —
  green *and integrated*, blocked, or skipped.
- A blocked plan does not block its wave siblings. It does block its dependents: after the
  human gate decides, `flow.sh skip-dependents <id>` marks them skipped so the barrier can
  move, and they are reported at Gate B. Without this the pipeline stalls forever.

`scripts/flow.sh waves` computes the layering from the state file and rejects unknown
dependencies (exit 3) and cycles (exit 2). Use it. Hand-deriving a DAG in prose costs
expensive output tokens for something that is arithmetic.

### Integration — how wave N+1 sees wave N

Worktrees start from a commit, not from each other. Without an integration step every plan
is built on the original base, and "depends on 001" means nothing.

- `flow.sh integration-init` creates branch `flow/<run>/main` in its own worktree
  (`.flow/integration`). The user's checkout is never touched.
- Each executor works on branch `flow/<run>/<id>`, created **from the integration branch**
  at dispatch time — so it contains every dependency already integrated.
- After APPROVE: `flow.sh set <id> green && flow.sh integrate <id>` (a `--no-ff` merge).
- On a merge conflict (exit 6) the plan returns to `review`. `SendMessage` its executor:
  merge `flow/<run>/main` into its branch, resolve, re-run the done criteria, report. Two
  plans conflicting in one wave usually means the plans overlapped in scope — note it for
  the next planning pass.

---

## 2. Roster — every agent knows who it is and what it must not touch

Each dispatched agent adopts a role with an explicit contract: scope, anti-patterns, tier.
This table is the **stable prompt prefix** — copy the row verbatim so agents of the same
role share a cache hit (see `token-budget.md`).

| Role | Tier | Does | Never does |
|---|---|---|---|
| `architect` | opus | Designs, decomposes into plans, adjudicates findings | Writes product code |
| `backend-dev` | sonnet | Backend, API, business logic | Touches UI or infra outside its plan |
| `frontend-dev` | sonnet | UI, components | Changes API contracts unilaterally |
| `data-dev` | sonnet/haiku | Schema, migrations, seeds | Business logic beyond the data layer |
| `qa` | sonnet | Writes and runs tests, validates done criteria | Edits product code — tests only |
| `security-reviewer` | opus | Reviews through a security lens | Rewrites; reports findings only |
| `perf-reviewer` | sonnet | Reviews through a performance lens | Rewrites; reports findings only |
| `docs` | haiku | Changelog, README, PR notes | Architecture decisions |

Pick the role from the plan's category. When two fit, the narrower one wins.

---

## 3. Dispatch

One `Agent` call per plan (or per batch — see `token-budget.md`), `isolation: "worktree"`,
`run_in_background: true`, at the role's tier. Preconditions before any dispatch:

- The working repo is a git repository with at least one commit, and the integration
  worktree exists. If not, stop and say so — worktree isolation needs both.
- Gate A is approved and the plan appears in `flow.sh ready` (dependencies green and integrated).
- `flow.sh set <id> running` succeeded — it refuses a fourth dispatch.
- The plan's drift check passes. Never hand a stale plan to an executor.

**Prompt structure** — stable prefix first, byte-identical per role:

```
[PREFIX]  role row (verbatim from §2) + hard rules + caveman micro-directive
          + return contract
[SUFFIX]  full plan text inlined + worktree note + wave context
```

Inline the **full plan text**. The worktree contains only committed files; if `plans/` is
uncommitted, the executor cannot read it. Never assume it can.

**Executor preamble** (part of the stable prefix):

> You are the executor for the plan below. First, in your worktree, run
> `git switch -c flow/<run>/<id> flow/<run>/main` — you build on the integrated work, not
> the original base. Follow the plan step by step. Run every verification
> command and confirm the expected result before continuing. Touch only in-scope files. On
> any STOP condition, stop immediately and report — do not improvise around obstacles.
> Commit on that branch per the plan's git workflow; never push. Do not edit
> `plans/README.md` — your reviewer maintains the index. Before reporting, audit every claim
> against an actual tool result from this session — report only what you have evidence for;
> if a verification failed or was skipped, say so plainly.

**Fresh-worktree note**: worktrees share git history but not `node_modules` or build
artifacts. The executor installs dependencies first, and tooling that resolves from `dist/`
may need one build even if the plan's command table (recon'd in the main tree) omitted it.
This is expected, not a deviation.

---

## 4. Return contract — mandatory, not a suggestion

Agents must not dump diffs, file contents, or logs into the orchestrator's context. The
orchestrator reads what it needs from disk.

```
STATUS: COMPLETE | STOPPED
STEPS: per step — done/skipped + verification result
STOPPED_BECAUSE: (only if STOPPED) which condition, what was observed
FILES: paths only, no contents
WORKTREE: path
BRANCH: flow/<run>/<id>
NOTES: deviations, surprises, judgment calls — max 5 lines
```

For anything larger than this, the agent writes a file and returns `DONE|<path>`.
A report that violates the contract is a review failure on its own — re-request it rather
than reading the overflow, or the savings evaporate at the moment they matter most.

---

## 5. State file — resume, panel, circuit breaker

`.flow/state.json` in the working repo is the machine-readable source of truth. It survives
context loss, drives the panel, and enforces the retry ceiling.

```json
{
  "run": "2026-07-31-chatbot",
  "objective": "Support chatbot with streaming and moderation",
  "phase": "execute",
  "gates": { "A": "approved", "B": "pending" },
  "integration": { "branch": "flow/2026-07-31-chatbot/main", "base": "main",
                   "worktree": ".flow/integration" },
  "waves": [["001"], ["002", "003"], ["004"]],
  "current_wave": 1,
  "plans": [
    { "id": "001", "role": "data-dev", "tier": "haiku", "status": "green",
      "attempts": 1, "revisions": 0, "deps": [],
      "branch": "flow/2026-07-31-chatbot/001", "integrated": true },
    { "id": "002", "role": "backend-dev", "tier": "sonnet", "status": "running",
      "attempts": 1, "revisions": 1, "deps": ["001"],
      "branch": "flow/2026-07-31-chatbot/002", "integrated": false }
  ],
  "budget": { "by_phase": {}, "by_tier": {}, "by_plan": {}, "spawns": 0, "inline": 0, "unreported": [] },
  "smoke": { "result": "substituted", "detail": "no Android SDK — ViewModel tests" }
}
```

- `status`: `pending | running | review | green | blocked | skipped`. `phase` is updated with
  `flow.sh phase <name>` at every phase boundary so the panel tells the truth.
- **One counting rule.** An *attempt* is a fresh dispatch (`set running`); a *revision* is a
  `SendMessage` round to the same executor within an attempt (`flow.sh revise`). Max 3
  attempts per plan, max 2 revisions per attempt — the third revision blocks the attempt.
  After the third blocked attempt the circuit breaker trips: escalate to a human gate. Never
  burn budget on blind retries.
- Update on every transition via `scripts/flow.sh`, not by rewriting JSON in prose. Every
  input is validated; a non-zero exit means the transition did not happen.

---

## 6. Determinism — plumbing is code, not tokens

Control flow is deterministic code; only the work inside an agent belongs to the model.
Wave layering, state updates, panel rendering, dedupe, and result merging are `scripts/flow.sh`
territory — zero tokens. Do not spend an expensive model re-rendering a table each turn.

If you generate a real orchestration script: no `Date.now()`, `Math.random()`, or bare
`new Date()` in control flow. Pass timestamps as arguments so a run can be resumed and cached.

---

## 7. Subagent mode vs team mode

- **Default (subagent)**: each plan runs in an isolated `Agent` with a worktree and returns
  under the contract above.
- **Team mode** (only if `TeamCreate`/`SendMessage` exist): peer-to-peer agents on a shared
  task list — worth the extra coordination cost only when two plans must negotiate live.
  Default to subagent mode; team mode multiplies context, and context is the budget.
