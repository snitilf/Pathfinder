#!/usr/bin/env sh
# fixtures for the model/token telemetry added to pathfinder-log.sh (Change A).
# each case feeds synthetic hook JSON on stdin with a small fixture transcript,
# points PATHFINDER_LOG_DIR at a temp dir, and asserts the produced log line.
# run: sh scripts/tests/pathfinder-log-test.sh

set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
LOG_SH="$HERE/../pathfinder-log.sh"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

PASS=0
FAIL=0
N=0

# run the helper with a given stdin payload, return the last log line written.
# each call uses a fresh temp log dir; PATHFINDER_LOG_DIR is exported for the
# WHOLE pipeline (not just printf) so the helper never touches the real logs.
run_line() {
  N=$((N+1))
  LOG_DIR="$WORK/logs-$N"
  ( export PATHFINDER_LOG_DIR="$LOG_DIR"; printf '%s' "$1" | sh "$LOG_SH" )
  RC=$?
  LINE="$(cat "$LOG_DIR"/*.jsonl 2>/dev/null | tail -1)"
}

ok() {
  # $1 = description, $2 = actual, $3 = expected
  if [ "$2" = "$3" ]; then
    PASS=$((PASS+1))
    printf 'PASS  %s\n' "$1"
  else
    FAIL=$((FAIL+1))
    printf 'FAIL  %s\n      expected: %s\n      actual:   %s\n' "$1" "$3" "$2"
  fi
}

field() { printf '%s' "$1" | jq -c "$2" 2>/dev/null; }

# ---------------------------------------------------------------------------
# fixture 1: DEDUP ALL FIVE FIELDS. one message.id across four lines, input-side
# constant across snapshots, output grows on the last line.
# ---------------------------------------------------------------------------
T1="$WORK/t1.jsonl"
{
  printf '%s\n' '{"type":"assistant","message":{"id":"msg_X","model":"claude-opus-4-8","usage":{"output_tokens":4,"input_tokens":10,"cache_read_input_tokens":20166,"cache_creation_input_tokens":1496}}}'
  printf '%s\n' '{"type":"assistant","message":{"id":"msg_X","model":"claude-opus-4-8","usage":{"output_tokens":4,"input_tokens":10,"cache_read_input_tokens":20166,"cache_creation_input_tokens":1496}}}'
  printf '%s\n' '{"type":"assistant","message":{"id":"msg_X","model":"claude-opus-4-8","usage":{"output_tokens":4,"input_tokens":10,"cache_read_input_tokens":20166,"cache_creation_input_tokens":1496}}}'
  printf '%s\n' '{"type":"assistant","message":{"id":"msg_X","model":"claude-opus-4-8","usage":{"output_tokens":12474,"input_tokens":10,"cache_read_input_tokens":20166,"cache_creation_input_tokens":1496}}}'
} > "$T1"
run_line "{\"hook_event_name\":\"SubagentStop\",\"agent_transcript_path\":\"$T1\"}"
ok "dedup output_tokens=12474 (not 12486)" "$(field "$LINE" .output_tokens)" "12474"
ok "dedup input_tokens=10 (not 40)"         "$(field "$LINE" .input_tokens)" "10"
ok "dedup cache_read_tokens=20166 (not 80664)"     "$(field "$LINE" .cache_read_tokens)" "20166"
ok "dedup cache_creation_tokens=1496 (not 5984)"   "$(field "$LINE" .cache_creation_tokens)" "1496"
ok "dedup models array"                     "$(field "$LINE" .models)" '["claude-opus-4-8"]'

