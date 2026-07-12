#!/usr/bin/env sh
# best-effort sessionstart tripwire for pathfinder.
# notices claude code version bumps and injects a revalidation reminder.
# never fails the session: every error path exits 0.
# stdout becomes claude-facing context, so only validated values are printed.

set -eu

STATE_DIR="${PATHFINDER_HOME:-$HOME/.claude/pathfinder}"
STATE_FILE="$STATE_DIR/last-version"
MANIFEST="$STATE_DIR/INSTALL"
CHECKLIST="$STATE_DIR/REVALIDATION.md"

# required role templates a usable checkout must carry
ROLES="scout Explore mech-executor executor verifier light-verifier security-executor"

is_semver() {
  printf '%s' "$1" | LC_ALL=C grep -q '^[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*$'
}

# count lines starting with key= in the manifest
key_count() {
  LC_ALL=C grep -c "^$1=" "$MANIFEST" 2>/dev/null || true
}

key_value() {
  LC_ALL=C sed -n "s/^$1=//p" "$MANIFEST" 2>/dev/null | head -1
}

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

# validate old before it can reach output; malformed state is repaired
# and reported with a neutral label instead of its raw content
OLD_LABEL="a previous version"
OLD_VALID=0
if [ -n "$OLD" ] && is_semver "$OLD"; then
  OLD_LABEL="$OLD"
  OLD_VALID=1
fi

# unchanged: stay quiet
[ "$OLD_VALID" = "1" ] && [ "$OLD" = "$NEW" ] && exit 0

# changed (or unreadable state): update state, then inject the reminder
printf '%s\n' "$NEW" > "$STATE_FILE" 2>/dev/null || exit 0

# manifest validity per the install schema (schema=1, single parseable
# version, valid enums, no duplicate known keys, valid source_commit)
MANIFEST_VALID=0
if [ -f "$MANIFEST" ]; then
  SC="$(key_count schema)"; VC="$(key_count version)"
  WC="$(key_count working_style)"; RC="$(key_count repo)"
  FC="$(key_count ref)"; CC="$(key_count source_commit)"; IC="$(key_count installed_at)"
  if [ "${SC:-0}" = "1" ] && [ "$(key_value schema)" = "1" ] \
    && [ "${VC:-0}" = "1" ] && is_semver "$(key_value version)" \
    && [ "${WC:-0}" -le 1 ] && [ "${RC:-0}" -le 1 ] && [ "${FC:-0}" -le 1 ] \
    && [ "${CC:-0}" -le 1 ] && [ "${IC:-0}" -le 1 ]; then
    MANIFEST_VALID=1
    WS="$(key_value working_style)"
    if [ -n "$WS" ] && [ "$WS" != "yes" ] && [ "$WS" != "no" ]; then MANIFEST_VALID=0; fi
    COMMIT="$(key_value source_commit)"
    if [ -n "$COMMIT" ]; then
      printf '%s' "$COMMIT" | LC_ALL=C grep -Eq '^[0-9a-f]{40}$|^[0-9a-f]{64}$' || MANIFEST_VALID=0
    fi
  fi
fi

# the repo line prints only for a validated, usable pathfinder checkout:
# valid manifest, absolute control-character-free path, existing dir,
# VERSION present, every required role template present
REPO_LINE=""
if [ "$MANIFEST_VALID" = "1" ]; then
  REPO="$(key_value repo)"
  if [ -n "$REPO" ]; then
    CLEAN="$(printf '%s' "$REPO" | LC_ALL=C tr -cd '[:print:]')"
    case "$REPO" in
      /*)
        if [ "$CLEAN" = "$REPO" ] && [ -d "$REPO" ] && [ -f "$REPO/VERSION" ]; then
          USABLE=1
          for r in $ROLES; do
            [ -f "$REPO/templates/agents/$r.md" ] || USABLE=0
          done
          [ "$USABLE" = "1" ] && REPO_LINE="Pathfinder repo (fixes happen there): $REPO"
        fi
        ;;
    esac
  fi
fi

# checklist line prefers the installed copy so any session can read it
if [ -f "$CHECKLIST" ]; then
  CHECKLIST_LINE="Checklist: $CHECKLIST"
else
  CHECKLIST_LINE="Checklist: docs/REVALIDATION.md in the pathfinder repo."
fi

printf '%s\n' "Claude Code changed from $OLD_LABEL to $NEW since pathfinder was last revalidated."
printf '%s\n' "Most Claude Code updates do not affect pathfinder; run the checklist when convenient."
printf '%s\n' "Re-check: model aliases and fallbackModel (https://code.claude.com/docs/en/model-config), hook events and payload fields (https://code.claude.com/docs/en/hooks), subagent frontmatter and discovery (https://code.claude.com/docs/en/sub-agents)."
printf '%s\n' "$CHECKLIST_LINE"
[ -n "$REPO_LINE" ] && printf '%s\n' "$REPO_LINE"

exit 0
