#!/usr/bin/env bash
# flow.sh — deterministic plumbing for flow-dev-company, served by the flow-harness engine
# (github.com/l3vram/flow-harness, Node >= 22). Same commands, messages and exit codes as the
# former jq script; run `flow.sh --help` for the full command list.
#
# Resolution order:
#   1. $FLOW_HARNESS_BIN            (a path to bin/flow-harness.mjs, or any executable)
#   2. flow-harness on PATH
#   3. npx -y -p github:l3vram/flow-harness#v0.36.0 flow-harness   (first run builds; needs network)
#
# Exit codes: 1 usage/validation, 2 cycle, 3 unknown dep, 4 circuit breaker, 5 Gate A not
# approved, 6 merge conflict, 7 shared task file, 8 out of scope, 127 engine not available.
# The previous implementation is scripts/flow-legacy.sh (deprecated, removed next release).
set -euo pipefail

FLOW_HARNESS_SPEC="github:l3vram/flow-harness#v0.36.0"

command -v node >/dev/null 2>&1 || {
  echo "flow.sh: node not found — the flow-harness engine needs Node >= 22 (deprecated fallback: scripts/flow-legacy.sh)" >&2
  exit 127
}
major=$(node -p 'process.versions.node.split(".")[0]')
[ "$major" -ge 22 ] || { echo "flow.sh: Node $major found — flow-harness needs Node >= 22" >&2; exit 127; }

if [ -n "${FLOW_HARNESS_BIN:-}" ]; then
  case "$FLOW_HARNESS_BIN" in
    *.mjs|*.js) exec node "$FLOW_HARNESS_BIN" "$@" ;;
    *)          exec "$FLOW_HARNESS_BIN" "$@" ;;
  esac
fi
if command -v flow-harness >/dev/null 2>&1; then exec flow-harness "$@"; fi
command -v npx >/dev/null 2>&1 || {
  echo "flow.sh: flow-harness not found and npx unavailable — install: npm i -g $FLOW_HARNESS_SPEC" >&2
  exit 127
}
exec npx -y -p "$FLOW_HARNESS_SPEC" flow-harness "$@"
