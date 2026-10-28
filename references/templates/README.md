# Task-context templates

Copy these into `tasks/TASK-<number>/` when a task needs them. Ceremony scales with the task —
the tiers and the minimum files per tier are defined in `references/task-context.md`.

| File | Template | Tier |
|---|---|---|
| `task.md` | `task-template.md` | 2 and 3 |
| `handoff.md` | `handoff-template.md` | 2 and 3 |
| `context.md` | `context-template.md` | 3 |
| `investigation.md` | `investigation-template.md` | 3 (when something was discovered) |
| `decisions.md` | `decisions-template.md` | 3 (when a decision was made) |
| GitHub Issue body | `github-issue-template.md` | only with `--issues`, for material findings |

Tier 1 (trivial) needs no task directory. The repository stays the source of truth; an issue is
only a pointer back to `tasks/TASK-<number>/`.