# ---------------------------------------------------------------------------
# fixture 2: PRIVACY. transcript carries prose in text fields; log line must
# contain only model string + integers, no prose.
# ---------------------------------------------------------------------------
T2="$WORK/t2.jsonl"
printf '%s\n' '{"type":"assistant","message":{"id":"msg_P","model":"claude-opus-4-8","content":[{"type":"text","text":"SECRETPROSE_should_never_appear_in_log"}],"usage":{"output_tokens":100,"input_tokens":5,"cache_read_input_tokens":0,"cache_creation_input_tokens":0}}}' > "$T2"
run_line "{\"hook_event_name\":\"SubagentStop\",\"agent_transcript_path\":\"$T2\"}"
if printf '%s' "$LINE" | grep -q "SECRETPROSE"; then
  ok "privacy: no transcript prose in log line" "prose-leaked" "no-prose"
else
  ok "privacy: no transcript prose in log line" "no-prose" "no-prose"
fi

# ---------------------------------------------------------------------------
# fixture 3: synthetic-plus-real. one <synthetic> (zero usage) + one real model.
# models has only the real one; synthetic zero usage does not shift sums.
# ---------------------------------------------------------------------------
T3="$WORK/t3.jsonl"
{
  printf '%s\n' '{"type":"assistant","message":{"id":"msg_syn","model":"<synthetic>","usage":{"output_tokens":0,"input_tokens":0,"cache_read_input_tokens":0,"cache_creation_input_tokens":0}}}'
  printf '%s\n' '{"type":"assistant","message":{"id":"msg_real","model":"claude-sonnet-5","usage":{"output_tokens":50,"input_tokens":7,"cache_read_input_tokens":3,"cache_creation_input_tokens":2}}}'
} > "$T3"
run_line "{\"hook_event_name\":\"SubagentStop\",\"agent_transcript_path\":\"$T3\"}"
ok "synthetic+real: models only real"   "$(field "$LINE" .models)" '["claude-sonnet-5"]'
ok "synthetic+real: output unshifted"    "$(field "$LINE" .output_tokens)" "50"
ok "synthetic+real: input unshifted"     "$(field "$LINE" .input_tokens)" "7"

# ---------------------------------------------------------------------------
# fixture 4: all-synthetic-only. all five fields null, NOT models:[].
# ---------------------------------------------------------------------------
T4="$WORK/t4.jsonl"
{
  printf '%s\n' '{"type":"assistant","message":{"id":"msg_s1","model":"<synthetic>","usage":{"output_tokens":0,"input_tokens":0,"cache_read_input_tokens":0,"cache_creation_input_tokens":0}}}'
  printf '%s\n' '{"type":"assistant","message":{"id":"msg_s2","model":"<synthetic>","usage":{"output_tokens":0,"input_tokens":0,"cache_read_input_tokens":0,"cache_creation_input_tokens":0}}}'
} > "$T4"
run_line "{\"hook_event_name\":\"SubagentStop\",\"agent_transcript_path\":\"$T4\"}"
ok "all-synthetic: models null (not [])"  "$(field "$LINE" .models)" "null"
ok "all-synthetic: output null"           "$(field "$LINE" .output_tokens)" "null"
ok "all-synthetic: input null"            "$(field "$LINE" .input_tokens)" "null"
ok "all-synthetic: cache_read null"       "$(field "$LINE" .cache_read_tokens)" "null"
ok "all-synthetic: cache_creation null"   "$(field "$LINE" .cache_creation_tokens)" "null"

# ---------------------------------------------------------------------------
# fixture 5: multi-model. two real models, sorted distinct.
# ---------------------------------------------------------------------------
T5="$WORK/t5.jsonl"
{
  printf '%s\n' '{"type":"assistant","message":{"id":"msg_o","model":"claude-opus-4-8","usage":{"output_tokens":10,"input_tokens":1,"cache_read_input_tokens":0,"cache_creation_input_tokens":0}}}'
  printf '%s\n' '{"type":"assistant","message":{"id":"msg_f","model":"claude-fable-5","usage":{"output_tokens":20,"input_tokens":2,"cache_read_input_tokens":0,"cache_creation_input_tokens":0}}}'
} > "$T5"
run_line "{\"hook_event_name\":\"SubagentStop\",\"agent_transcript_path\":\"$T5\"}"
ok "multi-model: sorted distinct array" "$(field "$LINE" .models)" '["claude-fable-5","claude-opus-4-8"]'
ok "multi-model: summed output"         "$(field "$LINE" .output_tokens)" "30"

