#!/usr/bin/env sh
# summarize pathfinder jsonl logs if present. missing logs are a normal state.

set -eu

LOG_ROOT="${PATHFINDER_LOG_DIR:-$HOME/.claude/pathfinder/logs}"

if [ ! -d "$LOG_ROOT" ]; then
  echo "no pathfinder logs directory at $LOG_ROOT (normal if hooks are not installed)"
  exit 0
fi

# shellcheck disable=SC2012
FILES="$(ls -1 "$LOG_ROOT"/*.jsonl 2>/dev/null || true)"
if [ -z "$FILES" ]; then
  echo "no jsonl logs under $LOG_ROOT (normal if no hook events yet)"
  exit 0
fi

echo "pathfinder log summary ($LOG_ROOT)"
echo "---"

if command -v jq >/dev/null 2>&1; then
  # counts by event and agent_type across all days
  cat "$LOG_ROOT"/*.jsonl 2>/dev/null | jq -s '
    "total_lines: \(length)",
    "by_event:",
    (group_by(.event) | map({(.[0].event // "null"): length}) | add // {}),
    "by_agent_type:",
    (group_by(.agent_type) | map({(.[0].agent_type // "null"): length}) | add // {})
  ' 2>/dev/null || {
    TOTAL="$(cat "$LOG_ROOT"/*.jsonl 2>/dev/null | wc -l | tr -d ' ')"
    echo "total_lines: $TOTAL (jq parse failed; raw line count only)"
  }
else
  TOTAL="$(cat "$LOG_ROOT"/*.jsonl 2>/dev/null | wc -l | tr -d ' ')"
  echo "total_lines: $TOTAL"
  echo "(install jq for breakdown by event and agent_type)"
fi

exit 0
