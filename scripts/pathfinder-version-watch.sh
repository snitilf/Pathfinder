#!/usr/bin/env sh
# best-effort sessionstart tripwire for pathfinder.
# notices claude code version bumps and injects a revalidation reminder.
# never fails the session: every error path exits 0.

set -eu

STATE_DIR="${PATHFINDER_HOME:-$HOME/.claude/pathfinder}"
STATE_FILE="$STATE_DIR/last-version"

# read the running claude version; soft-fail if the binary is missing
RAW="$(claude --version 2>/dev/null || true)"
[ -z "$RAW" ] && exit 0

# parse an x.y.z out of whatever claude --version printed
NEW="$(printf '%s' "$RAW" | sed -n 's/.*\([0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\).*/\1/p' | head -1)"
[ -z "$NEW" ] && exit 0

# soft-fail if we cannot make the state dir
mkdir -p "$STATE_DIR" 2>/dev/null || exit 0

# first run: record silently, never fire
if [ ! -f "$STATE_FILE" ]; then
  printf '%s\n' "$NEW" > "$STATE_FILE" 2>/dev/null || exit 0
  exit 0
fi

OLD="$(head -1 "$STATE_FILE" 2>/dev/null || true)"

# unchanged (or unreadable state): stay quiet
[ -z "$OLD" ] && exit 0
[ "$OLD" = "$NEW" ] && exit 0

# changed: update state, then inject the reminder on stdout
printf '%s\n' "$NEW" > "$STATE_FILE" 2>/dev/null || exit 0

printf '%s\n' "Claude Code changed from $OLD to $NEW since pathfinder was last revalidated."
printf '%s\n' "Before trusting the installed settings and hooks, re-check model aliases and fallbackModel shape (https://code.claude.com/docs/en/model-config), hook events and payload fields (https://code.claude.com/docs/en/hooks), and subagent frontmatter keys (model, effort, disallowedTools)."
printf '%s\n' "Full checklist in docs/REVALIDATION.md in the pathfinder repo."

exit 0
