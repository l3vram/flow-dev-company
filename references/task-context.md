# Task Context Protocol — Adaptive ceremony with continuity

Git is the durable source of engineering context. The task layer exists to preserve why a change happened, what was discovered, what decision was made, and what the next agent should do — without copying the entire conversation or turning GitHub Issues into the source of truth.

This protocol scales according to task complexity.

---

## Complexity tiers

### Tier 1 — Trivial

Use when:
- typo, one-line config change, small comment fix
- no meaningful risk or agent handoff
- full verification fits in a short loop

Rule:
- do not create a task directory
- use normal commit + verification only

### Tier 2 — Small but meaningful

Use when:
- focused bug fix
- small feature with clear scope
- task can be completed by one agent or in one short sequence

Use minimal task context:

```text
tasks/TASK-<number>/
  ├── task.md
  └── handoff.md
```

`task.md` should contain only intent, status, scope, acceptance criteria, and base state.
`handoff.md` should capture entry/exit state, files changed, commits, verification, remaining work, and next action.

### Tier 3 — Complex / multi-agent / high-risk

Use when:
- multiple files or subsystems
- multiple agents / multiple waves
- architectural decisions or safety-risk changes
- work likely to resume after context loss

Use full task context:

```text
tasks/TASK-<number>/
  ├── task.md
  ├── context.md
  ├── investigation.md
  ├── decisions.md
  └── handoff.md
```

For complex tasks, `handoff.md` is a short iteration log with timestamps, state on entry, work completed, files changed, commits, verification, next action, and exit state.

---

## Minimum contract by tier

### Tier 1 — none

No task files required. Git history and the plan/done criteria are enough.

### Tier 2 — minimal task files

#### `task.md`

```md
# TASK-<number> — <title>

## Status
BACKLOG | READY | ANALYZING | IMPLEMENTING | VALIDATING | REVIEW | DONE | BLOCKED | CANCELLED

## Objective
<What needs to change and why.>

## Scope
### In scope
- ...
### Out of scope
- ...

## Acceptance criteria
- [ ] ...
- [ ] ...

## Current state
<Short factual summary.>

## Related
- Issue: <URL or `none`>
- Plan: `plans/NNN-*.md`

## Verification
- Build: `<command>`
- Tests: `<command>`
- Smoke: `<command>`
```

#### `handoff.md`

```md
# Handoff

## Task
TASK-<number>

## Agent
<agent/model>

## Status
IMPLEMENTING | VALIDATING | REVIEW | BLOCKED | DONE

## Completed
- ...
- ...

## Files changed
- `path`
- `path`

## Commits
- `<sha>` — <message>

## Verification
- `<command>` — PASS | FAIL | NOT RUN

## Remaining work
- ...

## Exact next action
<One concrete next action.>
```

This is sufficient for small but meaningful work.

---

### Tier 3 — full task context

#### `task.md`

Use the full task contract with:
- objective
- user-visible outcome
- acceptance criteria
- scope and non-scope
- relevant technical area
- issue/plan/PR references
- current state
- verification commands
- evidence and last updated timestamp
- current handoff pointer

#### `context.md`

```md
# Context

## Architecture
<Relevant architecture only.>

## Existing behavior
<What the code does today.>

## Relevant code
- `path/to/file:line` — reason it matters
- `path/to/file:line` — reason it matters

## Conventions
- ...

## Constraints
- ...

## Dependencies
- ...

## Known risks
- ...
```

#### `investigation.md`

Required when the task discovers facts not known at creation time.

```md
# Investigation

## <YYYY-MM-DD> — <short finding>

### Finding
<Concrete fact discovered.>

### Evidence
- `path/to/file:line`
- commit `<sha>`
- command `<command>` → `<result>`

### Impact
<How this changes implementation or verification.>

### Action
<What should happen because of this finding.>
```

#### `decisions.md`

ADR-lite format. If the decision changes, create a new `DEC-<n>-02` superseding `DEC-<n>-01`.

#### `handoff.md`

For complex tasks, keep a timestamped iteration log.

```md
# Handoff

## Task
TASK-<number>

## Iteration
1

## Agent entry
<agent/model>

## Status
IMPLEMENTING

## Completed
- ...

## Files changed
- `path`

## Commits
- `<sha>` — <message>

## Verification
- `<command>` — PASS

## Important discoveries
- ...

## Decisions made
- DEC-<number>-01

## Remaining work
- ...

## Exact next action
<One concrete next action for the next agent.>
```

This ensures continuation without prior chat history.

---

## Agent loading protocol

Before modifying a task, every executor/reviewer must read:

1. `tasks/TASK-xxx/task.md`
2. `tasks/TASK-xxx/context.md` (if present)
3. `tasks/TASK-xxx/handoff.md`
4. `tasks/TASK-xxx/decisions.md` (if present)
5. `tasks/TASK-xxx/investigation.md` when relevant
6. the associated plan
7. `git status`
8. task-related `git log`
9. the relevant diff

