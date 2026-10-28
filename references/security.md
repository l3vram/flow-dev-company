# Security — the security layer of review

This is layer 3 of the gauntlet and the security part of the Phase 5 branch review. It
reviews **only the code the fleet generates in a run**. Read it when the risk router sends a
diff to the full gauntlet (Phase 3), or when `SPEC.md` sets `Security: scoped` (Phase 5). The
rest of a run ignores it.

Auditing an existing system end to end is out of scope — that is done externally, with its
own tooling. If the user asks for one, say so; never point the vendored workflow at a whole
repository from here.

The methodology is Cloudflare's `security-audit` skill, vendored unmodified in
`<SKILL_DIR>/references/security-audit/` (MIT; provenance in its `UPSTREAM.md`). Those files
are authoritative on *how* to review. This file decides only *when* flow uses them, at what
cost, and how their output feeds plans and gates. Never edit the vendored files — adapt here.
It is bundled, not registered: read its files, do not invoke it with the Skill tool.

---

## 1. Two levels — pick the cheapest that protects the work

| Level | Upstream mode | Runs | Cost (estimate) |
|---|---|---|---|
| `guidance` | guidance | Default. Phase 3, on every diff the router sends to the full gauntlet | ~2–4k input tokens per such diff, no extra agents |
| `scoped` | full audit, scoped to the run's diff | Phase 5, when `SPEC.md` says `Security: scoped` | `quick`: ≥6 agents fixed (4 recon, 1 critic, ≥1 verifier) + one hunter per coverage unit |

`guidance` always runs on HIGH-risk diffs; `scoped` adds a whole-run pass on top of it. The
SPEC line is `Security: guidance | scoped [quick|standard|deep]`; `scoped` defaults to `quick`.
A `scoped` review runs under a strict agent budget (upstream `budget`, counted in agent
invocations), approved with the plans at Gate A. Default for `scoped quick`: 15 — a starting
point, not a measurement; tune it from `flow.sh report`. Upstream refuses a budget that cannot
fund its reconnaissance and reserves; that refusal is information, not something to route
around.

For a run of one or two low-risk plans, recommend `guidance` even under the Production-grade
preset: six agents of fixed overhead to review a small diff the router already passed cost
more than they protect. Say so; the user decides.

## 2. What this environment can and cannot prove — say it before a `scoped` review

Upstream marks a record `confirmed` only with a **bounded local observed result**, produced
inside an OS-enforced sandbox (no external network, empty allowlisted environment, read-only
target, scratch-only writes, CPU/memory/process/file-size/time limits) and promoted into
evidence by trusted parent-side code. Flow's worktrees are **not** that sandbox — they have
network, the host environment, and write access — and flow ships no promotion code. So by
default every security review here is **source-only**:

- Security agents never build, test, or run the code. They read.
- Source-grounded leads land as `needs_validation`, the missing sandbox named as the blocker.
  Expect `confirmed: 0`. That is the evidence bar, not a clean bill of health — never present
  it as one.
- Flow closes the gap the way it closes every other one: a **validate-then-fix plan** (§5).
  The fleet writes the regression test the lead's `validation_plan.local` describes, in its
  own worktree under flow's normal rules, and the test settles the lead.
- `confirmed` becomes reachable only when the user supplies a sandbox that meets every
  upstream control *and* the promotion procedure in `security-audit/SKILL.md` §Write
  isolation. A container with no network, read-only mounts, an empty environment and cgroup
  limits covers the sandbox half; promotion still needs that trusted parent-side code. Never
  improvise a partial sandbox and call it compliant.

## 3. `guidance` — layer 3 of the gauntlet (Phase 3)

When the router sends a diff to the full gauntlet, the security layer (opus — your own
review, or a dispatched `security-reviewer`) reads from `security-audit/`:

1. `SKILL.md` — only `## Core principles` and `## Anti-patterns`.
2. For each trigger the diff hit, the row below. From a companion file read only its
   `Core discipline`, the matching attack-class section, and `Validation rules`; from
   `ATTACK-CLASSES.md` only the named bold block. At most two companions per diff — needing
   more means the diff should have been split; note it for the next planning pass.

| Router trigger | Read |
|---|---|
| auth, authz, session, permission | `WEB-PROTOCOL-AND-AUTH.md`; `ATTACK-CLASSES.md` → **Access control** |
| payments, billing, money | `ATTACK-CLASSES.md` → **Business logic** |
| crypto, secrets, tokens | `ATTACK-CLASSES.md` → **Cryptography and secrets** |
| outbound network, new egress | `ATTACK-CLASSES.md` → **Resource and file handling** |
| migrations, deletions, multi-tenant data | `DATA-ISOLATION-AND-LIFECYCLE.md` |
| new dependencies, CI, release | `SUPPLY-CHAIN-AND-RELEASE.md` |
| LLM tool calling, model-controlled actions, untrusted content in prompts | `AI-AND-LLM.md` |
| rendering user content in the DOM, postMessage, CORS | `CLIENT-SIDE.md` |
| IaC, containers, IAM, serverless config | `CLOUD-AND-DEPLOYMENT.md` |
| queues, webhooks, RPC, GraphQL | `PROTOCOLS-RPC-AND-MESSAGING.md` |
| unbounded work from untrusted input | `RESOURCE-EXHAUSTION-AND-AVAILABILITY.md` |
| native code, `unsafe`, FFI | `MEMORY-SAFETY-AND-BINARY.md` |
| mobile, desktop, deep links, local IPC | `DESKTOP-MOBILE-AND-LOCAL-IPC.md` |

