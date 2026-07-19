#!/usr/bin/env sh
# best-effort orchestration telemetry appender for pathfinder hooks.
# reads hook JSON from stdin. never fails the session on log errors.

set -eu

LOG_ROOT="${PATHFINDER_LOG_DIR:-$HOME/.claude/pathfinder/logs}"
DAY="$(date -u +%Y-%m-%d 2>/dev/null || date +%Y-%m-%d)"
LOG_FILE="$LOG_ROOT/$DAY.jsonl"
TS="$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date +%Y-%m-%dT%H:%M:%S)"

# soft-fail everything: broken logs must not break a session
mkdir -p "$LOG_ROOT" 2>/dev/null || exit 0

INPUT="$(cat 2>/dev/null || true)"
if [ -z "$INPUT" ]; then
  exit 0
fi

# extract only fields the hook payload may provide; do not invent tokens
if command -v jq >/dev/null 2>&1; then
  # model and token telemetry (five additive fields), all null unless a
  # SubagentStop with a readable regular-file transcript yields real usage.
  # privacy: only the model string and integer token counts leave the
  # transcript; transcript prose is never read into the log line.
  MODELS_JSON=""
  OUT=""
  IN=""
  CREAD=""
  CCREATE=""
  EVENT="$(printf '%s' "$INPUT" | jq -r '.hook_event_name // .event // "unknown"' 2>/dev/null || printf 'unknown')"
  if [ "$EVENT" = "SubagentStop" ]; then
    T="$(printf '%s' "$INPUT" | jq -r '.agent_transcript_path // ""' 2>/dev/null || printf '')"
    # guard: must be a regular readable file, else the five vars stay null
    if [ -n "$T" ] && [ -f "$T" ] && [ -r "$T" ]; then
      # stream the transcript per line (never slurp; files can be multi-MB).
      # dedup by message.id taking max per field across streaming snapshots,
      # then sum across distinct ids. exclude the <synthetic> sentinel and
      # null/empty model strings from both the sums and the model set.
      RESULT="$(jq -r 'select(.message.usage and .message.model != "<synthetic>"
                              and .message.model != null and .message.model != "")
                       | [.message.id, .message.model,
                          (.message.usage.output_tokens // 0),
                          (.message.usage.input_tokens // 0),
                          (.message.usage.cache_read_input_tokens // 0),
                          (.message.usage.cache_creation_input_tokens // 0)] | @tsv' "$T" 2>/dev/null \
        | awk -F'\t' '
            { if ($3 > o[$1]) o[$1]=$3
              if ($4 > i[$1]) i[$1]=$4
              if ($5 > r[$1]) r[$1]=$5
              if ($6 > c[$1]) c[$1]=$6
              m[$2]=1 }
            END { for (k in o){ O+=o[k]; I+=i[k]; R+=r[k]; C+=c[k]; n++ }
                  if (n==0) exit 0
                  printf "%d\t%d\t%d\t%d", O, I, R, C
                  for (k in m) printf "\t%s", k
                  printf "\n" }' 2>/dev/null || true)"
      # zero qualifying lines (all-synthetic / no usage): RESULT empty ->
      # vars stay null (A.0 state 3 collapses to state 1: never models []).
      if [ -n "$RESULT" ]; then
        OUT="$(printf '%s' "$RESULT" | cut -f1)"
        IN="$(printf '%s' "$RESULT" | cut -f2)"
        CREAD="$(printf '%s' "$RESULT" | cut -f3)"
        CCREATE="$(printf '%s' "$RESULT" | cut -f4)"
        # sort model keys portably (macOS awk lacks asorti); jq quotes them
        MODELS_JSON="$(printf '%s' "$RESULT" | cut -f5- | tr '\t' '\n' | sort -u | jq -R . | jq -cs . 2>/dev/null || printf '')"
      fi
    fi
  fi

  LINE="$(printf '%s' "$INPUT" | jq -c \
    --arg ts "$TS" \
    --argjson models "${MODELS_JSON:-null}" \
    --argjson out "${OUT:-null}" \
    --argjson in "${IN:-null}" \
    --argjson cread "${CREAD:-null}" \
    --argjson ccreate "${CCREATE:-null}" \
    '{
      ts: $ts,
      event: (.hook_event_name // .event // "unknown"),
      session_id: (.session_id // null),
      agent_type: (.agent_type // null),
      agent_id: (.agent_id // null),
      reason: (.reason // null),
      models: $models,
      output_tokens: $out,
      input_tokens: $in,
      cache_read_tokens: $cread,
      cache_creation_tokens: $ccreate
    }' 2>/dev/null || true)"
else
  # minimal fallback without jq: store raw event tag if greppable
  EVENT="$(printf '%s' "$INPUT" | sed -n 's/.*"hook_event_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)"
  [ -z "$EVENT" ] && EVENT="unknown"
  SESSION="$(printf '%s' "$INPUT" | sed -n 's/.*"session_id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)"
  ATYPE="$(printf '%s' "$INPUT" | sed -n 's/.*"agent_type"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)"
  LINE="{\"ts\":\"$TS\",\"event\":\"$EVENT\",\"session_id\":$( [ -n "$SESSION" ] && printf '"%s"' "$SESSION" || printf 'null' ),\"agent_type\":$( [ -n "$ATYPE" ] && printf '"%s"' "$ATYPE" || printf 'null' ),\"agent_id\":null,\"reason\":null}"
fi

[ -z "${LINE:-}" ] && exit 0
printf '%s\n' "$LINE" >> "$LOG_FILE" 2>/dev/null || exit 0
exit 0
