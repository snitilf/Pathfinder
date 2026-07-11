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
  LINE="$(printf '%s' "$INPUT" | jq -c \
    --arg ts "$TS" \
    '{
      ts: $ts,
      event: (.hook_event_name // .event // "unknown"),
      session_id: (.session_id // null),
      agent_type: (.agent_type // null),
      agent_id: (.agent_id // null),
      reason: (.reason // null)
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
