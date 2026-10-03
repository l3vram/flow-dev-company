# GitHub Issue Template — material findings and errors

Use this template when creating a GitHub Issue for a discovered bug, investigation finding, or material error.

**Remember:** Issues are optional, explicit, and linked back to the repository source of truth. The issue is a pointer and collaboration surface, not the detailed implementation log.

---

```markdown
# <issue title>

## Objective

<What needs to be fixed, tracked, or coordinated. 1–2 sentences.>

Example:
"The order list endpoint has an N+1 query that causes timeouts on accounts with > 10K orders. This needs to be fixed before the feature goes into production."

## Evidence

- `src/orders/api.ts:130–160` — order list endpoint code
- command `npm run profile -- orders/list --users=1000` → observed 47 database queries for 47 API calls
- commit `a1b2c3d` — introduced the query pattern
- issue #123 — related: "Orders page slow on large accounts"

## Impact

<What is the consequence if this is not fixed. How severe is it.>

Example:
"Accounts with > 10K orders cannot use the order list feature. Page load times exceed 30 seconds. Production SLA is 2 seconds. This is a P1 blocker."

## Scope

### In scope

- Fix the N+1 query in the order list endpoint
- Add database index on `orders.created_at`
- Add test for the query performance

### Out of scope

- Other order-related endpoints (handled separately)
- Client-side pagination changes
- Cache layer (future work)

## Acceptance criteria

- [ ] Order list endpoint uses a single query (verified with query profiler)
- [ ] Index on `orders.created_at` is created
- [ ] Load test passes: 10K orders, < 2 second response time
- [ ] Test added to prevent regression
- [ ] No changes to the public API response shape

## Related

- Task: `tasks/TASK-089/`
- Plan: `plans/089-orders-n1-fix.md`
- Branch: `flow/<run-id>/089`
- PR: <link when available> or `none`

## Suggested approach

<Optional: a brief pointer to how this might be solved.>

Example:
"Use a JOIN with GROUP BY instead of the loop. See similar pattern in `src/users/api.ts:45–80`."

## Labels

- `bug`
- `performance`
- `p1`
- `orders`

---

*This issue was created as part of TASK-089. Implementation will proceed in the linked task and plan files, which are the source of truth. This issue tracks the coordination and serves as a search/discovery surface.*
```

---

## When to create an issue

Create a GitHub Issue when:

1. **Material severity**: the bug/finding is important enough to survive this task
2. **Cross-team coordination**: multiple teams or future work depends on it
3. **External tracking**: stakeholders outside the immediate task need visibility
4. **Significant scope**: the fix is large and deserves its own project/epic

**Do not create an issue** for:

- Trivial findings that will be fixed in the current task
- Internal notes that do not require external coordination
- Work that stays within a single task

---

## Issue link pattern

Always link the issue back to the repository source of truth:

```markdown
- Task: `tasks/TASK-xxx/`
- Plan: `plans/NNN-*.md`
- Branch: `flow/<run>/<id>`
```

This way, the issue is a pointer to the real work, not a duplicate.

---

## Notes

- Keep the issue concise: 200–300 words max.
- Link to file paths and commits for evidence.
- Do not paste entire code blocks; reference them by file:line.
- Acceptance criteria should be machine-checkable.
- Update the issue only at meaningful milestones, not every agent turn.
