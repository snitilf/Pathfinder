#!/usr/bin/env sh
# fixture tests for scripts/pathfinder-stats.sh (Change B).
# builds temp log dirs + temp agent frontmatter, runs the script with
# PATHFINDER_LOG_DIR / PATHFINDER_AGENTS_DIR, and asserts on the output.
# usage: sh test-stats.sh   (run from anywhere; set REPO if not autodetected)

set -u

REPO="${REPO:-/Users/snitil/Documents/GitHub/pathfinder}"
STATS="$REPO/scripts/pathfinder-stats.sh"
WORK="$(mktemp -d)"
PASS=0; FAIL=0
trap 'rm -rf "$WORK"' EXIT

ok()   { PASS=$((PASS+1)); printf 'PASS: %s\n' "$1"; }
bad()  { FAIL=$((FAIL+1)); printf 'FAIL: %s\n' "$1"; }

# assert that $2 (a file of captured output) contains regex $1
has() { if grep -Eq "$1" "$2"; then ok "$3"; else bad "$3 [missing /$1/]"; fi; }
hasnt() { if grep -Eq "$1" "$2"; then bad "$3 [unexpected /$1/]"; else ok "$3"; fi; }

# ---- shared fixture agents dir (real pins) ----
AG="$WORK/agents"; mkdir -p "$AG"
mkpin() { printf -- '---\nname: %s\nmodel: %s\neffort: low\n---\nbody\n' "$1" "$2" > "$AG/$1.md"; }
mkpin scout haiku
mkpin Explore haiku
mkpin mech-executor sonnet
mkpin light-verifier sonnet
mkpin executor opus
mkpin verifier opus
mkpin security-executor opus

STOP='"event":"SubagentStop"'

# ============================================================
echo "== fixture 1: alias mapping (scout on concrete haiku id => COMPLIANT) =="
L1="$WORK/l1"; mkdir -p "$L1"
{
  printf '{"ts":"2026-07-19T00:00:00Z",%s,"session_id":"s","agent_type":"scout","agent_id":"a1","reason":null,"models":["claude-haiku-4-5-20251001"],"output_tokens":100,"input_tokens":10,"cache_read_tokens":20,"cache_creation_tokens":5}\n' "$STOP"
} > "$L1/2026-07-19.jsonl"
O1="$WORK/o1"; PATHFINDER_LOG_DIR="$L1" PATHFINDER_AGENTS_DIR="$AG" sh "$STATS" > "$O1" 2>&1
has 'scout .*pin=haiku' "$O1" "scout pin read as haiku from frontmatter"
has 'compliant=1 / 1' "$O1" "scout haiku-id counts as compliant (alias-to-family, not string eq)"
has 'claude-haiku-4-5-20251001 +x1 \(matches pin\)' "$O1" "observed concrete id labeled matches pin"

# ============================================================
echo "== fixture 2: schema detection (old six-field vs new models:null => different buckets) =="
L2="$WORK/l2"; mkdir -p "$L2"
{
  # old pre-v1.2.0 line: no models key at all
  printf '{"ts":"2026-07-19T00:00:00Z",%s,"session_id":"s","agent_type":"executor","agent_id":"old","reason":null}\n' "$STOP"
  # new v1.2.0 line whose transcript was missing: has the key, value null
  printf '{"ts":"2026-07-19T00:01:00Z",%s,"session_id":"s","agent_type":"executor","agent_id":"new","reason":null,"models":null,"output_tokens":null,"input_tokens":null,"cache_read_tokens":null,"cache_creation_tokens":null}\n' "$STOP"
} > "$L2/2026-07-19.jsonl"
O2="$WORK/o2"; PATHFINDER_LOG_DIR="$L2" PATHFINDER_AGENTS_DIR="$AG" sh "$STATS" > "$O2" 2>&1
has 'schema v1 .*: 1 ' "$O2" "old line lands in schema v1 (count 1)"
has 'schema v2, models null .*: 1 ' "$O2" "new models:null line lands in v2null (count 1), NOT v1"
has 'schema v2, models present .*: 0 ' "$O2" "no v2present in this fixture"

