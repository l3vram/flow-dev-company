#!/usr/bin/env bash
# flow.sh — deterministic plumbing for flow-dev-company.
# Wave layering, state transitions, integration, panel rendering and the budget ledger are
# arithmetic. Doing them here costs zero tokens; doing them in the model costs expensive output.
#
# Usage:
#   flow.sh init <run-id> <objective>       create .flow/state.json
#   flow.sh phase <name>                    enrich|plan|execute|verify|review|handoff
#   flow.sh add <id> <role> <tier> [deps]   register a plan (deps comma-separated)
#   flow.sh waves                           Kahn layering; exit 2 on cycle, 3 on unknown dep
#   flow.sh gate <A|B> <status>             pending|approved|rejected
#   flow.sh integration-init [base]         create integration branch + worktree .flow/integration
#   flow.sh ready                           plan ids dispatchable now (Gate A approved, deps green)
#   flow.sh set <id> <status> [reason]      pending|running|review|green|blocked|skipped
#   flow.sh revise <id>                     count a REVISE round; 3rd round blocks the plan
#   flow.sh integrate <id>                  merge the plan's branch into the integration branch
#   flow.sh skip-dependents <id>            mark every transitive dependent of <id> skipped
#   flow.sh wave-done                       exit 0 if every plan in the current wave is settled
#   flow.sh advance                         move to next wave (only if current is settled)
#   flow.sh smoke <pass|fail|substituted> <detail>     record the Phase 4 smoke result
#   flow.sh budget <id> <tokens|null> <tier> <phase> [spawn|inline]
#                                           append to the ledger; only `spawn` counts as an agent
#   flow.sh panel                           render the fleet table
#   flow.sh report                          render the budget ledger
#
# Branches: integration = flow/<run>/main, plan = flow/<run>/<id>.
set -euo pipefail

STATE="${FLOW_STATE:-.flow/state.json}"
MAX_ATTEMPTS=3   # fresh dispatches per plan
MAX_REVISIONS=2  # REVISE rounds per attempt

STATUSES="pending running review green blocked skipped"
PHASES="enrich plan execute verify review handoff"
GATE_STATUSES="pending approved rejected"
TIERS="opus sonnet haiku"

command -v jq >/dev/null 2>&1 || {
  echo "flow.sh: jq not found. Fall back to model-maintained state and tell the user." >&2
  exit 127
}

die() { echo "flow.sh: $*" >&2; exit "${EXIT:-1}"; }
one_of() { local v="$1"; shift; for x in "$@"; do [ "$v" = "$x" ] && return 0; done; return 1; }
need_state() { [ -f "$STATE" ] || die "no $STATE — run 'flow.sh init' first"; }
# Temp file next to the state so the mv is an atomic rename on the same filesystem.
write() { local tmp; tmp=$(mktemp "$STATE.XXXXXX"); jq "$@" "$STATE" > "$tmp" && mv "$tmp" "$STATE"; }
has_plan() { jq -e --arg id "$1" 'any(.plans[]; .id == $id)' "$STATE" >/dev/null; }
need_plan() { has_plan "$1" || die "unknown plan id '$1'"; }
field() { jq -r --arg id "$1" ".plans[] | select(.id==\$id) | .$2" "$STATE"; }
run_id() { jq -r '.run' "$STATE"; }

cmd_init() {
  [ $# -ge 1 ] || die "usage: init <run-id> <objective>"
  [[ "$1" =~ ^[A-Za-z0-9._-]+$ ]] || die "run-id must match [A-Za-z0-9._-]+ (it becomes a branch name)"
  mkdir -p "$(dirname "$STATE")"
  jq -n --arg run "$1" --arg obj "${2:-}" '{
    run: $run, objective: $obj, phase: "enrich",
    gates: { A: "pending", B: "pending" },
    integration: { branch: ("flow/" + $run + "/main"), base: null, worktree: null },
    waves: [], current_wave: 0, plans: [],
    smoke: null,
    budget: { by_phase: {}, by_tier: {}, by_plan: {}, spawns: 0, inline: 0, unreported: [], notes: "" }
  }' > "$STATE"
  echo "init $STATE"
}