# ---------------------------------------------------------------------------
# fixture 6: missing / unreadable / non-regular-file transcript -> five nulls, exit 0.
# ---------------------------------------------------------------------------
run_line "{\"hook_event_name\":\"SubagentStop\",\"agent_transcript_path\":\"$WORK/does-not-exist.jsonl\"}"
ok "missing transcript: exit 0" "$RC" "0"
ok "missing transcript: models null" "$(field "$LINE" .models)" "null"
ok "missing transcript: output null" "$(field "$LINE" .output_tokens)" "null"

# non-regular file: a directory
run_line "{\"hook_event_name\":\"SubagentStop\",\"agent_transcript_path\":\"$WORK\"}"
ok "directory transcript: exit 0" "$RC" "0"
ok "directory transcript: models null" "$(field "$LINE" .models)" "null"

# unreadable file
TU="$WORK/tu.jsonl"
printf '%s\n' '{"type":"assistant","message":{"id":"msg_u","model":"claude-opus-4-8","usage":{"output_tokens":1,"input_tokens":1,"cache_read_input_tokens":0,"cache_creation_input_tokens":0}}}' > "$TU"
chmod 000 "$TU"
run_line "{\"hook_event_name\":\"SubagentStop\",\"agent_transcript_path\":\"$TU\"}"
# root can read anything; only assert exit 0 + null when the guard actually blocks
if [ ! -r "$TU" ]; then
  ok "unreadable transcript: models null" "$(field "$LINE" .models)" "null"
else
  ok "unreadable transcript: (readable as this user, skipped guard check)" "skip" "skip"
fi
ok "unreadable transcript: exit 0" "$RC" "0"
chmod 644 "$TU"

# ---------------------------------------------------------------------------
# fixture 7: malformed JSONL (truncated line) -> no crash, exit 0, real lines still counted.
# ---------------------------------------------------------------------------
T7="$WORK/t7.jsonl"
{
  printf '%s\n' '{"type":"assistant","message":{"id":"msg_g","model":"claude-opus-4-8","usage":{"output_tokens":9,"input_tokens":3,"cache_read_input_tokens":0,"cache_creation_input_tokens":0}}}'
  printf '%s\n' '{"type":"assistant","message":{"id":"msg_bad","model":"claude-opus-4-8","usage":{"output_tokens":5,"inp'
} > "$T7"
run_line "{\"hook_event_name\":\"SubagentStop\",\"agent_transcript_path\":\"$T7\"}"
ok "malformed jsonl: exit 0" "$RC" "0"
ok "malformed jsonl: valid line still counted" "$(field "$LINE" .output_tokens)" "9"

# ---------------------------------------------------------------------------
# fixture 8: SubagentStart and SessionEnd -> five nulls, six originals unchanged.
# ---------------------------------------------------------------------------
run_line "{\"hook_event_name\":\"SubagentStart\",\"session_id\":\"s1\",\"agent_type\":\"scout\",\"agent_id\":\"a1\",\"agent_transcript_path\":\"$T1\"}"
ok "SubagentStart: event unchanged"  "$(field "$LINE" .event)" '"SubagentStart"'
ok "SubagentStart: agent_type kept"  "$(field "$LINE" .agent_type)" '"scout"'
ok "SubagentStart: models null"      "$(field "$LINE" .models)" "null"
ok "SubagentStart: output null"      "$(field "$LINE" .output_tokens)" "null"

run_line "{\"hook_event_name\":\"SessionEnd\",\"session_id\":\"s2\",\"reason\":\"clear\"}"
ok "SessionEnd: event unchanged"  "$(field "$LINE" .event)" '"SessionEnd"'
ok "SessionEnd: reason kept"      "$(field "$LINE" .reason)" '"clear"'
ok "SessionEnd: models null"      "$(field "$LINE" .models)" "null"