# ============================================================
echo "== fixture 3: unattributed bucket visible and excluded from denominators =="
L3="$WORK/l3"; mkdir -p "$L3"
{
  # 3 unattributed empty-agent_type stops (v1)
  printf '{"ts":"2026-07-19T00:00:00Z",%s,"session_id":"s","agent_type":"","agent_id":"e1","reason":null}\n' "$STOP"
  printf '{"ts":"2026-07-19T00:00:01Z",%s,"session_id":"s","agent_type":"","agent_id":"e2","reason":null}\n' "$STOP"
  printf '{"ts":"2026-07-19T00:00:02Z",%s,"session_id":"s","agent_type":"","agent_id":"e3","reason":null,"models":null,"output_tokens":null,"input_tokens":null,"cache_read_tokens":null,"cache_creation_tokens":null}\n' "$STOP"
  # 1 attributed scout with model data
  printf '{"ts":"2026-07-19T00:00:03Z",%s,"session_id":"s","agent_type":"scout","agent_id":"a1","reason":null,"models":["claude-haiku-4-5-20251001"],"output_tokens":10,"input_tokens":1,"cache_read_tokens":1,"cache_creation_tokens":1}\n' "$STOP"
} > "$L3/2026-07-19.jsonl"
O3="$WORK/o3"; PATHFINDER_LOG_DIR="$L3" PATHFINDER_AGENTS_DIR="$AG" sh "$STATS" > "$O3" 2>&1
has 'unattributed: no agent_type from the hook, no transcript' "$O3" "unattributed bucket named honestly"
has '3 of 4 SubagentStop \(75.0%\)' "$O3" "unattributed share computed at run time (3/4=75%)"
# compliance denominator for scout is over its own 1 line, not shrunk/inflated by unattributed
has 'compliant=1 / 1' "$O3" "scout compliance denominator is its 1 line, unattributed excluded"

# ============================================================
echo "== fixture 4: realistic mixed schema (routing + compliance + ungoverned) =="
L4="$WORK/l4"; mkdir -p "$L4"
{
  # compliant pinned roles
  printf '{"ts":"2026-07-19T00:00:00Z",%s,"session_id":"s","agent_type":"scout","agent_id":"a1","reason":null,"models":["claude-haiku-4-5-20251001"],"output_tokens":100,"input_tokens":10,"cache_read_tokens":200,"cache_creation_tokens":5}\n' "$STOP"
  printf '{"ts":"2026-07-19T00:00:01Z",%s,"session_id":"s","agent_type":"executor","agent_id":"a2","reason":null,"models":["claude-opus-4-8"],"output_tokens":500,"input_tokens":80,"cache_read_tokens":130000,"cache_creation_tokens":21000}\n' "$STOP"
  # off-pin: executor observed on sonnet
  printf '{"ts":"2026-07-19T00:00:02Z",%s,"session_id":"s","agent_type":"executor","agent_id":"a3","reason":null,"models":["claude-sonnet-5"],"output_tokens":50,"input_tokens":5,"cache_read_tokens":10,"cache_creation_tokens":2}\n' "$STOP"
  # legacy scout line (no model data)
  printf '{"ts":"2026-07-19T00:00:03Z",%s,"session_id":"s","agent_type":"scout","agent_id":"a4","reason":null}\n' "$STOP"
  # ungoverned: workflow-subagent on opus, general-purpose multi-model
  printf '{"ts":"2026-07-19T00:00:04Z",%s,"session_id":"s","agent_type":"workflow-subagent","agent_id":"a5","reason":null,"models":["claude-opus-4-8"],"output_tokens":238,"input_tokens":20,"cache_read_tokens":300,"cache_creation_tokens":10}\n' "$STOP"
  printf '{"ts":"2026-07-19T00:00:05Z",%s,"session_id":"s","agent_type":"general-purpose","agent_id":"a6","reason":null,"models":["claude-fable-5","claude-opus-4-8"],"output_tokens":70,"input_tokens":7,"cache_read_tokens":9,"cache_creation_tokens":1}\n' "$STOP"
  # unattributed
  printf '{"ts":"2026-07-19T00:00:06Z",%s,"session_id":"s","agent_type":"","agent_id":"a7","reason":null}\n' "$STOP"
} > "$L4/2026-07-19.jsonl"
O4="$WORK/o4"; PATHFINDER_LOG_DIR="$L4" PATHFINDER_AGENTS_DIR="$AG" sh "$STATS" > "$O4" 2>&1
has 'routing table' "$O4" "routing table renders"
has 'claude-opus-4-8 +calls=1 out=500 in=80 cache_read=130000 cache_creation=21000' "$O4" "routing tokens per field for executor/opus"
has 'executor +pin=opus' "$O4" "executor pin=opus"
has 'compliant=1 / 2 with model data \(50.0%\), off-pin=1' "$O4" "executor: 1 of 2 compliant, 1 off-pin (sonnet)"
has 'claude-sonnet-5 +x1 \(OFF-PIN\)' "$O4" "off-pin sonnet flagged for executor"
has 'scout .*pin=haiku' "$O4" "scout pin haiku"
has 'no model data' "$O4" "scout legacy line surfaced as no-model-data"
has 'ungoverned delegation' "$O4" "ungoverned section renders"
has 'workflow-subagent: calls=1' "$O4" "workflow-subagent reported as ungoverned"
has 'general-purpose: calls=1' "$O4" "general-purpose reported as ungoverned"
has 'claude-fable-5\+claude-opus-4-8' "$O4" "multi-model set shown for general-purpose"
has 'distinguishable from telemetry' "$O4" "inheritance disclaimer present, no accusation"
hasnt 'workflow-subagent.*OFF-PIN' "$O4" "ungoverned types are not accused of pin violations"