cmd_phase() {
  need_state
  one_of "${1:-}" $PHASES || die "phase must be one of: $PHASES"
  write --arg p "$1" '.phase = $p'; echo "phase -> $1"
}

cmd_add() {
  need_state
  [ $# -ge 3 ] || die "usage: add <id> <role> <tier> [deps]"
  local id="$1" role="$2" tier="$3" deps="${4:-}"
  [[ "$id" =~ ^[A-Za-z0-9._-]+$ ]] || die "plan id must match [A-Za-z0-9._-]+"
  one_of "$tier" $TIERS || die "tier must be one of: $TIERS"
  has_plan "$id" && die "plan '$id' already registered"
  local deps_json="[]"
  [ -n "$deps" ] && deps_json=$(printf '%s' "$deps" | jq -R 'split(",") | map(select(length>0))')
  local run; run=$(run_id)
  write --arg id "$id" --arg role "$role" --arg tier "$tier" --argjson deps "$deps_json" \
        --arg br "flow/$run/$id" \
    '.plans += [{ id: $id, role: $role, tier: $tier, status: "pending",
                  attempts: 0, revisions: 0, deps: $deps, branch: $br,
                  integrated: false, review: null }]'
  echo "add $id ($role/$tier) deps=[${deps}]"
}

# Kahn layering: wave N = plans whose deps all live in earlier waves.
cmd_waves() {
  need_state
  local unknown
  unknown=$(jq -r '[.plans[].id] as $ids
                   | [.plans[] | .id as $p | .deps[] | select(. as $d | $ids | index($d) | not)
                      | "\($p)->\(.)"] | join(", ")' "$STATE")
  [ -z "$unknown" ] || EXIT=3 die "unknown dependency: $unknown — fix plans/README.md before dispatching"
  write '
    def layer($remaining; $placed; $acc):
      if ($remaining | length) == 0 then $acc
      else
        ($remaining | map(select(all(.deps[]; . as $d | $placed | index($d)))) | map(.id)) as $ready
        | if ($ready | length) == 0
          then $acc + [$remaining | map(.id)]          # cycle: emit remainder, surface it below
          else layer($remaining | map(select(.id as $i | $ready | index($i) | not));
                     $placed + $ready; $acc + [$ready])
          end
      end;
    .waves = layer(.plans; []; []) | .current_wave = 0
  '
  jq -r '.waves | to_entries[] | "wave \(.key+1): \(.value | join(", "))"' "$STATE"
  echo "($(jq '.waves | length' "$STATE") waves)"
  local cyc
  cyc=$(jq -r '[.waves[] as $w | .plans[]
                | select(.id as $i | $w | index($i))
                | select(any(.deps[]; . as $d | $w | index($d)))
                | .id] | unique | join(", ")' "$STATE")
  if [ -n "$cyc" ]; then
    echo "CYCLE in dependency graph involving: $cyc" >&2
    echo "Fix plans/README.md before dispatching — these plans cannot be ordered." >&2
    return 2
  fi
}

cmd_gate() {
  need_state
  one_of "${1:-}" A B || die "gate must be A or B"
  one_of "${2:-}" $GATE_STATUSES || die "gate status must be one of: $GATE_STATUSES"
  write --arg g "$1" --arg s "$2" '.gates[$g] = $s'; echo "gate $1 -> $2"
}

# The integration branch is where approved plans accumulate. It lives in its own worktree so
# the user's checkout is never touched, and every later wave branches from it.
cmd_integration_init() {
  need_state
  git rev-parse --verify -q HEAD >/dev/null \
    || die "not a git repository with at least one commit — greenfield: git init && commit plans/ first"
  local base="${1:-$(git rev-parse --abbrev-ref HEAD)}" br wt
  br=$(jq -r '.integration.branch' "$STATE")
  wt="$(dirname "$STATE")/integration"
  if [ -d "$wt" ]; then echo "integration worktree exists: $wt ($br)"; return 0; fi
  if git rev-parse --verify -q "refs/heads/$br" >/dev/null; then
    git worktree add -q "$wt" "$br"
  else
    git worktree add -q -b "$br" "$wt" "$base"
  fi
  write --arg b "$base" --arg w "$wt" '.integration.base = $b | .integration.worktree = $w'
  echo "integration $br at $wt (from $base)"
}

cmd_ready() {
  need_state
  [ "$(jq -r '.gates.A' "$STATE")" = "approved" ] \
    || EXIT=5 die "Gate A is not approved — no plan is dispatchable"
  jq -r '
    (.waves[.current_wave] // []) as $w
    | [.plans[] | select(.status == "green" and .integrated) | .id] as $done
    | .plans[]
    | select(.id as $i | $w | index($i))
    | select(.status == "pending")
    | select(all(.deps[]; . as $d | $done | index($d)))
    | .id' "$STATE"
}

cmd_set() {
  need_state
  [ $# -ge 2 ] || die "usage: set <id> <status> [reason]"
  local id="$1" status="$2" reason="${3:-}"
  need_plan "$id"
  one_of "$status" $STATUSES || die "status must be one of: $STATUSES"
  local att; att=$(field "$id" attempts)
  if [ "$status" = "running" ] && [ "$att" -ge "$MAX_ATTEMPTS" ]; then
    EXIT=4 die "plan $id already used $att/$MAX_ATTEMPTS attempts — circuit breaker, escalate to a human gate"
  fi
  write --arg id "$id" --arg s "$status" --arg r "$reason" '
    .plans |= map(
      if .id == $id then
        .status = $s
        | (if $s == "running" then .attempts += 1 | .revisions = 0 else . end)
        | (if $r != "" then .reason = $r else . end)
      else . end)'
  att=$(field "$id" attempts)
  if [ "$status" = "blocked" ] && [ "$att" -ge "$MAX_ATTEMPTS" ]; then
    write --arg id "$id" '.plans |= map(if .id==$id then .reason=((.reason // "") + " [circuit breaker]") else . end)'
    echo "set $id -> blocked (CIRCUIT BREAKER after $att attempts — escalate to human gate, then skip-dependents or rewrite the plan)"
    return 0
  fi
  if [ "$status" = "blocked" ]; then
    echo "set $id -> blocked${reason:+ ($reason)} — attempt $att/$MAX_ATTEMPTS; requeue with 'set $id pending'"
    return 0
  fi
  echo "set $id -> $status${reason:+ ($reason)}"
}

cmd_revise() {
  need_state
  local id="${1:-}"; need_plan "$id"
  write --arg id "$id" '.plans |= map(if .id==$id then .revisions += 1 else . end)'
  local rev; rev=$(field "$id" revisions)
  if [ "$rev" -gt "$MAX_REVISIONS" ]; then
    cmd_set "$id" blocked "revisions exhausted"
  else
    write --arg id "$id" '.plans |= map(if .id==$id then .status = "running" else . end)'
    echo "revise $id -> round $rev/$MAX_REVISIONS"
  fi
}

cmd_integrate() {
  need_state
  local id="${1:-}"; need_plan "$id"
  [ "$(field "$id" status)" = "green" ] || die "plan $id is not green — review must APPROVE before integration"
  local wt br
  wt=$(jq -r '.integration.worktree // empty' "$STATE")
  [ -n "$wt" ] && [ -d "$wt" ] || die "no integration worktree — run 'flow.sh integration-init'"
  br=$(field "$id" branch)
  git rev-parse --verify -q "refs/heads/$br" >/dev/null || die "branch $br not found — executor must commit on it"
  if git -C "$wt" merge --no-ff --no-edit -m "flow: integrate plan $id" "$br" >/dev/null 2>&1; then
    write --arg id "$id" '.plans |= map(if .id==$id then .integrated = true else . end)'
    echo "integrate $id -> $(jq -r '.integration.branch' "$STATE")"
  else
    local files; files=$(git -C "$wt" diff --name-only --diff-filter=U | paste -sd, -)
    git -C "$wt" merge --abort
    write --arg id "$id" --arg f "$files" \
      '.plans |= map(if .id==$id then .status = "review" | .reason = ("merge conflict: " + $f) else . end)'
    EXIT=6 die "merge conflict integrating $id ($files) — plan back to review; rebase its branch on the integration branch"
  fi
}

cmd_skip_dependents() {
  need_state
  local id="${1:-}"; need_plan "$id"
  local skipped
  skipped=$(jq -r --arg id "$id" '
    def closure($set):
      ([.plans[] | select(any(.deps[]; . as $d | $set | index($d))) | .id] + $set | unique) as $n
      | if ($n | length) == ($set | length) then $set else closure($n) end;
    closure([$id]) - [$id] | join(" ")' "$STATE")
  [ -n "$skipped" ] || { echo "no dependents of $id"; return 0; }
  write --arg id "$id" --arg s "$skipped" '
    ($s | split(" ")) as $ids
    | .plans |= map(if (.id as $i | $ids | index($i)) and .status != "green"
                    then .status = "skipped" | .reason = ("dependency " + $id + " blocked") else . end)'
  echo "skipped (dependency $id blocked): $skipped"
}

cmd_wave_done() {
  need_state
  jq -e '
    (.waves[.current_wave] // []) as $w
    | [.plans[] | select(.id as $i | $w | index($i))]
    | all(.[]; (.status == "green" and .integrated) or .status == "blocked" or .status == "skipped")' \
    "$STATE" >/dev/null
}

cmd_advance() {
  need_state
  if cmd_wave_done; then
    write '.current_wave += 1'
    local cur tot; cur=$(jq '.current_wave' "$STATE"); tot=$(jq '.waves | length' "$STATE")
    if [ "$cur" -ge "$tot" ]; then echo "all $tot waves settled"; else echo "advanced to wave $((cur + 1))/$tot"; fi
  else
    die "barrier: current wave not settled (every plan must be green+integrated, blocked, or skipped)"
  fi
}

# A ledger line is either a dispatched agent (`spawn`, the default) or work the orchestrator
# did in its own context (`inline`, e.g. its own review). Only spawns count as agents.
cmd_budget() {
  need_state
  [ $# -ge 4 ] || die "usage: budget <id> <tokens|null> <tier> <phase> [spawn|inline]"
  local id="$1" tok="$2" tier="$3" phase="$4" kind="${5:-spawn}"
  one_of "$kind" spawn inline || die "kind must be spawn or inline"
  local counter=".budget.spawns"; [ "$kind" = "inline" ] && counter=".budget.inline"
  if [ "$tok" = "null" ] || [ -z "$tok" ]; then
    write --arg e "$id/$phase ($kind)" ".budget.unreported += [\$e] | $counter = (($counter // 0) + 1)"
    echo "budget: $id/$phase ($kind) unreported by harness (recorded, not estimated)"
    return 0
  fi
  [[ "$tok" =~ ^[0-9]+$ ]] || die "tokens must be a non-negative integer or 'null'"
  write --arg id "$id" --argjson t "$tok" --arg tier "$tier" --arg ph "$phase" "
    .budget.by_plan[\$id]  = ((.budget.by_plan[\$id]  // 0) + \$t)
    | .budget.by_tier[\$tier] = ((.budget.by_tier[\$tier] // 0) + \$t)
    | .budget.by_phase[\$ph]  = ((.budget.by_phase[\$ph]  // 0) + \$t)
    | $counter = (($counter // 0) + 1)"
  echo "budget +$tok ($tier/$phase, $kind) -> $id"
}

# Phase 4's smoke result. `substituted` = the product could not be started here (no SDK,
# device, or credentials) and a lower layer was exercised instead — Gate B must show it.
cmd_smoke() {
  need_state
  one_of "${1:-}" pass fail substituted || die "smoke result must be pass, fail or substituted"
  [ -n "${2:-}" ] || die "smoke needs a detail: the command run, or for 'substituted' why and what ran instead"
  write --arg r "$1" --arg d "$2" '.smoke = { result: $r, detail: $d }'
  echo "smoke -> $1 ($2)"
}

# `column` is not installed everywhere; fall back to fixed-width printf.
table() {
  if command -v column >/dev/null 2>&1; then column -t -s "$(printf '\t')"
  else awk -F'\t' '{ printf "%-8s %-14s %-7s %-9s %-4s %-4s %s\n", $1, $2, $3, $4, $5, $6, $7 }'
  fi
}

cmd_panel() {
  need_state
  # Header and footer bypass the table — mixing them in skews its widths.
  jq -r '"FLEET | phase: \(.phase) | wave \([.current_wave + 1, (.waves | length)] | min)/\(.waves | length) | gates A:\(.gates.A) B:\(.gates.B)"' "$STATE"
  echo
  jq -r '
    def shown: if . == "blocked" then "BLOCKED" elif . == "pending" then "waiting" else . end;
    (["PLAN","ROLE","TIER","STATUS","TRY","INT","DEPS"] | @tsv),
    (.plans[] | [.id, .role, .tier, (.status | shown), (.attempts|tostring),
                 (if .integrated then "yes" else "-" end),
                 (if (.deps|length)==0 then "-" else (.deps|join(",")) end)] | @tsv)
  ' "$STATE" | table
  echo
  jq -r '"wave \(.current_wave + 1) members: \((.waves[.current_wave] // []) | join(", "))",
         "integration: \(.integration.branch)",
         (if .smoke then "smoke: \(.smoke.result) — \(.smoke.detail)" else empty end),
         "objective: \(.objective // "-")",
         (.plans[] | select(.reason != null and (.status == "blocked" or .status == "skipped" or .status == "review"))
          | "  \(.id): \(.reason)")' "$STATE"
}

cmd_report() {
  need_state
  jq -r '
    "TOKEN LEDGER — run \(.run)", "",
    "by phase:", (.budget.by_phase | to_entries[] | "  \(.key): \(.value)"),
    "by tier:",  (.budget.by_tier  | to_entries[] | "  \(.key): \(.value)"),
    "by plan:",  (.budget.by_plan  | to_entries[] | "  \(.key): \(.value)"),
    "", "agents spawned: \(.budget.spawns)   inline entries: \(.budget.inline // 0)",
    (if (.budget.unreported // []) | length > 0
     then "unreported by harness: \(.budget.unreported | join(", "))" else empty end),
    (if (.budget.notes // "") != "" then "notes: \(.budget.notes)" else empty end),
    (if .smoke then "smoke: \(.smoke.result) — \(.smoke.detail)" else empty end),
    "", "(Unreported entries are listed, never estimated.)"
  ' "$STATE"
}

case "${1:-}" in
  init)             shift; cmd_init "$@" ;;
  phase)            shift; cmd_phase "$@" ;;
  add)              shift; cmd_add "$@" ;;
  waves)            cmd_waves ;;
  gate)             shift; cmd_gate "$@" ;;
  integration-init) shift; cmd_integration_init "$@" ;;
  ready)            cmd_ready ;;
  set)              shift; cmd_set "$@" ;;
  revise)           shift; cmd_revise "$@" ;;
  integrate)        shift; cmd_integrate "$@" ;;
  skip-dependents)  shift; cmd_skip_dependents "$@" ;;
  wave-done)        cmd_wave_done && echo "wave settled" || { echo "wave in progress"; exit 1; } ;;
  advance)          cmd_advance ;;
  budget)           shift; cmd_budget "$@" ;;
  smoke)            shift; cmd_smoke "$@" ;;
  panel)            cmd_panel ;;
  report)           cmd_report ;;
  *) sed -n '2,27p' "$0" >&2; exit 1 ;;
esac