Pass the reviewer absolute paths and section names; it reads the files itself. Nothing is
written to disk and no audit directory is created. The security layer stays read-only
(upstream's universal execution safety); layer 1's done-criteria runs are flow's and unchanged.

**The candidate gate decides the verdict.** A security REVISE or BLOCK names the lower-trust
principal, the accepted input, the missing or wrong control, and the affected principal or
resource, each with `file:line`. A concern that cannot name all four is a hardening note in
the review NOTES, not a REVISE — a false REVISE costs a full executor round. Severity follows
the anchors in `SKILL.md` §Separate priority from certainty; HIGH-severity findings still go
through adversarial verification (`review.md` §2).

## 4. `scoped` — the run's diff, upstream full audit mode (Phase 5)

Run upstream's six phases exactly as `security-audit/SKILL.md` and the phase files it links
define them — read each file at its phase, not all at once. Flow fixes only these values:

- **Target**: the integration worktree (`.flow/integration`, absolute path) as an upstream
  scoped run over the diff between `integration.base` and `flow/<run>/main`
  (`git -C .flow/integration diff --name-only <base>...HEAD`). Everything outside that diff
  is `out_of_scope` in the ledger — upstream records it, never as covered.
- **Output directory**: upstream's default, `~/security-audit-skill/<repo-name>/run-<N>`,
  where `<repo-name>` is the main checkout's name — never the worktree's `integration`.
  Inside the repository only when the user picks it and `git check-ignore -q <dir>` passes.
- **Profile and budget**: from the SPEC line (§1), recorded in upstream `run-metadata.json`.
- **Agents** (Claude Code mapping): parent = you, the orchestrator; Task tool = `Agent`;
  upstream `research` agent = `subagent_type: "Explore"` (no file-editing tools; the prompt
  still forbids writes); upstream `general` agent = `subagent_type: "general-purpose"`.
  Always pass `model`: reconnaissance, hunters, coverage critics → `sonnet`; Phase 3 candidate
  verifiers and Phase 5 record verifiers → `opus`. Never `haiku` — a cheap hunter's noise is
  paid for by expensive verifiers. Dispatch each wave in one message, `run_in_background: true`.
- **Prompts**: build hunter and verifier prompts in upstream's exact order. It is already
  cache-friendly: the preamble and `architecture.md` are identical across a wave.
- **Ledger**: every security agent is a spawn line —
  `flow.sh budget sec-<agent-id> <tokens|null> <tier> review`.
- **Validators**: run `validate-coverage-ledger.cjs` and `validate-findings.cjs` from
  `<SKILL_DIR>/references/security-audit/` exactly when upstream says. They need Node.js;
  without it the review cannot reach a terminal state — say so and fall back to `guidance`.
- **Terminal state**: upstream's — every report written and both validators passing, or
  `run_status: "incomplete"` with its reason. Then record it for Gate B:
  `flow.sh security scoped "<profile>, <agents spent>/<budget>, source-only|sandboxed" <output-dir>/findings.json`.

Record the security outcome even when no `scoped` review ran:
`flow.sh security guidance "<N> HIGH-risk diffs reviewed"`, or
`flow.sh security skipped "<why>"`.

## 5. From `findings.json` to fix plans

Tag every record `introduced` (in code this run wrote) or `pre-existing`, as the branch review
does. Pre-existing records are not this run's work: list them at Gate B for the external audit
or the backlog, and plan them only if the user adds them.

For introduced records the planner reads `findings.json`, never the prose reports, and writes
one plan per fingerprint with `plan-template.md` — excerpts from its own reads, as always, and
the run's Task ID. The plan's Status block carries `Finding: <fingerprint> (<findings.json path>)`.
Fix plans requeue to execution like a Phase 4 failure.

| Introduced record | Becomes |
|---|---|
| `confirmed` critical / high | fix plan, P1, `Risk: HIGH` (its diff gets the full gauntlet) |
| `confirmed` medium | fix plan, P2 |
| `confirmed` low / informational | P3 fix plan, or "not worth doing" with one line |
| `needs_validation`, blocker resolvable by a local test | validate-then-fix plan (below) |
| `needs_validation`, blocker is a deployment fact | no plan; listed at Gate B and in `handoff.md` with its `validation_plan.deployment` check for the owner |
| `rejected` | nothing to do; upstream keeps it in `findings.json` so the claim is not raised again |

**Validate-then-fix plan.** Step 1 writes the regression test from `validation_plan.local`
and runs it against the unfixed code. STOP condition: the test passes on unfixed code — the
lead is refuted; report it and change nothing. Otherwise fix at the last trusted decision
point (upstream's smallest effective source fix); that same test is the done criterion.

Plans state the invariant and the regression case ("a path with a parent-directory segment
is rejected with 400"). They never copy upstream `execution.payloads` verbatim: plans are
committed, and an executor does not need a working exploit to write a fix.

A fix loop does not re-run the `scoped` review by default: every fix plan is `Risk: HIGH`,
so its diff gets the `guidance` layer, and its regression test is the evidence. Offer a
`scoped quick` re-run against the same output directory at Gate B, with its budget — upstream
then revalidates the changed source instead of re-hunting.

## 6. Gate B

`flow.sh report` prints the recorded security line, or `security: not recorded` — absence is
never silent. Present, in the user's language:

- the level that ran, its profile, agents spent against budget, source-only or sandboxed;
- introduced findings by severity and what happened to each. An introduced critical or high
  is fixed before merge or explicitly accepted by the user;
- every open `needs_validation` lead with its exact blocker, and — when the review was
  source-only — the plain statement that `confirmed: 0` reflects the missing sandbox, not
  proven safety;
- pre-existing findings, handed to the external audit or the backlog;
- what was out of scope or deferred. Upstream reports that one run found roughly half of what
  repeated runs found; never imply a single pass exhausted even the run's own diff.
