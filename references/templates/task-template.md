# Task Template — task.md

Use this template for `tasks/TASK-<number>/task.md`. Adapt the sections based on task tier.

---

```markdown
# TASK-<number> — <title>

## Status

BACKLOG | READY | ANALYZING | IMPLEMENTING | VALIDATING | REVIEW | DONE | BLOCKED | CANCELLED

## Objective

<What needs to change and why. 1–3 sentences.>

## User-visible outcome

<What the user/team should observe when complete.>

## Scope

### In scope

- ...
- ...

### Out of scope

- ...
- ...

## Acceptance criteria

- [ ] ...
- [ ] ...
- [ ] ...

## Technical area

<Module/package, important files, important symbols.>

## Related

- Issue: <GitHub URL or `none`>
- Plan: `plans/NNN-slug.md`
- Decision: DEC-<number>-01, DEC-<number>-02
- PR: <PR URL or `none`>

## Current state

<Short factual summary of the repo state.>

## Verification

| Purpose | Command |
|---|---|
| Build | `<command>` |
| Tests | `<command>` |
| Lint/typecheck | `<command>` |
| Smoke | `<command>` |

## Evidence

- Base commit: `<sha>`
- Current commit: `<sha>`
- Relevant commits: `<sha>`, `<sha>`

## Last updated

<ISO timestamp>

## Current handoff

Read `handoff.md` before modifying this task.
```

---

## Notes

- Keep this concise: 50–150 lines max.
- The plan contains detailed steps; this file is the stable task identity.
- For Tier 1 tasks, skip the task file entirely.
- For Tier 2 tasks, keep acceptance criteria and status only.
- For Tier 3 tasks, use the full template.