# ---------------------------------------------------------------------------
# fixture 9: jq removed from PATH -> six-field line, exit 0, five fields absent.
# ---------------------------------------------------------------------------
FAKEBIN="$WORK/fakebin"
mkdir -p "$FAKEBIN"
for b in sh sed cat date mkdir printf head tr cut sort awk grep; do
  p="$(command -v "$b" 2>/dev/null)"
  [ -n "$p" ] && ln -sf "$p" "$FAKEBIN/$b"
done
LOG_DIR9="$WORK/logs9"
REAL_SH="$(command -v sh)"
( export PATH="$FAKEBIN" PATHFINDER_LOG_DIR="$LOG_DIR9"; printf '%s' "{\"hook_event_name\":\"SubagentStop\",\"agent_transcript_path\":\"$T1\"}" | "$REAL_SH" "$LOG_SH" )
RC9=$?
LINE9="$(cat "$LOG_DIR9"/*.jsonl 2>/dev/null | tail -1)"
ok "no jq: exit 0" "$RC9" "0"
ok "no jq: event captured via sed" "$(printf '%s' "$LINE9" | grep -c 'SubagentStop')" "1"
if printf '%s' "$LINE9" | grep -q 'models'; then
  ok "no jq: no models field" "has-models" "no-models"
else
  ok "no jq: no models field" "no-models" "no-models"
fi

# ---------------------------------------------------------------------------
# fixture 10: unwritable log dir -> exit 0.
# ---------------------------------------------------------------------------
RO="$WORK/ro"
mkdir -p "$RO"
chmod 555 "$RO"
if mkdir "$RO/sub" 2>/dev/null; then
  # running as root: cannot make an unwritable dir, skip meaningfully
  rmdir "$RO/sub" 2>/dev/null
  ok "unwritable log dir: (running as root, skipped)" "skip" "skip"
else
  ( export PATHFINDER_LOG_DIR="$RO/sub"; printf '%s' "{\"hook_event_name\":\"SubagentStop\",\"agent_transcript_path\":\"$T1\"}" | sh "$LOG_SH" )
  ok "unwritable log dir: exit 0" "$?" "0"
fi
chmod 755 "$RO"

# ---------------------------------------------------------------------------
# real-transcript cross-check (hand-reconstructed ground truth).
# ---------------------------------------------------------------------------
REALT="${PATHFINDER_REAL_TRANSCRIPT:-}"
if [ -n "$REALT" ] && [ -f "$REALT" ]; then
  # reconstruct expected values independently
  EXP="$(jq -r 'select(.message.usage and .message.model != "<synthetic>" and .message.model != null and .message.model != "")
                | [.message.id, .message.model,
                   (.message.usage.output_tokens // 0), (.message.usage.input_tokens // 0),
                   (.message.usage.cache_read_input_tokens // 0), (.message.usage.cache_creation_input_tokens // 0)] | @tsv' "$REALT" \
    | awk -F'\t' '{ if($3>o[$1])o[$1]=$3; if($4>i[$1])i[$1]=$4; if($5>r[$1])r[$1]=$5; if($6>c[$1])c[$1]=$6; m[$2]=1 }
                  END{ for(k in o){O+=o[k];I+=i[k];R+=r[k];C+=c[k]}; printf "%d %d %d %d", O,I,R,C }')"
  run_line "{\"hook_event_name\":\"SubagentStop\",\"agent_transcript_path\":\"$REALT\"}"
  GOT="$(field "$LINE" .output_tokens) $(field "$LINE" .input_tokens) $(field "$LINE" .cache_read_tokens) $(field "$LINE" .cache_creation_tokens)"
  ok "real transcript cross-check ($REALT)" "$GOT" "$EXP"
else
  printf 'SKIP  real transcript cross-check (set PATHFINDER_REAL_TRANSCRIPT)\n'
fi

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
