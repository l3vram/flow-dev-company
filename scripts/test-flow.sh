#!/usr/bin/env bash
# test-flow.sh — regression tests for flow.sh. Runs in a throwaway git repo; needs jq + git.
# Usage: scripts/test-flow.sh   (exit 0 = all pass)
set -uo pipefail

FLOW="$(cd "$(dirname "$0")" && pwd)/flow.sh"
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
cd "$TMP"
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t

pass=0; fail=0
ok()   { pass=$((pass+1)); }
bad()  { fail=$((fail+1)); echo "FAIL: $*"; }
# expect <exit-code> <description> -- <command...>
expect() {
  local want="$1" desc="$2"; shift 3
  "$@" >/dev/null 2>&1; local got=$?
  [ "$got" -eq "$want" ] && ok || bad "$desc (exit $got, want $want)"
}
eq() { [ "$1" = "$2" ] && ok || bad "$3 (got '$1', want '$2')"; }
st() { jq -r --arg id "$1" ".plans[] | select(.id==\$id) | .$2" .flow/state.json; }
fresh() { rm -rf .flow; "$FLOW" init "$1" "test" >/dev/null; }

# --- input validation -------------------------------------------------------
fresh v
expect 1 "bad tier rejected"          -- "$FLOW" add a dev gpt
"$FLOW" add a dev sonnet >/dev/null
expect 1 "duplicate id rejected"      -- "$FLOW" add a dev sonnet
expect 1 "unknown id on set rejected" -- "$FLOW" set nope green
expect 1 "status typo rejected"       -- "$FLOW" set a grene
expect 1 "unknown gate rejected"      -- "$FLOW" gate C approved
expect 1 "gate status typo rejected"  -- "$FLOW" gate A yes
expect 1 "unknown phase rejected"     -- "$FLOW" phase shipping
expect 0 "valid phase accepted"       -- "$FLOW" phase execute
eq "$(jq -r .phase .flow/state.json)" "execute" "phase persisted"
expect 1 "non-numeric budget rejected" -- "$FLOW" budget a lots opus plan

# --- dependency graph -------------------------------------------------------
fresh g
"$FLOW" add a dev sonnet zzz >/dev/null
expect 3 "unknown dependency detected" -- "$FLOW" waves

fresh c
"$FLOW" add a dev sonnet b >/dev/null; "$FLOW" add b dev sonnet a >/dev/null
expect 2 "cycle detected" -- "$FLOW" waves

fresh w
"$FLOW" add 001 data-dev haiku >/dev/null
"$FLOW" add 002 backend-dev sonnet 001 >/dev/null
"$FLOW" add 003 frontend-dev sonnet 001 >/dev/null
"$FLOW" add 004 qa sonnet 002,003 >/dev/null
"$FLOW" waves >/dev/null
eq "$(jq -c .waves .flow/state.json)" '[["001"],["002","003"],["004"]]' "Kahn layering"

# --- Gate A enforced in code ------------------------------------------------
expect 5 "ready refuses before Gate A" -- "$FLOW" ready
"$FLOW" gate A approved >/dev/null
eq "$(FLOW_STATE=.flow/state.json "$FLOW" ready)" "001" "ready after Gate A"

# --- circuit breaker: exactly 3 real attempts --------------------------------
for i in 1 2; do "$FLOW" set 001 running >/dev/null; "$FLOW" set 001 blocked x >/dev/null; "$FLOW" set 001 pending >/dev/null; done
"$FLOW" set 001 running >/dev/null
eq "$(st 001 status)" "running" "third attempt actually runs"
"$FLOW" set 001 blocked x >/dev/null
eq "$(st 001 attempts)" "3" "three attempts counted"
expect 4 "fourth dispatch refused" -- "$FLOW" set 001 running

# --- blocked plan does not deadlock the pipeline ----------------------------
expect 0 "skip-dependents" -- "$FLOW" skip-dependents 001
eq "$(st 002 status),$(st 003 status),$(st 004 status)" "skipped,skipped,skipped" "transitive skip"
expect 0 "wave 1 settled with blocked plan" -- "$FLOW" advance
expect 0 "wave 2 settled with skipped plans" -- "$FLOW" advance
expect 0 "wave 3 settled" -- "$FLOW" advance

# --- revisions: max 2 rounds, then blocked ----------------------------------
fresh r
"$FLOW" add a dev sonnet >/dev/null; "$FLOW" set a running >/dev/null
"$FLOW" revise a >/dev/null; "$FLOW" revise a >/dev/null
eq "$(st a status)" "running" "two revisions allowed"
"$FLOW" revise a >/dev/null
eq "$(st a status)" "blocked" "third revision blocks"
eq "$(st a attempts)" "1" "revisions are not attempts"

