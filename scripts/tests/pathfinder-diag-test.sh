#!/usr/bin/env sh
# regression fixtures for legacy installation diagnostics.
# all configuration and the claude binary live in a temporary directory.

set -u
umask 077

HERE="$(CDPATH= cd "$(dirname "$0")" && pwd)"
DIAG="$HERE/../pathfinder-diag.sh"
WORK="$(mktemp -d)" || exit 1
trap 'rm -rf "$WORK"' 0
trap 'exit 1' HUP INT TERM
PASS=0
FAIL=0
CASE=0

command -v jq >/dev/null 2>&1 || { printf '%s\n' 'FAIL: jq is required for diagnostic fixtures'; exit 1; }

BIN="$WORK/bin"
mkdir -p "$BIN"
cat > "$BIN/claude" <<'EOF'
#!/usr/bin/env sh
printf '%s (Claude Code)\n' "${FAKE_CLAUDE_VERSION:-2.1.322}"
EOF
chmod 700 "$BIN/claude"

ok() { PASS=$((PASS + 1)); printf 'PASS: %s\n' "$1"; }
bad() { FAIL=$((FAIL + 1)); printf 'FAIL: %s\n' "$1"; }
has() { if grep -Eq "$1" "$OUTPUT"; then ok "$2"; else bad "$2"; fi; }
status_is() { if [ "$RC" -eq "$1" ]; then ok "$2"; else bad "$2 (exit $RC, expected $1)"; fi; }

fixture() {
  CASE=$((CASE + 1))
  FIXTURE="$WORK/case-$CASE"
  mkdir -p "$FIXTURE/agents" "$FIXTURE/pathfinder/logs"
  printf '%s\n' '{}' > "$FIXTURE/settings.json"
  printf '%s\n' '<!-- pathfinder:begin -->' '<!-- pathfinder v1.2.0 -->' 'legacy policy' '<!-- pathfinder:end -->' > "$FIXTURE/CLAUDE.md"
  printf '%s\n' '1.2.0' > "$FIXTURE/pathfinder/VERSION"
  for role in scout Explore mech-executor executor verifier light-verifier security-executor; do
    printf -- '---\nname: %s\ndescription: legacy fixture\nmodel: opus\n---\n' "$role" > "$FIXTURE/agents/$role.md"
  done
  OUTPUT="$WORK/output-$CASE"
}

run_diag() {
  PATH="$BIN:$PATH" FAKE_CLAUDE_VERSION=2.1.322 CLAUDE_HOME="$FIXTURE" sh "$DIAG" > "$OUTPUT" 2>&1
  RC=$?
}

fixture
run_diag
status_is 0 'ordered legacy installation passes'
has 'result: ok' 'ordered installation reports success'

fixture
printf '%s\n' '<!-- pathfinder:end -->' 'legacy policy' '<!-- pathfinder:begin -->' > "$FIXTURE/CLAUDE.md"
run_diag
status_is 1 'reversed policy markers fail'
has 'FAIL:.*(marker|order|ambiguous)' 'reversed markers produce a diagnostic'

fixture
mkdir -p "$FIXTURE/agents/nested"
cp "$FIXTURE/agents/scout.md" "$FIXTURE/agents/nested/duplicate.md"
run_diag
status_is 1 'duplicate agent names fail'
has 'FAIL:.*duplicate agent name' 'duplicate name is identified'

fixture
mkdir -p "$FIXTURE/agents/nested"
cp "$FIXTURE/agents/scout.md" "$FIXTURE/agents/nested/scout.md"
printf -- '---\nname: another-agent\ndescription: fixture\n---\n' > "$FIXTURE/agents/scout.md"
run_diag
status_is 1 'nested legacy role claim fails without duplicate names'
has 'FAIL:.*nested agent file claims pathfinder role' 'nested role location is identified'

fixture
printf '%s\n' '{"model":' > "$FIXTURE/settings.json"
run_diag
status_is 1 'invalid settings JSON fails'
has 'FAIL:.*settings.json.*valid JSON' 'invalid settings are identified'

fixture
printf '%s\n' 'quoted <!-- pathfinder:begin --> text' 'quoted <!-- pathfinder:end --> text' > "$FIXTURE/CLAUDE.md"
run_diag
status_is 1 'quoted marker substrings are not an installed block'

fixture
REPO="$(CDPATH= cd "$HERE/../.." && pwd)"
printf 'schema=1\nversion=1.2.0\nrepo=%s\nworking_style=no\n' "$REPO" > "$FIXTURE/pathfinder/INSTALL"
run_diag
status_is 0 'legacy install remains healthy with a v2 source checkout'
has 'v2 plugin migration target' 'v2 source is identified as migration rather than repair'
if grep -q 're-run install to sync' "$OUTPUT"; then bad 'v2 source does not recommend incompatible template repair'; else ok 'v2 source does not recommend incompatible template repair'; fi

fixture
rm "$FIXTURE/agents/verifier.md"
run_diag
status_is 1 'missing legacy role fails'
has 'FAIL:.*missing agent file verifier.md' 'missing role is identified'

printf '\n%s\n' "summary: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
