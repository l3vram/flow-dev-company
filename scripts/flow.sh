#!/usr/bin/env bash
# flow.sh — deterministic plumbing for flow-dev-company.
# Wave layering, state transitions, panel rendering and the budget ledger are arithmetic.
# Doing them here costs zero tokens; doing them in the model costs expensive output.
#
# Usage:
#   flow.sh init <run-id> <objective>     create .flow/state.json
#   flow.sh add <id> <role> <tier> [deps] register a plan (deps comma-separated)
#   flow.sh waves                         recompute wave layering (Kahn) into state
#   flow.sh set <id> <status> [reason]    pending|running|review|green|blocked
#   flow.sh ready                         plan ids dispatchable now (deps green, current wave)
#   flow.sh wave-done                     exit 0 if current wave fully green
#   flow.sh advance                       move to next wave (only if current is done)
#   flow.sh gate <A|B> <status>           record a human gate decision
#   flow.sh budget <id> <tokens> <tier> <phase>   append to the ledger
#   flow.sh panel                         render the fleet table
#   flow.sh report                        render the budget ledger
set -euo pipefail

STATE="${FLOW_STATE:-.flow/state.json}"

command -v jq >/dev/null 2>&1 || {
  echo "flow.sh: jq not found. Fall back to model-maintained state and tell the user." >&2
  exit 127
}

need_state() { [ -f "$STATE" ] || { echo "flow.sh: no $STATE — run 'flow.sh init' first" >&2; exit 1; }; }
write() { tmp=$(mktemp); jq "$@" "$STATE" > "$tmp" && mv "$tmp" "$STATE"; }

cmd_init() {
  mkdir -p "$(dirname "$STATE")"
  jq -n --arg run "$1" --arg obj "${2:-}" '{
    run: $run, objective: $obj, phase: "plan",
    gates: { A: "pending", B: "pending" },
    waves: [], current_wave: 0, plans: [],
    budget: { by_phase: {}, by_tier: {}, by_plan: {}, spawns: 0, notes: "" }
  }' > "$STATE"
  echo "init $STATE"
}

cmd_add() {
  need_state
  local id="$1" role="$2" tier="$3" deps="${4:-}"
  local deps_json="[]"
  [ -n "$deps" ] && deps_json=$(printf '%s' "$deps" | jq -R 'split(",") | map(select(length>0))')
  write --arg id "$id" --arg role "$role" --arg tier "$tier" --argjson deps "$deps_json" \
    '.plans += [{ id: $id, role: $role, tier: $tier, status: "pending",
                  attempts: 0, deps: $deps, worktree: ("wt-" + $id), review: null }]'
  echo "add $id ($role/$tier) deps=[${deps}]"
}

