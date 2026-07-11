#!/usr/bin/env sh
# pathfinder health check. posix only. optional; install runbook can do the same by hand.

set -eu

CLAUDE_HOME="${CLAUDE_HOME:-$HOME/.claude}"
AGENTS_DIR="$CLAUDE_HOME/agents"
CLAUDE_MD="$CLAUDE_HOME/CLAUDE.md"
SETTINGS="$CLAUDE_HOME/settings.json"
PF_DIR="$CLAUDE_HOME/pathfinder"
LOG_DIR="$PF_DIR/logs"
MIN_VERSION="2.1.198"
EXPECTED_AGENTS="scout Explore mech-executor executor verifier light-verifier security-executor"

FAILS=0
warn() { printf 'WARN: %s\n' "$1"; }
fail() { printf 'FAIL: %s\n' "$1"; FAILS=$((FAILS + 1)); }
ok() { printf 'OK: %s\n' "$1"; }

echo "pathfinder diagnostics"
echo "---"

# claude version
if command -v claude >/dev/null 2>&1; then
  VER_LINE="$(claude --version 2>/dev/null || true)"
  if [ -z "$VER_LINE" ]; then
    fail "claude present but version undetectable"
  else
    ok "claude: $VER_LINE"
    # extract first x.y.z
    VER="$(printf '%s' "$VER_LINE" | sed -n 's/.*\([0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\).*/\1/p' | head -1)"
    if [ -n "$VER" ]; then
      # numeric compare major.minor.patch
      older_than_min() {
        printf '%s\n%s\n' "$1" "$MIN_VERSION" | sort -t. -k1,1n -k2,2n -k3,3n | head -1 | grep -qx "$1" && [ "$1" != "$MIN_VERSION" ]
      }
      if older_than_min "$VER"; then
        fail "claude $VER is below minimum $MIN_VERSION"
      else
        ok "version $VER meets minimum $MIN_VERSION"
      fi
    else
      warn "could not parse version number from: $VER_LINE"
    fi
  fi
else
  fail "claude not on PATH; cannot verify version"
fi

# settings
if [ -f "$SETTINGS" ]; then
  if command -v jq >/dev/null 2>&1; then
    if jq empty "$SETTINGS" 2>/dev/null; then
      ok "settings.json parses"
      MODEL="$(jq -r '.model // empty' "$SETTINGS" 2>/dev/null || true)"
      [ -n "$MODEL" ] && ok "settings.model=$MODEL" || warn "settings.model unset"
    else
      fail "settings.json is not valid JSON"
    fi
  else
    ok "settings.json present (install jq to validate)"
  fi
else
  warn "settings.json missing"
fi

# CLAUDE_CODE_SUBAGENT_MODEL
if [ -n "${CLAUDE_CODE_SUBAGENT_MODEL:-}" ]; then
  warn "CLAUDE_CODE_SUBAGENT_MODEL is set ($CLAUDE_CODE_SUBAGENT_MODEL); it overrides per-agent model frontmatter"
else
  ok "CLAUDE_CODE_SUBAGENT_MODEL unset"
fi

# markers
if [ -f "$CLAUDE_MD" ]; then
  BEGIN_COUNT="$(grep -c 'pathfinder:begin' "$CLAUDE_MD" 2>/dev/null || true)"
  END_COUNT="$(grep -c 'pathfinder:end' "$CLAUDE_MD" 2>/dev/null || true)"
  BEGIN_COUNT="${BEGIN_COUNT:-0}"
  END_COUNT="${END_COUNT:-0}"
  if [ "$BEGIN_COUNT" = "1" ] && [ "$END_COUNT" = "1" ]; then
    ok "exactly one pathfinder marker pair in CLAUDE.md"
  elif [ "$BEGIN_COUNT" = "0" ] && [ "$END_COUNT" = "0" ]; then
    fail "no pathfinder markers in CLAUDE.md"
  else
    fail "ambiguous markers: begin=$BEGIN_COUNT end=$END_COUNT (expected 1/1)"
  fi
  if grep -q 'pathfinder v' "$CLAUDE_MD" 2>/dev/null; then
    STAMP="$(grep -o 'pathfinder v[0-9.]*' "$CLAUDE_MD" | head -1)"
    ok "version stamp: $STAMP"
  else
    warn "no pathfinder version stamp in CLAUDE.md"
  fi
else
  fail "CLAUDE.md missing"
fi

# agents
if [ -d "$AGENTS_DIR" ]; then
  for name in $EXPECTED_AGENTS; do
    f="$AGENTS_DIR/$name.md"
    if [ -f "$f" ]; then
      ok "agent file $name.md"
    else
      fail "missing agent file $name.md"
    fi
  done
  # name: collision scan (same name in different files)
  if command -v grep >/dev/null 2>&1; then
    NAMES="$(grep -h '^name:' "$AGENTS_DIR"/*.md 2>/dev/null | sed 's/^name:[[:space:]]*//' | sort | uniq -d || true)"
    if [ -n "$NAMES" ]; then
      fail "duplicate agent name: frontmatter collisions: $NAMES"
    else
      ok "no duplicate name: values among agent files"
    fi
  fi
else
  fail "agents directory missing: $AGENTS_DIR"
fi

# pathfinder dir / logs
if [ -d "$PF_DIR" ]; then
  ok "pathfinder dir present"
  [ -f "$PF_DIR/VERSION" ] && ok "pathfinder VERSION=$(cat "$PF_DIR/VERSION")" || warn "pathfinder VERSION file missing"
  if [ -d "$LOG_DIR" ]; then
    ok "logs dir present (best-effort orchestration telemetry; may be empty)"
  else
    warn "logs dir missing (ok if hooks not installed)"
  fi
else
  warn "pathfinder dir missing under $CLAUDE_HOME"
fi

# hooks presence (best-effort string search)
if [ -f "$SETTINGS" ] && grep -q 'SubagentStart\|pathfinder-log' "$SETTINGS" 2>/dev/null; then
  ok "settings mention SubagentStart or pathfinder-log (hooks may be installed)"
else
  warn "no pathfinder hook strings found in settings.json (auto-logging may be off)"
fi

echo "---"
if [ "$FAILS" -gt 0 ]; then
  echo "result: $FAILS failure(s)"
  exit 1
fi
echo "result: ok"
exit 0
