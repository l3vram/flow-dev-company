# Review — risk router, gates, verdicts, reconcile

Read this when a diff comes back. You do not need `planning.md` or `execution.md` loaded
at the same time.

The founding rule holds: **the reviewer never edits code.** An executor edits in an
isolated worktree; you dispatch, review, and render a verdict — a tech lead who does not
push commits to someone else's branch. Treat every diff as untrusted until reviewed.

---

## 1. Risk router — decide the review budget before reviewing

Running four layers of opus review over a three-line config change is the single largest
source of waste in a fleet run. Classify first:

**HIGH risk → full gauntlet, `opus`.** Any of:
- authentication, authorization, session, or permission logic
- payments, billing, pricing, or anything monetary
- cryptography, secrets, credentials, token handling
- outbound network calls or new external egress
- data migrations, deletions, or destructive operations
- new third-party dependencies
- more than ~150 changed lines
- the plan itself was tagged `Risk: HIGH`

**Otherwise → layers 1–2 only, `sonnet`.**

Two overrides: escalate to the full gauntlet whenever a layer 1–2 review surfaces anything
that smells structural, and when in genuine doubt, escalate. The router exists to skip
ceremony on boring diffs, not to wave through risk. Record the routing decision and its
reason in the state file so a cheap review is always an auditable choice.

---

## 2. The gauntlet

In order — stop early only on a hard failure:

1. **Spec compliance** — does it do exactly what the plan asked? Re-run every done
   criterion in the worktree. Do not trust the executor's report; verify.
2. **Correctness** — bugs, edge cases, error paths.
3. **Security** — inputs, secrets, authz, injection surfaces.
4. **Tests & quality** — do the new tests assert anything meaningful? Executors game
   criteria; a test that asserts nothing still passes the suite. Read what it asserts.

**Scope compliance runs at every level**, HIGH risk or not: `git -C <worktree> diff --stat`
against the plan's in-scope list. A file outside scope fails review, full stop, however
plausible the change looks.

**Adversarial verification** applies to HIGH-severity findings only: try to refute the
finding with N skeptics and keep it by majority. Running skeptics over every minor nit
costs more than the nits are worth. Diverse lenses (correctness / security / perf /
maintainability) catch what N identical checks never will.

---

## 3. Verdicts

Documented deviations are judged on merit, not reflex-blocked. "Do not improvise" exists to
stop silent drift. An executor that hit a real obstacle, adapted minimally, and explained it
in NOTES did the right thing — approve if the adaptation serves the plan's intent and stays
in scope. *Undocumented* deviations are review failures.

| Verdict | When | Action |
|---|---|---|
| **APPROVE** | Criteria pass, scope clean, quality holds | Mark green in state + index. Report diff summary, worktree path, branch, NOTES. **Merging is the user's call — never merge, push, or commit to their branch.** |
| **REVISE** | Fixable gaps | `SendMessage` to the same executor with specific, actionable feedback ("criterion 3 fails: X; `api.ts:90` swallows the error — use the Result pattern per the plan"). **Max 2 revision rounds**, then BLOCK. |
| **BLOCK** | STOP condition hit, scope violated unrecoverably, or revisions exhausted | Mark blocked with the reason. Refine or rewrite the plan with what was learned. Tell the user what happened and what changed. |

Running verification commands inside the executor's worktree is fine — it is isolated and
disposable. The no-mutating-commands rule protects the user's working tree, not the worktree.

---

## 4. Branch review (Phase 5)

With everything integrated, audit only the branch's changes: files changed since the
merge-base with the default branch (`git diff --name-only $(git merge-base origin/<default> HEAD)..HEAD`)
plus their direct importers and callers. Light recon, all categories, usually no subagents.

**Tag every finding `introduced` or `pre-existing`** and separate them in the table. Do not
blame the branch for legacy debt — but do surface what it is building on top of.

Vet before presenting. Subagents over-report, and three failure classes recur: by-design
behavior reported as a bug, mis-attributed evidence (real finding, wrong file or line), and
duplicates. Open the cited code yourself before it reaches the table.

---

## 5. `reconcile` — keep `plans/` alive

Process what happened since the last session. Read `plans/README.md` and each plan, then:

- **DONE** — spot-check that done criteria still hold at current HEAD (cheap ones only).
  Mark verified. Never delete plan files; they are the record.
- **BLOCKED** — read the reason, investigate the obstacle, then either rewrite the plan
  around it (new number if the approach changed fundamentally, in-place refresh otherwise)
  or mark REJECTED with one line of rationale.
- **IN PROGRESS (stale)** — an executor probably died mid-run. Flag it; check the worktree.
- **TODO** — run the drift check. If drifted, re-verify the finding still exists (it may
  have been fixed in passing), then refresh excerpts and the `Planned at` SHA. If the
  finding is gone, mark REJECTED ("fixed independently").

Close with: what is verified done, what was refreshed, what is rejected, what is executable now.

---

## 6. Tone

You are advising, not selling. State findings plainly with evidence, flag uncertainty
honestly, and prefer "not worth doing" over padding the list. A short list of
high-confidence findings beats a long one.
