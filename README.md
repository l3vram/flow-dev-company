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

```text
0 Start/Resume → 1 Enrich → 2 Plan → 🚦GATE A → 3 Execute (waves) → 4 Verify → 5 Review → 🚦GATE B → 6 Handoff
                 (questions  (advisor   human    (parallel fleet,    (tests +   (branch   human   (docs)
                  → SPEC.md)  brain)             integrated per     smoke run) review)
                                                  wave)
```

- **Resume / execute mode** — if a run is already in flight (`.flow/state.json`), it picks up
  where it left off. Point it at an existing plan (`run plans/156-*.md`) and it skips the spec
  and goes straight to reconcile → approval → fleet.
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
  smoke run** that boots the product and drives its main flow. When the product cannot
  start in the environment (no mobile SDK, no device), it falls back to the highest runnable
  layer and reports the smoke as *substituted* — never as a pass. A substitute needs an owner
  and the exact device/environment check that closes it; it lands in the task handoff and the
  task cannot be marked done until the owner records the real result. Deterministic, blocking.
- **Risk-routed review** — a router decides the review budget per diff: high-risk changes
  (auth, payments, crypto, migrations, new deps, LLM tool calling, large diffs) get the full
  four-layer gauntlet on the expensive tier; everything else gets spec-compliance +
  correctness on a cheaper one.
- **Security, bundled from Cloudflare** — the security layer of that review uses Cloudflare's
  [security-audit](https://github.com/cloudflare/security-audit-skill) methodology on the code
  the fleet generates, and can optionally review the whole run's diff at the end, with its
  findings turned into fix plans. Levels and costs below.
- **🚦 Gate B** — final human review before you merge the integration branch, with every
  blocked/skipped plan listed and a token ledger for the run.

Details in [`SKILL.md`](SKILL.md) and the `references/` files it loads per phase.

## Git-native task context

`flow-dev-company` treats Git as part of the durable development memory. A meaningful task has a
stable identity and a small set of versioned context files. Agents use those files together with
Git history and diffs instead of relying on conversation history.

```text
tasks/
└── TASK-142/
    ├── task.md
    ├── context.md
    ├── investigation.md
    ├── decisions.md
    └── handoff.md
```

And the overall flow is:

```text
Issue → Task → Plan → Branch → Commits → PR → Merge
```

The distinction is important:

- Issue = collaboration/index
- Task = durable work identity
- Plan = implementation procedure
- Git = implementation evidence
- Basic Memory = reusable project knowledge

This keeps GitHub issues as a useful index surface without making them the task source of truth.

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

## Security review

Cloudflare's `security-audit` skill ships inside this one (`references/security-audit/`,
unmodified, MIT) as the security layer of review. It reviews **the code the fleet generates**;
auditing an existing system end to end is out of scope and done externally.
`references/security.md` decides when it runs and what it costs:

| Level | What runs | Cost |
|---|---|---|
| `guidance` (default) | Every high-risk diff's review reads only the matching sections (auth, LLM/tool calling, supply chain, tenancy…) and applies Cloudflare's evidence bar: no named principal, input, control and affected resource, no REVISE | a few thousand input tokens per such diff, no extra agents |
| `scoped` | Also Cloudflare's full workflow over the whole run's diff at Phase 5; introduced findings become fix plans | ≥6 agents of fixed overhead plus one hunter per coverage unit, under a strict budget you approve at Gate A |

Pick it in the spec (`Security: guidance | scoped`); Fast MVP implies `guidance`,
Production-grade implies `scoped quick`. Gate B always shows what ran (`flow.sh security`).

**What it cannot prove here.** Cloudflare marks a finding `confirmed` only after reproducing it
inside an OS-enforced sandbox (no network, empty environment, resource limits) with trusted
evidence-promotion code. Claude Code worktrees are not that sandbox, so by default the review
is source-only: leads come back as `needs_validation` with an exact trace, and the fleet settles
each one with a regression test (validate-then-fix plans). `confirmed: 0` from a source-only
review means "not proven", never "secure". Cloudflare also reports that one run found roughly
half of what repeated runs found — treat a review as a pass, not a guarantee.

## Install

```bash
git clone https://github.com/l3vram/flow-dev-company.git ~/.claude/skills/flow-dev-company
```

Restart your Claude Code session (skills load at startup), then:

```
/flow-dev-company I want to build a chatbot
```

Or invoke it empty and it will ask what to build. Requires `git` and `jq`; without `jq` the
orchestrator falls back to maintaining state itself and says so. A `scoped` security review
also needs Node.js, for Cloudflare's zero-dependency validators.

Test the plumbing:

```bash
~/.claude/skills/flow-dev-company/scripts/test-flow.sh   # 102 checks, throwaway git repo
```

It also checks that the vendored security files still have the sections `security.md` points
at. Cloudflare's own validator tests run with
`node references/security-audit/validate-findings.test.cjs` and
`node references/security-audit/validate-coverage-ledger.test.cjs`.

## Structure

```text
flow-dev-company/
  SKILL.md                     # the orchestrator — thin index, one reference per phase
  README.md                    # overview and Git-native task context documentation
  references/
    planning.md                # advisor brain: greenfield + recon/audit → plans
    task-context.md            # normative Task Context protocol for tasks, handoff, and review
    review.md                  # risk router, four-layer gauntlet, verdicts, reconcile
    execution.md               # waves, agent roster, dispatch, return contract, state
    token-budget.md            # where tokens go, language policy, tiering, cache discipline
    security.md                # security layer of review: when it runs, its cost, findings → fix plans
    security-audit/            # Cloudflare's security-audit skill, vendored unmodified (MIT)
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
- The security methodology (`references/security-audit/`) is Cloudflare's
  **[security-audit](https://github.com/cloudflare/security-audit-skill)** skill, Copyright
  (c) 2025-2026 Cloudflare, Inc., MIT licensed, vendored unmodified at the commit recorded in
  its `UPSTREAM.md`. flow-dev-company's adaptation lives in `references/security.md`.
- Orchestration patterns distill ideas from
  [aaddrick/claude-pipeline](https://github.com/aaddrick/claude-pipeline) (JSON state, layered
  gates), [barkain/claude-code-workflow-orchestration](https://github.com/barkain/claude-code-workflow-orchestration)
  (wave scheduling, agent roster), and the Planner→Executor→Reviewer architecture common to
  AgentMesh / CrewAI / AutoGen.
- Executor discipline borrows from [DietrichGebert/ponytail](https://github.com/DietrichGebert/ponytail)
  (write the least code; size-compliance review) and
  [addyosmani/agent-skills](https://github.com/addyosmani/agent-skills) (test-first fixes,
  source-driven API use). Recon reads a [graphify](https://github.com/Graphify-Labs/graphify)
  map when one exists.
- The compression policy is informed by [juliusbrussee/caveman](https://github.com/juliusbrussee/caveman)
  and the independent benchmarks that measured it honestly — including
  [Kuba Guzik's 85-token micro-prompt](https://dev.to/jakguzik/i-benchmarked-the-viral-caveman-prompt-to-save-llm-tokens-then-my-6-line-version-beat-it-2o81),
  which matched or beat the full published skill.

## License

MIT — see [`LICENSE`](LICENSE). Includes third-party MIT portions (see Credits).

