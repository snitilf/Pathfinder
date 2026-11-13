#!/usr/bin/env sh
# regression fixtures for the optional last-seen version reminder.
# state and the claude binary live in a temporary directory.

set -u
umask 077

HERE="$(CDPATH= cd "$(dirname "$0")" && pwd)"
WATCH="$HERE/../pathfinder-version-watch.sh"
WORK="$(mktemp -d)" || exit 1
trap 'rm -rf "$WORK"' 0
trap 'exit 1' HUP INT TERM
PASS=0
FAIL=0
CALL=0
STATE="$WORK/state"
BIN="$WORK/bin"
mkdir -p "$BIN"
cat > "$BIN/claude" <<'EOF'
#!/usr/bin/env sh
printf '%s (Claude Code)\n' "${FAKE_CLAUDE_VERSION:-2.1.322}"
EOF
chmod 700 "$BIN/claude"

ok() { PASS=$((PASS + 1)); printf 'PASS: %s\n' "$1"; }
bad() { FAIL=$((FAIL + 1)); printf 'FAIL: %s\n' "$1"; }
status_ok() { if [ "$RC" -eq 0 ]; then ok "$1"; else bad "$1 (exit $RC)"; fi; }
silent() { if [ ! -s "$OUTPUT" ]; then ok "$1"; else bad "$1"; fi; }
has() { if grep -Eq "$1" "$OUTPUT"; then ok "$2"; else bad "$2"; fi; }
hasnt() { if grep -Eq "$1" "$OUTPUT"; then bad "$2"; else ok "$2"; fi; }
state_is() { if [ "$(cat "$STATE/last-version" 2>/dev/null)" = "$1" ]; then ok "$2"; else bad "$2"; fi; }

run_watch() {
  CALL=$((CALL + 1))
  OUTPUT="$WORK/output-$CALL"
  PATH="$BIN:$PATH" FAKE_CLAUDE_VERSION="$1" PATHFINDER_HOME="$STATE" sh "$WATCH" > "$OUTPUT" 2>&1
  RC=$?
}

run_watch 2.1.321
status_ok 'first observation exits successfully'
silent 'first observation is silent'
state_is 2.1.321 'first observation stores the current version'

run_watch 2.1.321
status_ok 'unchanged version exits successfully'
silent 'unchanged version is silent'

run_watch 2.1.322
status_ok 'changed version exits successfully'
has 'Claude Code changed from 2\.1\.321 to 2\.1\.322' 'notice identifies the observed change'
has 'last[- ]seen|last (saw|observed)|previous (observation|startup)' 'notice describes an observation rather than completed validation'
hasnt 'last revalidated' 'notice does not claim a completed validation'
state_is 2.1.322 'changed version updates the stored observation'

run_watch 2.1.322
status_ok 'repeated new version exits successfully'
silent 'repeated new version does not repeat the notice'

printf 'UNTRUSTED_VERSION\033[31m\n' > "$STATE/last-version"
run_watch 2.1.322
status_ok 'malformed saved version exits successfully'
has 'a previous version' 'malformed saved version receives a neutral label'
hasnt 'UNTRUSTED_VERSION' 'malformed saved version is not echoed'
state_is 2.1.322 'malformed saved version is repaired'

REPO="$(CDPATH= cd "$HERE/../.." && pwd)"
printf 'schema=1\nversion=1.2.0\nrepo=%s\nworking_style=no\n' "$REPO" > "$STATE/INSTALL"
run_watch 2.1.323
has 'Pathfinder repo \(fixes happen there\):' 'two-role plugin checkout remains a usable reminder target'

printf '\n%s\n' "summary: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