If task context and Git disagree:
- stop
- identify the discrepancy
- update the task context if safe
- report it before continuing

This is the core interoperability rule.

---

## Issue creation for findings and errors

Issue creation is explicit and optional, not implicit. Use it when a finding is important enough to be tracked beyond the current task.

When creating an issue for a discovered bug or an investigation finding, use:

```md
# <issue title>

## Objective
<What needs to be fixed or tracked.>

## Evidence
- `path/to/file:line` — reason it matters
- command `<command>` → `<result>`
- commit `<sha>`

## Impact
<Consequence if not fixed.>

## Scope
### In scope
- ...
### Out of scope
- ...

## Acceptance criteria
- [ ] ...
- [ ] ...

## Related
- Task: `tasks/TASK-xxx/`
- Plan: `plans/NNN-*.md`
- Branch: `flow/<run>/<id>`
- PR: `<URL or none>`
```

This allows the project to create issues for real findings without making the issue tracker the task source of truth.

---

## Rules that do not bend

1. Git is authoritative.
2. If the handoff says one thing and Git says another, the handoff is stale.
3. No task directory for trivial tasks.
4. No chat transcript in task files.
5. Every multi-agent handoff must include a concrete next action.
6. Every issue must reference the task/plan it came from when relevant.
7. Do not create an issue for every internal note; only for material actionable findings.

---

## Practical threshold

Use the following practical threshold:

- trivial: normal commit, no task context
- small but meaningful: task + handoff only
- medium/large: task + context + handoff + decisions as needed
- high-risk/multi-agent: full context + issue + plan + PR trail

This keeps ceremony proportional to the work without losing continuity.

---

## Summary

- Small tasks stay small.
- Complex tasks leave a durable audit trail.
- Issues are optional, explicit, and linked back to the repo truth.
- Handoffs are proof artifacts, not chat logs.
- The next agent can always resume from Git + task files without prior conversation.


---

## Issue protocol and source-of-truth hierarchy

This skill keeps the existing orchestration model (`plans/`, `waves`, `.flow/state.json`, Gate A/B), but adds a Git-native task layer for durable context. The task layer is an execution aid, not a second state machine.

### Source-of-truth hierarchy

1. Git code/history — authoritative evidence of what actually changed.
2. Task files under `tasks/TASK-xxx/` — intended purpose, context, decisions, handoff state.
3. GitHub Issue — collaboration/index surface, useful but not the source of truth.
4. Basic Memory — reusable project knowledge across tasks.

If task files and Git disagree, reconcile against Git first.

### Task context scaling by complexity

- Trivial work: no task directory. Normal git commit + verification is enough.
- Small but meaningful work: `tasks/TASK-xxx/task.md` + `tasks/TASK-xxx/handoff.md`.
- Complex work: `task.md`, `context.md`, `investigation.md`, `decisions.md`, `handoff.md`.

The task file set must remain proportional to the task; the goal is minimal ceremony but durable continuity.

### Issue creation policy

Issues are optional and explicit. They are not the source of truth, they are the collaboration/index surface.

Create a GitHub Issue when:
- the task is large enough to need coordination with humans or other agents
- the task or a discovered defect has cross-cutting scope
- a finding is severe enough to require tracking outside the current task branch
- the work is being published with `--issues`

For tasks created from a plan, the issue should at minimum reference:
- task path
- plan path
- branch
- PR link (when available)
- current status

For a discovered defect or investigation finding, create an issue only when it is material, actionable, and not already covered by the current task. The issue should include:
- title
- objective
- evidence (paths, commands, commit or findings)
- scope and impact
- acceptance criteria
- related task/plan link
- owner or next action

Use this pattern:

```md
# <issue title>

## Objective
<What needs to be fixed or tracked.>

## Evidence
- `path/to/file:line` — reason it matters
- command `<command>` → `<result>`
- commit `<sha>`

## Impact
<Consequence if not fixed.>

## Scope
### In scope
- ...
### Out of scope
- ...

## Acceptance criteria
- [ ] ...
- [ ] ...

## Related
- Task: `tasks/TASK-xxx/`
- Plan: `plans/NNN-*.md`
- Branch: `flow/<run>/<id>`
- PR: `<URL or none>`
```

This ensures that findings are captured without turning issues into a second source of truth.

### Handoff contract

Every agent that touches a task must update `handoff.md` before handing off. The next agent must read:

- `task.md`
- `context.md`
- `handoff.md`
- `decisions.md`
- `investigation.md` when relevant
- the associated plan
- `git status`
- task-related `git log`
- relevant diff

If task context and Git disagree, stop and reconcile before making changes.

### Minimal example

```text
tasks/
└── TASK-142/
    ├── task.md
    ├── handoff.md
    └── context.md   # only when the task is not trivial
```

This keeps the protocol compact while preserving continuity across sessions and agents.
