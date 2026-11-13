#!/usr/bin/env sh
# run local configuration checks without installing or invoking a model.

set -eu
umask 077
HERE="$(CDPATH= cd "$(dirname "$0")" && pwd)"
REPO="$(CDPATH= cd "$HERE/.." && pwd)"
for tool in jq python3; do
  command -v "$tool" >/dev/null 2>&1 || { printf 'FAIL: %s is required\n' "$tool" >&2; exit 1; }
done
find "$HERE" -type f -name '*.sh' -print | while IFS= read -r script; do
  sh -n "$script" || exit 1
done
python3 "$HERE/check-plugin.py" "$REPO"
for test in "$HERE/tests/"*-test.sh; do
  printf '\nRunning %s\n' "$(basename "$test")"
  sh "$test"
done
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' 0
trap 'exit 1' HUP INT TERM
if command -v claude >/dev/null 2>&1; then
  python3 "$HERE/check-plugin.py" "$REPO" --stage "$WORK"
  claude --version
  claude plugin validate --strict "$WORK"
else
  printf '%s\n' 'SKIP: Claude Code is absent; native plugin validation not exercised'
fi
if command -v git >/dev/null 2>&1 && git -C "$REPO" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  git -C "$REPO" diff --check
fi
printf '\n%s\n' 'local checks passed; live model, migration, and task outcomes not exercised'