# Kahn layering: wave N = plans whose deps all live in earlier waves.
cmd_waves() {
  need_state
  write '
    def layer($remaining; $placed; $acc):
      if ($remaining | length) == 0 then $acc
      else
        ($remaining | map(select(all(.deps[]; . as $d | $placed | index($d)))) | map(.id)) as $ready
        | if ($ready | length) == 0
          then $acc + [$remaining | map(.id)]          # cycle: emit remainder, surface it upstream
          else layer($remaining | map(select(.id as $i | $ready | index($i) | not));
                     $placed + $ready; $acc + [$ready])
          end
      end;
    .waves = layer(.plans; []; [])
  '
  local n; n=$(jq '.waves | length' "$STATE")
  jq -r '.waves | to_entries[] | "wave \(.key+1): \(.value | join(", "))"' "$STATE"
  echo "($n waves)"
  # A cycle surfaces as a wave containing a plan that depends on a wave sibling.
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

cmd_set() {
  need_state
  local id="$1" status="$2" reason="${3:-}"
  write --arg id "$id" --arg s "$status" --arg r "$reason" '
    .plans |= map(
      if .id == $id then
        .status = $s
        | (if $s == "running" then .attempts += 1 else . end)
        | (if $r != "" then .reason = $r else . end)
      else . end)'
  # Circuit breaker: three attempts is the ceiling. Blind retries burn budget.
  local att; att=$(jq -r --arg id "$id" '.plans[] | select(.id==$id) | .attempts' "$STATE")
  if [ "$att" -ge 3 ] && [ "$status" != "green" ]; then
    write --arg id "$id" '.plans |= map(if .id==$id then .status="blocked" | .reason=((.reason // "") + " [circuit breaker: 3 attempts]") else . end)'
    echo "set $id -> blocked (CIRCUIT BREAKER at $att attempts — escalate to human gate)"
    return 0
  fi
  echo "set $id -> $status${reason:+ ($reason)}"
}

cmd_ready() {
  need_state
  jq -r '
    (.waves[.current_wave] // []) as $w
    | [.plans[] | select(.status == "green") | .id] as $green
    | .plans[]
    | select(.id as $i | $w | index($i))
    | select(.status == "pending")
    | select(all(.deps[]; . as $d | $green | index($d)))
    | .id' "$STATE"
}

cmd_wave_done() {
  need_state
  jq -e '
    (.waves[.current_wave] // []) as $w
    | [.plans[] | select(.id as $i | $w | index($i))]
    | all(.[]; .status == "green" or .status == "blocked")' "$STATE" >/dev/null
}

cmd_advance() {
  need_state
  if cmd_wave_done; then
    write '.current_wave += 1'
    echo "advanced to wave $(( $(jq '.current_wave' "$STATE") + 1 ))/$(jq '.waves | length' "$STATE")"
  else
    echo "barrier: current wave not complete — not advancing" >&2; exit 1
  fi
}

cmd_gate() { need_state; write --arg g "$1" --arg s "$2" '.gates[$g] = $s'; echo "gate $1 -> $2"; }

cmd_budget() {
  need_state
  local id="$1" tok="$2" tier="$3" phase="$4"
  write --arg id "$id" --argjson t "$tok" --arg tier "$tier" --arg ph "$phase" '
    .budget.by_plan[$id]  = ((.budget.by_plan[$id]  // 0) + $t)
    | .budget.by_tier[$tier] = ((.budget.by_tier[$tier] // 0) + $t)
    | .budget.by_phase[$ph]  = ((.budget.by_phase[$ph]  // 0) + $t)
    | .budget.spawns += 1'
  echo "budget +$tok ($tier/$phase) -> $id"
}

cmd_panel() {
  need_state
  # Header and footer bypass `column` — mixing them into the table skews its widths.
  jq -r '"FLEET | phase: \(.phase) | wave \(.current_wave + 1)/\(.waves | length) | gates A:\(.gates.A) B:\(.gates.B)"' "$STATE"
  echo
  jq -r '
    def icon: if . == "green" then "green" elif . == "running" then "running"
              elif . == "review" then "review" elif . == "blocked" then "BLOCKED"
              else "waiting" end;
    (["PLAN","ROLE","TIER","STATUS","TRY","DEPS"] | @tsv),
    (.plans[] | [.id, .role, .tier, (.status | icon), (.attempts|tostring),
                 (if (.deps|length)==0 then "-" else (.deps|join(",")) end)] | @tsv)
  ' "$STATE" | column -t -s "$(printf '\t')"
  echo
  jq -r '"wave \(.current_wave + 1) members: \((.waves[.current_wave] // []) | join(", "))",
         "objective: \(.objective // "-")"' "$STATE"
}

cmd_report() {
  need_state
  jq -r '
    "TOKEN LEDGER — run \(.run)", "",
    "by phase:", (.budget.by_phase | to_entries[] | "  \(.key): \(.value)"),
    "by tier:",  (.budget.by_tier  | to_entries[] | "  \(.key): \(.value)"),
    "by plan:",  (.budget.by_plan  | to_entries[] | "  \(.key): \(.value)"),
    "", "spawns: \(.budget.spawns)",
    (if (.budget.notes // "") != "" then "notes: \(.budget.notes)" else empty end),
    "", "(null or missing = harness did not report it. Never substitute an estimate.)"
  ' "$STATE"
}

case "${1:-}" in
  init)      shift; cmd_init "$@" ;;
  add)       shift; cmd_add "$@" ;;
  waves)     cmd_waves ;;
  set)       shift; cmd_set "$@" ;;
  ready)     cmd_ready ;;
  wave-done) cmd_wave_done && echo "wave complete" || { echo "wave in progress"; exit 1; } ;;
  advance)   cmd_advance ;;
  gate)      shift; cmd_gate "$@" ;;
  budget)    shift; cmd_budget "$@" ;;
  panel)     cmd_panel ;;
  report)    cmd_report ;;
  *) sed -n '2,20p' "$0" >&2; exit 1 ;;
esac
