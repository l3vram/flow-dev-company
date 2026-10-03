# Handoff Template — handoff.md

Use this template for `tasks/TASK-<number>/handoff.md`. Required for all non-trivial tasks.

For Tier 2 tasks, use a simple one-pass handoff. For Tier 3 tasks, use the iteration log format.

---

## Tier 2 Handoff (simple, single-pass)

```markdown
# Handoff — TASK-<number>

## Task

TASK-<number> — <title>

## Agent

<model/role>

## Status

IMPLEMENTING | VALIDATING | REVIEW | BLOCKED | DONE

## Completed in this turn

- ...
- ...

## Current implementation

<Short factual description of what exists now.>

## Files changed

- `path`
- `path`

## Commits

- `<sha>` — <message>
- `<sha>` — <message>

## Verification

- `<command>` — PASS | FAIL | NOT RUN
- `<command>` — PASS | FAIL | NOT RUN

Never claim PASS without evidence from this session.

## Known issues (if any)

- ...

## Remaining work

- ...

## Exact next action

<One concrete next action for the next agent or human.>

## Do not redo

- ...
```

---

## Tier 3 Handoff (iteration log)

For complex or multi-agent tasks, keep an iteration log with entry/exit timestamps.

```markdown
# Handoff — TASK-<number>

## Task

TASK-<number> — <title>

## Current status

BACKLOG | READY | ANALYZING | IMPLEMENTING | VALIDATING | REVIEW | BLOCKED | DONE

---

## Iteration 1

### Agent entry

- **Agent**: <model/role>
- **Time in**: <ISO timestamp, e.g. 2026-10-03T14:22:00Z>
- **Entry status**: READY
- **Base branch**: `flow/<run>/main` or task branch name
- **Base commit**: `<sha>`

### Work completed

- Analyzed repository structure
- Implemented core feature
- Added tests

### Files changed

- `src/orders/api.ts`
- `src/orders/api.test.ts`

### Commits

- `<sha>` — feat: implement denomination resolver
- `<sha>` — test: add denomination resolver tests

### Verification

- `pnpm typecheck` — PASS
- `pnpm test` — PASS (all tests pass, 5 new tests added)
- `pnpm lint` — PASS
- Smoke: `npm run test:e2e` — PASS

Evidence: all commands run in this session; output confirms success.

### Important discoveries

- Existing movement records can be reused; full implementation possible.

### Decisions made

- DEC-<number>-01 — use debt fallback strategy

### Known issues

- None

### Remaining work

- Prepare for review
- Wait for approval to merge

### Exact next action

Reviewer: run full test suite and review diff against plan.

### Agent exit

- **Agent**: <model/role>
- **Time out**: <ISO timestamp>
- **Exit status**: VALIDATING
- **Branch**: `flow/<run>/001` or task branch name
- **HEAD commit**: `<sha>`

---

## Iteration 2

### Agent entry

- **Agent**: claude-3-5-opus (reviewer)
- **Time in**: <ISO timestamp>
- **Entry status**: VALIDATING
- **Task branch**: `flow/<run>/001`
- **Base commit (for review)**: `<original-base-sha>`
- **Task HEAD**: `<current-sha>`

### Work completed

- Reviewed full diff
- Ran full test suite
- Verified against plan
- Found one issue in error path

### Verification

- `pnpm test` — PASS (all 2,341 tests)
- Diff review — PASS (scope matches plan, no unexpected changes)
- Error handling — FAIL: missing try/catch at api.ts:145

### Issues found

- Error path not covered: what if index creation fails? Add try/catch.

### Decisions made

- None

### Remaining work

- Executor revises error handling
- Re-run tests
- Final approval

### Exact next action

Executor: add try/catch around index creation at api.ts:145, add test for error case.

### Agent exit

- **Agent**: claude-3-5-opus
- **Time out**: <ISO timestamp>
- **Exit status**: REVIEW (requires revision)
- **Branch**: `flow/<run>/001` (no changes by reviewer)
- **HEAD commit**: `<sha>` (same as entry)

---

## Iteration 3

### Agent entry

- **Agent**: claude-3-5-sonnet (revision)
- **Time in**: <ISO timestamp>
- **Entry status**: IMPLEMENTING
- **Task branch**: `flow/<run>/001`
- **Previous exit HEAD**: `<previous-sha>`

### Work completed

- Added try/catch for index creation
- Added test case for error scenario
- Verified all tests pass

### Files changed

- `src/orders/api.ts`
- `src/orders/api.test.ts`

### Commits

- `<sha>` — fix: add error handling for index creation
- `<sha>` — test: cover index creation error case

### Verification

- `pnpm test` — PASS (all 2,341 + 1 new test)
- `pnpm typecheck` — PASS
- `pnpm lint` — PASS

### Important discoveries

- None

### Decisions made

- None (revision only)

### Remaining work

- Final review and approval

### Exact next action

Reviewer: approve and merge.

### Agent exit

- **Agent**: claude-3-5-sonnet
- **Time out**: <ISO timestamp>
- **Exit status**: REVIEW (ready for final approval)
- **Branch**: `flow/<run>/001`
- **HEAD commit**: `<sha>`

---

## Iteration 4 (final approval)

### Agent entry

- **Agent**: reviewer (final)
- **Time in**: <ISO timestamp>
- **Entry status**: REVIEW

### Work completed

- Confirmed error handling is correct
- Verified all tests pass
- Approved for merge

### Verification

- `pnpm test` — PASS
- Diff against plan — PASS (scope OK, no unexpected changes)

### Decisions made

- None

### Exact next action

Merge `flow/<run>/001` into `flow/<run>/main`.

### Agent exit

- **Agent**: reviewer
- **Time out**: <ISO timestamp>
- **Exit status**: DONE
- **Branch**: `flow/<run>/001`
- **HEAD commit**: `<sha>`

---

## Final state

- **Status**: DONE
- **Total iterations**: 4
- **Total time**: ~2 hours
- **Merged**: yes, into `flow/<run>/main` via commit `<merge-sha>`
- **PR**: <URL or none>

*Do not redo:*
- Error handling — verified in tests
- Index creation — working as expected
```

---

## Notes

- Handoff is a proof artifact, not a chat log.
- Every iteration must have entry/exit timestamps so the next agent knows exactly where to pick up.
- Verification must have evidence: PASS/FAIL/NOT RUN, never guesses.
- Each iteration is independent; the next agent reads only the current and prior states.
- Do not duplicate the plan; reference the plan when relevant.
