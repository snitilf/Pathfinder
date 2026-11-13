#!/usr/bin/env sh
# exercise source failures in disposable copies, without invoking a model.

set -u
umask 077
HERE="$(CDPATH= cd "$(dirname "$0")" && pwd)"
REPO="$(CDPATH= cd "$HERE/../.." && pwd)"
WORK="$(mktemp -d)" || exit 1
trap 'rm -rf "$WORK"' 0
trap 'exit 1' HUP INT TERM
PASS=0; FAIL=0; CASE=0
ok() { PASS=$((PASS + 1)); printf 'PASS: %s\n' "$1"; }
bad() { FAIL=$((FAIL + 1)); printf 'FAIL: %s\n' "$1"; }
fixture() {
  CASE=$((CASE + 1))
  FIXTURE="$WORK/case-$CASE"
  mkdir "$FIXTURE"
  python3 "$REPO/scripts/check-plugin.py" "$REPO" --stage "$FIXTURE" >/dev/null || exit 1
}
run_expect() {
  sh "$REPO/scripts/pathfinder-diag.sh" --plugin "$FIXTURE" > "$WORK/output" 2>&1
  RC=$?
  if [ "$RC" -eq "$1" ]; then ok "$2"; else bad "$2 (exit $RC, expected $1)"; cat "$WORK/output"; fi
}
fixture
run_expect 0 'valid plugin source passes without reading a legacy installation'
fixture
printf '{broken\n' > "$FIXTURE/.claude-plugin/plugin.json"
run_expect 1 'malformed manifest fails'
fixture
rm "$FIXTURE/templates/agents/scout.md"
run_expect 1 'missing declared role fails'
fixture
printf '9.9.9\n' > "$FIXTURE/VERSION"
run_expect 1 'version mismatch fails'
fixture
rm "$FIXTURE/skills/review/SKILL.md"
run_expect 1 'missing review skill fails'
fixture
mkdir "$FIXTURE/hooks"
printf '{"hooks":{}}\n' > "$FIXTURE/hooks/hooks.json"
run_expect 1 'unexpected automatically loaded hooks fail'
fixture
cp "$FIXTURE/templates/agents/scout.md" "$WORK/outside.md"
rm "$FIXTURE/templates/agents/scout.md"
ln -s "$WORK/outside.md" "$FIXTURE/templates/agents/scout.md"
run_expect 1 'declared source symlink escaping the plugin fails'
fixture
python3 - "$FIXTURE/.claude-plugin/plugin.json" <<'PY'
import json
import sys
from pathlib import Path
path = Path(sys.argv[1])
data = json.loads(path.read_text())
data['settings'] = {'model': 'opus'}
path.write_text(json.dumps(data))
PY
run_expect 1 'unexpected settings override fails'
fixture
printf '{}\n' > "$FIXTURE/templates/settings.snippet.json"
rm "$FIXTURE/templates/settings.snippet.json"
run_expect 1 'missing settings preservation contract fails'
fixture
printf '<!-- pathfinder:begin -->\n<!-- pathfinder v9.9.9 -->\n' > "$FIXTURE/templates/claude-md/00-header.md"
run_expect 1 'optional policy version mismatch fails'
fixture
printf '<!-- pathfinder:end -->\n<!-- pathfinder v2.0.0 -->\n' > "$FIXTURE/templates/claude-md/00-header.md"
printf '<!-- pathfinder:begin -->\n' > "$FIXTURE/templates/claude-md/90-footer.md"
run_expect 1 'reversed optional source policy markers fail'
fixture
mkdir "$FIXTURE/inside"
python3 "$REPO/scripts/check-plugin.py" "$FIXTURE" --stage "$FIXTURE/inside" > "$WORK/output" 2>&1
RC=$?
if [ "$RC" -eq 1 ] && [ ! -e "$FIXTURE/inside/.claude-plugin/plugin.json" ]; then ok 'staging inside plugin source is rejected before copying'; else bad 'staging inside plugin source is rejected before copying'; fi
printf '\n%s\n' "summary: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