# ============================================================
echo "== fixture 5: jq absent (graceful, raw count, exit 0) =="
O5="$WORK/o5"
FAKEBIN="$WORK/nojq"; mkdir -p "$FAKEBIN"
# build a PATH that has coreutils but not jq: symlink common tools, omit jq
for t in sh cat ls wc tr awk sed grep mktemp printf rm find sort uniq stat; do
  p="$(command -v "$t" 2>/dev/null || true)"; [ -n "$p" ] && ln -sf "$p" "$FAKEBIN/$t" 2>/dev/null || true
done
PATH="$FAKEBIN" PATHFINDER_LOG_DIR="$L4" PATHFINDER_AGENTS_DIR="$AG" sh "$STATS" > "$O5" 2>&1
E5=$?
[ "$E5" -eq 0 ] && ok "jq-absent exit 0" || bad "jq-absent exit $E5"
has 'total_lines: 7' "$O5" "jq-absent falls back to raw line count"
has 'install jq' "$O5" "jq-absent prints hint"
hasnt 'routing table' "$O5" "jq-absent does not attempt routing"

# ============================================================
echo "== fixture 6: empty log dir (graceful) =="
L6="$WORK/l6"; mkdir -p "$L6"
O6="$WORK/o6"; PATHFINDER_LOG_DIR="$L6" PATHFINDER_AGENTS_DIR="$AG" sh "$STATS" > "$O6" 2>&1
E6=$?
[ "$E6" -eq 0 ] && ok "empty-dir exit 0" || bad "empty-dir exit $E6"
has 'no jsonl logs' "$O6" "empty dir reports no jsonl gracefully"

# ============================================================
echo "== fixture 7: absent log dir (graceful) =="
O7="$WORK/o7"; PATHFINDER_LOG_DIR="$WORK/does-not-exist" PATHFINDER_AGENTS_DIR="$AG" sh "$STATS" > "$O7" 2>&1
E7=$?
[ "$E7" -eq 0 ] && ok "absent-dir exit 0" || bad "absent-dir exit $E7"
has 'no pathfinder logs directory' "$O7" "absent dir reported gracefully"

# ============================================================
echo "== fixture 8: malformed / truncated jsonl line (no crash) =="
L8="$WORK/l8"; mkdir -p "$L8"
{
  printf '{"ts":"2026-07-19T00:00:00Z",%s,"session_id":"s","agent_type":"scout","agent_id":"a1","reason":null,"models":["claude-haiku-4-5-20251001"],"output_tokens":10,"input_tokens":1,"cache_read_tokens":1,"cache_creation_tokens":1}\n' "$STOP"
  printf '{"ts":"2026-07-19T00:00:01Z","event":"Subagent\n'   # truncated / broken line
  printf 'not json at all\n'
} > "$L8/2026-07-19.jsonl"
O8="$WORK/o8"; PATHFINDER_LOG_DIR="$L8" PATHFINDER_AGENTS_DIR="$AG" sh "$STATS" > "$O8" 2>&1
E8=$?
[ "$E8" -eq 0 ] && ok "malformed-line exit 0" || bad "malformed-line exit $E8"
has 'compliant=1 / 1' "$O8" "valid line still processed despite malformed neighbors"

# ============================================================
echo "== fixture 9: unrecognized pin alias => report only, never a violation =="
AG9="$WORK/agents9"; mkdir -p "$AG9"
cp "$AG"/*.md "$AG9"/
printf -- '---\nname: scout\nmodel: inherit\neffort: low\n---\n' > "$AG9/scout.md"
L9="$WORK/l9"; mkdir -p "$L9"
printf '{"ts":"2026-07-19T00:00:00Z",%s,"session_id":"s","agent_type":"scout","agent_id":"a1","reason":null,"models":["claude-opus-4-8"],"output_tokens":10,"input_tokens":1,"cache_read_tokens":1,"cache_creation_tokens":1}\n' "$STOP" > "$L9/2026-07-19.jsonl"
O9="$WORK/o9"; PATHFINDER_LOG_DIR="$L9" PATHFINDER_AGENTS_DIR="$AG9" sh "$STATS" > "$O9" 2>&1
has 'scout .*pin=inherit \(alias not recognized\) - reporting only' "$O9" "unmappable alias reported, not a violation"
hasnt 'scout.*OFF-PIN' "$O9" "unmappable alias never yields OFF-PIN"

# ============================================================
echo
echo "== summary: $PASS passed, $FAIL failed =="
[ "$FAIL" -eq 0 ]
