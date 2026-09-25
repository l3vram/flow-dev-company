# flow-dev-company

**End-to-end software development orchestrator for Claude Code.**
One skill: give it a goal ("I want to build a chatbot"), it enriches the spec with
senior-level questions, plans the work, and executes with a **fleet of parallel agents** —
an expensive brain plans and reviews, cheap hands execute in isolated worktrees, every task
at the right model tier.

Self-contained: **nothing else to install.**

---

## The idea in one line

> A prompter asks a question. An architect draws a graph.
> This skill turns "do A, then B, then C" into waves of agents running in parallel, with
> human gates where decisions matter and verification where trust matters.

## How it works

```
0 Start/Resume → 1 Enrich → 2 Plan → 🚦GATE A → 3 Execute (waves) → 4 Verify → 5 Review → 🚦GATE B → 6 Handoff
                 (questions  (advisor   human    (parallel fleet,    (tests +   (branch   human   (docs)
                  → SPEC.md)  brain)             integrated per     smoke run) review)
                                                  wave)
```

- **Resume** — if a run is already in flight (`.flow/state.json`), it picks up where it left off.
- **Enrich** — specializes into your domain, proposes what good engineering includes even if
  unasked, and asks the missing questions with options + presets (MVP / Production / Custom).
  The result is written to `plans/SPEC.md`, including the smoke scenario that proves it works.
- **Plan** — an advisor brain (expensive tier) writes self-contained plans plus their
  dependency graph (DAG).
- **🚦 Gate A** — you approve the plan before any budget goes to the fleet.
- **Wave execution** — the DAG is layered into *waves* (topological, via Kahn); each wave runs
  in parallel in isolated worktrees, every agent with its **role** (backend/frontend/data/qa/
  docs…) and **tier**. Approved work is merged into an **integration branch**
  (`flow/<run>/main`, in its own worktree — your checkout is never touched), and the next wave
  branches from it, so dependent plans build on real code. Barrier between waves, 3-attempt
  circuit breaker per plan, blocked plans cascade-skip their dependents instead of stalling.
- **Verify** — on the integrated result: every plan's done criteria (build/test/lint) **plus a
  smoke run** that boots the product and drives its main flow. Deterministic, blocking.
- **Risk-routed review** — a router decides the review budget per diff: high-risk changes
  (auth, payments, crypto, migrations, new deps, large diffs) get the full four-layer gauntlet
  on the expensive tier; everything else gets spec-compliance + correctness on a cheaper one.
- **🚦 Gate B** — final human review before you merge the integration branch, with every
  blocked/skipped plan listed and a token ledger for the run.

Details in [`SKILL.md`](SKILL.md) and the `references/` files it loads per phase.

## Token discipline

The fleet is only worth running if it does not burn the budget. This skill is built around
where the tokens actually go — not where it is easiest to optimize:

Estimated distribution (a design heuristic, not a measurement — `flow.sh report` gives you
the real numbers for your runs):

| Cost center | Est. share | Lever |
|---|---|---|
| Reviewing diffs on the expensive tier | ~45% | Risk router — most diffs never need it |
| Executors exploring cold repos | ~25% | Recon facts inlined into every plan |
| Self-contained plans copied per agent | ~15% | Accepted cost — plans are never compressed |
| Verbose agent returns | ~8% | Mandatory return contract |
| The skill's own text | ~7% | Progressive disclosure — one reference per phase |

Plus: everything internal is written in **English** (non-English text costs ~1.5x for the same
meaning), prompt prefixes are **cache-stable per role**, trivial plans are **batched** into one
agent, all plumbing (waves, state, panel, ledger) is **deterministic bash**, and a `budget`
ledger in `.flow/state.json` reports actuals at Gate B — unreported spawns are listed, never
guessed.

Compression is applied narrowly — to agent-to-agent reports, never to plans, code, or anything
you read. Published benchmarks put "caveman"-style compression at 8.5–21% on real coding tasks
(not the advertised 65–75%), and it costs input tokens per turn, so it is used where it pays
and nowhere else.

## Model tiering

| Tier | Model | For |
|---|---|---|
| Cheap | `haiku` | Executing specified plans, boilerplate, docs |
| Mid | `sonnet` | Implementing plans with non-trivial logic, routine review |
| Expensive | `opus` | Planning, specifying, high-risk review, deciding |

Judgment goes to the expensive tier; executing already-written plans goes to the cheap one.
Never the reverse.

## Install

```bash
git clone https://github.com/l3vram/flow-dev-company.git ~/.claude/skills/flow-dev-company
```

Restart your Claude Code session (skills load at startup), then:

```
/flow-dev-company I want to build a chatbot
```

Or invoke it empty and it will ask what to build. Requires `git` and `jq`; without `jq` the
orchestrator falls back to maintaining state itself and says so.

Test the plumbing:

```bash
~/.claude/skills/flow-dev-company/scripts/test-flow.sh   # 40 checks, throwaway git repo
```

## Structure

```
flow-dev-company/
  SKILL.md                     # the orchestrator — thin index, one reference per phase
  references/
    planning.md                # advisor brain: greenfield + recon/audit → plans
    review.md                  # risk router, four-layer gauntlet, verdicts, reconcile
    execution.md               # waves, agent roster, dispatch, return contract, state
    token-budget.md            # where tokens go, language policy, tiering, cache discipline
    audit-playbook.md          # audit categories (existing repos)
    plan-template.md           # self-contained plan format
  scripts/
    flow.sh                    # deterministic plumbing: waves, state, gates, integration, panel, ledger
    test-flow.sh               # regression suite for flow.sh
```

## Credits

- The bundled advisor brain (`planning.md`, `review.md`, `audit-playbook.md`,
  `plan-template.md`) derives from the **`improve`** skill by
  **[shadcn](https://github.com/shadcn)**, MIT licensed. Adapted with a **greenfield mode**
  for projects starting from zero, and split by phase for progressive disclosure.
- Orchestration patterns distill ideas from
  [aaddrick/claude-pipeline](https://github.com/aaddrick/claude-pipeline) (JSON state, layered
  gates), [barkain/claude-code-workflow-orchestration](https://github.com/barkain/claude-code-workflow-orchestration)
  (wave scheduling, agent roster), and the Planner→Executor→Reviewer architecture common to
  AgentMesh / CrewAI / AutoGen.
- The compression policy is informed by [juliusbrussee/caveman](https://github.com/juliusbrussee/caveman)
  and the independent benchmarks that measured it honestly — including
  [Kuba Guzik's 85-token micro-prompt](https://dev.to/jakguzik/i-benchmarked-the-viral-caveman-prompt-to-save-llm-tokens-then-my-6-line-version-beat-it-2o81),
  which matched or beat the full published skill.

## License

MIT — see [`LICENSE`](LICENSE). Includes third-party MIT portions (see Credits).