# --- budget: null is recorded as unreported, not counted --------------------
"$FLOW" budget a null sonnet execute >/dev/null
"$FLOW" budget a 1200 sonnet execute >/dev/null
eq "$(jq -c '[.budget.by_plan.a, .budget.unreported, .budget.spawns]' .flow/state.json)" \
   '[1200,["a/execute (spawn)"],2]' "ledger null handling"

# --- ledger: orchestrator's own work is not an agent spawn ------------------
fresh l
"$FLOW" add 156 dev sonnet >/dev/null
"$FLOW" budget 156 119530 sonnet execute >/dev/null
"$FLOW" budget 156 null opus review inline >/dev/null
eq "$(jq -c '[.budget.spawns, .budget.inline, .budget.by_plan."156"]' .flow/state.json)" \
   '[1,1,119530]' "one agent + one inline review = 1 spawn"
"$FLOW" report | grep -q "agents spawned: 1" && ok || bad "report shows 1 agent"
expect 1 "bad ledger kind rejected" -- "$FLOW" budget 156 10 opus review agent

# --- smoke result recorded, substitutes visible -----------------------------
expect 1 "smoke needs a detail"      -- "$FLOW" smoke substituted
expect 1 "bad smoke result rejected" -- "$FLOW" smoke skipped "x"
"$FLOW" smoke substituted "no Android SDK; ran ViewModel tests" >/dev/null
"$FLOW" panel 2>/dev/null | grep -q "smoke: substituted" && ok || bad "panel shows substituted smoke"

# --- panel works without `column` -------------------------------------------
mkdir -p nocol; for b in jq awk sed paste mktemp mv dirname cat; do ln -sf "$(command -v $b)" nocol/; done
out=$(PATH="$TMP/nocol" /bin/bash "$FLOW" panel 2>&1); rc=$?
[ $rc -eq 0 ] && echo "$out" | grep -q "PLAN" && ok || bad "panel without column (exit $rc): $out"

# --- integration: waves build on each other, conflicts are caught -----------
rm -rf .flow repo; mkdir repo; cd repo
git init -q -b main; echo base > base.txt; git add .; git commit -qm init
F="$FLOW"
"$F" init run1 "integration" >/dev/null
"$F" add 001 dev sonnet >/dev/null; "$F" add 002 dev sonnet >/dev/null; "$F" add 003 dev sonnet 001 >/dev/null
"$F" waves >/dev/null; "$F" gate A approved >/dev/null
expect 0 "integration-init" -- "$F" integration-init
INT=flow/run1/main
# Executors branch from the integration branch, as execution.md instructs.
for id in 001 002; do
  git branch -q "flow/run1/$id" "$INT"
  git worktree add -q "../wt-$id" "flow/run1/$id"
  echo "$id" > "../wt-$id/shared.txt"; echo "$id" > "../wt-$id/f$id.txt"
  git -C "../wt-$id" add .; git -C "../wt-$id" commit -qm "plan $id"
  "$F" set "$id" running >/dev/null; "$F" set "$id" green >/dev/null
done
expect 0 "integrate first plan"   -- "$F" integrate 001
expect 6 "conflict detected"      -- "$F" integrate 002
eq "$(st 002 status)" "review" "conflicting plan back to review"
expect 1 "barrier holds on unintegrated plan" -- "$F" advance
git -C ../wt-002 rm -q shared.txt; git -C ../wt-002 commit -qm "resolve"
git -C ../wt-002 merge -q --no-edit "$INT" >/dev/null 2>&1 || { git -C ../wt-002 checkout -q --theirs shared.txt 2>/dev/null; git -C ../wt-002 add -A; git -C ../wt-002 commit -qm merge; }
"$F" set 002 green >/dev/null
expect 0 "integrate after resolution" -- "$F" integrate 002
expect 0 "advance after integration"  -- "$F" advance
eq "$("$F" ready)" "003" "dependent ready only after dep integrated"
git branch -q flow/run1/003 "$INT"
git show flow/run1/003:f001.txt >/dev/null 2>&1 && ok || bad "wave 2 branch contains wave 1 code"
eq "$(cat base.txt)" "base" "user checkout untouched"
eq "$(git rev-parse --abbrev-ref HEAD)" "main" "user branch untouched"

cd "$TMP"; rm -rf empty; mkdir empty; cd empty; git init -q
"$FLOW" init g "greenfield" >/dev/null
expect 1 "integration-init refuses repo without commits" -- "$FLOW" integration-init

echo "flow.sh tests: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
