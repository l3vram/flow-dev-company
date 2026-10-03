# flow-dev-company

## Task Context and issue protocol

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
