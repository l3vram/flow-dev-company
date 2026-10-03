# Investigation Template — investigation.md

Use this template for `tasks/TASK-<number>/investigation.md`. Required for Tier 3 tasks; optional for Tier 2.

Use this to record discoveries that were not known when the task was created and that materially affect implementation.

---

```markdown
# Investigation — TASK-<number>

## 2026-10-03 14:22 UTC — Existing movement records can be reused

### Finding

The database contains 47 movement records from a prior integration that were never fully utilized. These records have the exact structure we need for the denomination resolver. We can reuse them without schema changes.

### Evidence

- `src/db/migrations/009_create_movements.sql:10–30` — movement table schema
- command `SELECT COUNT(*) FROM movements WHERE purpose='denomination_exchange';` → 47 rows
- commit `a1b2c3d` — initial movement table design in 2024-03

### Impact

We do not need a new table or migration. Implementation is simpler. Reuse reduces database friction and keeps the schema stable.

### Action

Update the plan to point to the existing movement table instead of creating a new table. Mark plan step "Create denomination resolver table" as SUPERSEDED.

---

## 2026-10-03 15:30 UTC — Refresh token rotation works correctly

### Finding

Tested the refresh token rotation logic with 10 concurrent requests. All tokens were correctly invalidated and rotated. No race conditions detected.

### Evidence

- command `npm run test:e2e -- auth/refresh-rotation` → PASS (10 concurrent, 0 failures)
- test file: `src/__tests__/auth/refresh-rotation.test.ts:45–120`
- commit `f1e2d3c` — refresh rotation implementation

### Impact

The refresh token implementation is production-ready. No additional robustness work needed.

### Action

No changes to plan. Mark this as verified and ready for review.

---

## 2026-10-03 16:15 UTC — Index creation locks writes for ~2 seconds

### Finding

Added an index on the `orders.created_at` column. The lock duration was measured:

```
BEFORE INDEX: SELECT COUNT(*) FROM orders → ~100K rows
INDEX CREATION: ~2 seconds of write lock observed
AFTER INDEX: SELECT COUNT(*) FROM orders → 100K rows, index is used
```

### Evidence

- command `CREATE INDEX CONCURRENTLY idx_orders_created_at ON orders(created_at);` → 2.1 second lock observed
- PostgreSQL logs: `2026-10-03 16:15:00 WARNING: … EXCLUSIVE LOCK …`
- production table: `orders` has 103K rows

### Impact

Index creation with `CONCURRENTLY` is safe for our data size. No application downtime needed. Lock is acceptable.

### Action

Use `CREATE INDEX CONCURRENTLY` in the migration. No additional coordination needed.

---

## 2026-10-03 17:00 UTC — SUPERSEDED: 47 existing movement records

*This finding is SUPERSEDED by a later discovery.*

Original: Existing movement records can be reused.

Superseded by: The movement table was deprecated in commit `g2f3e4d`. We must use the new `denomination_changes` table instead.

New approach: Migrate existing records to the new schema. This is a small operation and will be done as part of the plan.

---

## (No more investigations)
```

---

## Notes

- Every investigation entry must have a timestamp in `YYYY-MM-DD HH:MM UTC` format.
- Evidence is required: never speculate.
- Mark findings as `SUPERSEDED` when a later discovery makes them obsolete.
- Investigation entries are additive; do not delete them.
- This is where the next agent learns what was discovered and how it changed the work.
