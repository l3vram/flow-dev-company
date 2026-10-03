# Context Template — context.md

Use this template for `tasks/TASK-<number>/context.md`. This file is for complex tasks only (Tier 3).

---

```markdown
# Context — TASK-<number>

## Architecture

<Relevant architectural sections only. Not a full design document.>

### Modules involved

- `module/path` — what it does
- `module/path` — what it does

### Key subsystems

<Brief description of how relevant subsystems interact.>

## Existing behavior

<What the code does today, focusing on what this task will change.>

### Example

```typescript
// Current behavior at src/orders/api.ts:130
const orders = await db.orders.find(userId); // N+1 query
```

## Relevant code

| File | Lines | Why it matters |
|---|---|---|
| `src/orders/api.ts` | 130–160 | Contains the N+1 query |
| `src/db/connection.ts` | 45–80 | Database initialization; connection pooling |
| `src/lib/result.ts` | 1–50 | Error handling pattern to follow |

## Conventions

- **Error handling**: Use the Result pattern from `src/lib/result.ts`. Example in `src/users/api.ts:40–60`.
- **Naming**: CamelCase for types, camelCase for variables. Follow ADR-002 for naming decisions.
- **Testing**: Model tests after `src/__tests__/orders.test.ts`.
- **Commits**: Use conventional commits: `feat(orders): ...`, `fix(orders): ...`, `test(orders): ...`.

## Constraints

- Database migration must be backward compatible.
- Public API response shape cannot change (clients depend on it).
- Temporary feature flags must be removed by end of sprint.

## Dependencies

- Depends on the schema migration landing first (TASK-xxx or plan NNN).
- Does not depend on anything else.
- Other work may depend on this: TASK-yyy, TASK-zzz.

## Known risks

- The N+1 query may timeout on large datasets; monitor with `SELECT COUNT(*) FROM orders`.
- Index creation on a large table may lock writes; consider online migration if > 10M rows.
- Client cache invalidation: verify that all clients are aware of the new response schema.

## Verification environment

- Node.js 18+, PostgreSQL 13+
- Run locally or in staging; production database is read-only for safety
- Smoke scenario: `npm run test:e2e -- orders` must pass
```

---

## Notes

- Do not copy entire source files; reference by file/symbol/commit.
- Point to specific lines that matter.
- This is for Tier 3 tasks only. For Tier 2, skip this file.
- Keep this under 200 lines.
