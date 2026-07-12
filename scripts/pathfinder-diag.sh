#!/usr/bin/env sh
# pathfinder health check. posix only. optional; install runbook can do the same by hand.
# content drift against the local checkout is warn-only; health problems are failures.
# values read from mutable local files are sanitized before display.

set -eu

CLAUDE_HOME="${CLAUDE_HOME:-$HOME/.claude}"
AGENTS_DIR="$CLAUDE_HOME/agents"
CLAUDE_MD="$CLAUDE_HOME/CLAUDE.md"
SETTINGS="$CLAUDE_HOME/settings.json"
PF_DIR="$CLAUDE_HOME/pathfinder"
PF_BIN="$PF_DIR/bin"
LOG_DIR="$PF_DIR/logs"
MANIFEST="$PF_DIR/INSTALL"
BACKUP_DIR="$CLAUDE_HOME/backups/pathfinder"
MIN_VERSION="2.1.198"
EXPECTED_AGENTS="scout Explore mech-executor executor verifier light-verifier security-executor"
PF_SCRIPTS="pathfinder-log.sh pathfinder-version-watch.sh pathfinder-diag.sh pathfinder-stats.sh"

FAILS=0
warn() { printf 'WARN: %s\n' "$1"; }
fail() { printf 'FAIL: %s\n' "$1"; FAILS=$((FAILS + 1)); }
ok() { printf 'OK: %s\n' "$1"; }

# strip control, escape, and other non-printing bytes before any
# mutable-file value or path reaches output; plain spaces survive
sanitize() { printf '%s' "$1" | LC_ALL=C tr -cd '[:print:]'; }

is_semver() {
  printf '%s' "$1" | LC_ALL=C grep -q '^[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*$'
}

# portable octal mode: bsd stat, then gnu stat; callers check MODE_OK first
MODE_OK=1
get_mode() {
  stat -f %Lp "$1" 2>/dev/null || stat -c %a "$1" 2>/dev/null || return 1
}
if ! get_mode "$HOME" >/dev/null 2>&1; then
  MODE_OK=0
fi

# true when mode string has any group or other write bit
gw_writable() {
  case "$1" in
    *[2367]?) return 0 ;;
    *[2367]) return 0 ;;
  esac
  return 1
}

TMPD=""
cleanup() { [ -n "$TMPD" ] && rm -rf "$TMPD" 2>/dev/null || true; }
trap cleanup EXIT

echo "pathfinder diagnostics"
echo "---"

# claude version
if command -v claude >/dev/null 2>&1; then
  VER_LINE="$(claude --version 2>/dev/null || true)"
  if [ -z "$VER_LINE" ]; then
    fail "claude present but version undetectable"
  else
    ok "claude: $(sanitize "$VER_LINE")"
    VER="$(printf '%s' "$VER_LINE" | sed -n 's/.*\([0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\).*/\1/p' | head -1)"
    if [ -n "$VER" ]; then
      older_than() {
        printf '%s\n%s\n' "$1" "$2" | sort -t. -k1,1n -k2,2n -k3,3n | head -1 | grep -qx "$1" && [ "$1" != "$2" ]
      }
      if older_than "$VER" "$MIN_VERSION"; then
        fail "claude $VER is below minimum $MIN_VERSION"
      else
        ok "version $VER meets minimum $MIN_VERSION"
      fi
    else
      warn "could not parse version number from claude output"
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
      [ -n "$MODEL" ] && ok "settings.model=$(sanitize "$MODEL")" || warn "settings.model unset"
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
  warn "CLAUDE_CODE_SUBAGENT_MODEL is set; it overrides per-agent model frontmatter"
else
  ok "CLAUDE_CODE_SUBAGENT_MODEL unset"
fi

# markers
MARKERS_OK=0
if [ -f "$CLAUDE_MD" ]; then
  BEGIN_COUNT="$(grep -c 'pathfinder:begin' "$CLAUDE_MD" 2>/dev/null || true)"
  END_COUNT="$(grep -c 'pathfinder:end' "$CLAUDE_MD" 2>/dev/null || true)"
  BEGIN_COUNT="${BEGIN_COUNT:-0}"
  END_COUNT="${END_COUNT:-0}"
  if [ "$BEGIN_COUNT" = "1" ] && [ "$END_COUNT" = "1" ]; then
    ok "exactly one pathfinder marker pair in CLAUDE.md"
    MARKERS_OK=1
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

# agents: recursive scan. claude code discovers agents recursively and
# requires unique name: values across the whole tree, so nested files count.
if [ -d "$AGENTS_DIR" ]; then
  for name in $EXPECTED_AGENTS; do
    f="$AGENTS_DIR/$name.md"
    if [ -f "$f" ]; then
      ok "agent file $name.md"
    else
      fail "missing agent file $name.md"
    fi
  done

  TMPD="$(mktemp -d 2>/dev/null || true)"
  if [ -z "$TMPD" ]; then
    warn "mktemp unavailable; recursive collision scan and source comparison skipped"
  else
    # frontmatter name: only (between the first --- pair), never body text
    NAMETAB="$TMPD/names"
    : > "$NAMETAB"
    find "$AGENTS_DIR" -type f -name '*.md' -print 2>/dev/null | while IFS= read -r f; do
      n="$(awk 'NR==1{if($0!="---")exit} NR>1&&/^---/{exit} NR>1&&/^name:[ \t]*/{sub(/^name:[ \t]*/,"");print;exit}' "$f" 2>/dev/null || true)"
      [ -n "$n" ] && printf '%s\t%s\n' "$n" "$f" >> "$NAMETAB"
    done

    DUPES="$(cut -f1 "$NAMETAB" 2>/dev/null | sort | uniq -d || true)"
    if [ -n "$DUPES" ]; then
      printf '%s\n' "$DUPES" | while IFS= read -r d; do
        PATHS="$(grep "^$d	" "$NAMETAB" | cut -f2 | tr '\n' ' ' || true)"
        printf 'FAIL: %s\n' "duplicate agent name '$(sanitize "$d")' in: $(sanitize "$PATHS")"
      done
      # the while runs in a subshell; count dupes here for the exit code
      FAILS=$((FAILS + $(printf '%s\n' "$DUPES" | grep -c . || true)))
    else
      ok "no duplicate name: values across the agents tree"
    fi

    # nested file claiming a pathfinder role name, even if root file is absent
    for name in $EXPECTED_AGENTS; do
      NESTED="$(grep "^$name	" "$NAMETAB" | cut -f2 | grep -v "^$AGENTS_DIR/$name\.md$" || true)"
      if [ -n "$NESTED" ]; then
        fail "nested agent file claims pathfinder role '$name': $(sanitize "$(printf '%s' "$NESTED" | tr '\n' ' ')")"
      fi
    done
  fi
else
  fail "agents directory missing: $AGENTS_DIR"
fi

# pathfinder dir / logs
INSTALLED_VER=""
if [ -d "$PF_DIR" ]; then
  ok "pathfinder dir present"
  if [ -f "$PF_DIR/VERSION" ]; then
    INSTALLED_VER="$(head -1 "$PF_DIR/VERSION" 2>/dev/null || true)"
    if is_semver "$INSTALLED_VER"; then
      ok "pathfinder VERSION=$INSTALLED_VER"
    else
      warn "installed VERSION file is malformed"
      INSTALLED_VER=""
    fi
  else
    warn "pathfinder VERSION file missing"
  fi
  if [ -d "$LOG_DIR" ]; then
    ok "logs dir present (best-effort orchestration telemetry; may be empty)"
  else
    warn "logs dir missing (ok if hooks not installed)"
  fi
else
  warn "pathfinder dir missing under $CLAUDE_HOME"
fi

# pathfinder-owned directories must be real private directories, not symlinks
for d in "$PF_DIR" "$PF_BIN" "$LOG_DIR" "$BACKUP_DIR"; do
  [ -e "$d" ] || continue
  if [ -h "$d" ]; then
    warn "pathfinder-owned path is a symlink: $(sanitize "$d"); writes could be redirected; replace with a real directory"
    continue
  fi
  if [ "$MODE_OK" = "1" ]; then
    M="$(get_mode "$d" 2>/dev/null || true)"
    if [ -n "$M" ] && gw_writable "$M"; then
      warn "pathfinder-owned directory is group/world writable (mode $M): $(sanitize "$d")"
    fi
  fi
done
if [ "$MODE_OK" = "0" ]; then
  warn "mode integrity check skipped (no supported stat)"
fi

# executable bit on installed helpers that exist
for s in $PF_SCRIPTS; do
  p="$PF_BIN/$s"
  [ -f "$p" ] || continue
  if [ -h "$p" ]; then
    warn "installed helper is a symlink: $(sanitize "$p"); replace with a regular file"
  elif [ ! -x "$p" ]; then
    warn "installed helper is not executable: $(sanitize "$p"); chmod +x it"
  fi
done

# install manifest: strict validity, then source-based drift checks
MANIFEST_STATE="none"
REPO=""
WS=""
MVER=""
if [ -f "$MANIFEST" ]; then
  kc() { LC_ALL=C grep -c "^$1=" "$MANIFEST" 2>/dev/null || true; }
  kv() { LC_ALL=C sed -n "s/^$1=//p" "$MANIFEST" 2>/dev/null | head -1; }
  SC="$(kc schema)"; VC="$(kc version)"; WC="$(kc working_style)"
  RC="$(kc repo)"; FC="$(kc ref)"; CC="$(kc source_commit)"; IC="$(kc installed_at)"
  if [ "${SC:-0}" != "1" ] || [ "${VC:-0}" != "1" ] || [ "${WC:-0}" -gt 1 ] \
    || [ "${RC:-0}" -gt 1 ] || [ "${FC:-0}" -gt 1 ] || [ "${CC:-0}" -gt 1 ] || [ "${IC:-0}" -gt 1 ]; then
    MANIFEST_STATE="invalid"
  elif [ "$(kv schema)" != "1" ]; then
    MANIFEST_STATE="unsupported"
  else
    MANIFEST_STATE="valid"
    MVER="$(kv version)"
    is_semver "$MVER" || MANIFEST_STATE="invalid"
    WS="$(kv working_style)"
    if [ -n "$WS" ] && [ "$WS" != "yes" ] && [ "$WS" != "no" ]; then MANIFEST_STATE="invalid"; fi
    COMMIT="$(kv source_commit)"
    if [ -n "$COMMIT" ]; then
      printf '%s' "$COMMIT" | LC_ALL=C grep -Eq '^[0-9a-f]{40}$|^[0-9a-f]{64}$' || MANIFEST_STATE="invalid"
    fi
    REPO="$(kv repo)"
  fi
fi

SOURCE_OK=0
case "$MANIFEST_STATE" in
  none)
    warn "no install manifest (pre-1.1.0 install); drift checks skipped; re-run install to create it"
    ;;
  unsupported)
    warn "install manifest schema is unsupported by this diag; re-run install or update pathfinder"
    ;;
  invalid)
    warn "install manifest invalid; re-run install to repair"
    ;;
  valid)
    ok "install manifest valid (schema 1)"
    if [ -n "$INSTALLED_VER" ] && [ "$MVER" != "$INSTALLED_VER" ]; then
      warn "manifest records version $MVER but installed VERSION is $INSTALLED_VER; re-run install"
    fi
    if [ -z "$REPO" ]; then
      warn "no local source available for comparison; drift checks skipped"
    else
      # usable checkout: absolute clean path, VERSION, every required role template
      RCLEAN="$(sanitize "$REPO")"
      USABLE=1
      case "$REPO" in /*) : ;; *) USABLE=0 ;; esac
      [ "$RCLEAN" = "$REPO" ] || USABLE=0
      [ -d "$REPO" ] || USABLE=0
      if [ "$USABLE" = "1" ]; then
        [ -f "$REPO/VERSION" ] || USABLE=0
        for name in $EXPECTED_AGENTS; do
          [ -f "$REPO/templates/agents/$name.md" ] || USABLE=0
        done
      fi
      if [ "$USABLE" = "1" ]; then
        SOURCE_OK=1
      else
        warn "recorded repo path missing or not a usable pathfinder checkout: $RCLEAN"
      fi
    fi
    ;;
esac

# source-based drift checks (all warn-only: drift means stale or customized,
# never corrupted; an uncommitted repo edit is a normal cause)
if [ "$SOURCE_OK" = "1" ]; then
  # version ordering: equal, repo newer (update available), repo older, unorderable
  RVER="$(head -1 "$REPO/VERSION" 2>/dev/null || true)"
  if [ -n "$INSTALLED_VER" ] && is_semver "$RVER"; then
    if [ "$RVER" = "$INSTALLED_VER" ]; then
      ok "repo and installed versions match ($INSTALLED_VER)"
    else
      LOWER="$(printf '%s\n%s\n' "$RVER" "$INSTALLED_VER" | sort -t. -k1,1n -k2,2n -k3,3n | head -1)"
      if [ "$LOWER" = "$INSTALLED_VER" ]; then
        warn "update available: repo is at $RVER, installed is $INSTALLED_VER; re-run install to apply"
      else
        warn "local checkout ($RVER) predates the installation ($INSTALLED_VER); the checkout is behind, not the install"
      fi
    fi
  else
    warn "cannot determine version ordering; one or both VERSION files are malformed; check them by hand"
  fi

  # agents: derived list = template basenames (base role set already verified)
  for t in "$REPO/templates/agents/"*.md; do
    [ -f "$t" ] || continue
    b="$(basename "$t")"
    inst="$AGENTS_DIR/$b"
    if [ -f "$inst" ]; then
      if ! cmp -s "$t" "$inst"; then
        warn "installed agent $b differs from the local checkout; the checkout may have uncommitted changes, or the install is stale; re-run install to sync"
      fi
    fi
  done

  # installed helpers vs source scripts (only those present on both sides)
  for s in $PF_SCRIPTS; do
    src="$REPO/scripts/$s"
    inst="$PF_BIN/$s"
    [ -f "$inst" ] || continue
    if [ ! -f "$src" ]; then
      warn "local checkout is missing scripts/$s; skipping that comparison"
      continue
    fi
    if ! cmp -s "$src" "$inst"; then
      warn "installed helper $s differs from the local checkout; the checkout may have uncommitted changes, or the install is stale; re-run install to sync"
    fi
  done

  # installed checklist copy
  if [ -f "$PF_DIR/REVALIDATION.md" ]; then
    if [ ! -f "$REPO/docs/REVALIDATION.md" ]; then
      warn "local checkout is missing docs/REVALIDATION.md; skipping that comparison"
    elif ! cmp -s "$REPO/docs/REVALIDATION.md" "$PF_DIR/REVALIDATION.md"; then
      warn "installed REVALIDATION.md differs from the local checkout; re-run install to sync"
    fi
  fi

  # policy block: rebuild expected assembly per manifest working_style
  if [ "$MARKERS_OK" = "1" ] && [ -n "$TMPD" ]; then
    FRAGS_OK=1
    for frag in 00-header.md 10-core.md 20-verification.md 90-footer.md; do
      [ -f "$REPO/templates/claude-md/$frag" ] || FRAGS_OK=0
    done
    STYLE_FRAG="$REPO/templates/claude-md/60-working-style.md"
    if [ "$FRAGS_OK" = "0" ]; then
      warn "local checkout is missing policy fragments; skipping policy comparison"
    else
      awk '/pathfinder:begin/{f=1} f{print} /pathfinder:end/{exit}' "$CLAUDE_MD" > "$TMPD/installed.block" 2>/dev/null || true
      cat "$REPO/templates/claude-md/00-header.md" "$REPO/templates/claude-md/10-core.md" \
        "$REPO/templates/claude-md/20-verification.md" "$REPO/templates/claude-md/90-footer.md" \
        > "$TMPD/plain.block" 2>/dev/null || true
      if [ -f "$STYLE_FRAG" ]; then
        cat "$REPO/templates/claude-md/00-header.md" "$REPO/templates/claude-md/10-core.md" \
          "$REPO/templates/claude-md/20-verification.md" "$STYLE_FRAG" \
          "$REPO/templates/claude-md/90-footer.md" > "$TMPD/style.block" 2>/dev/null || true
      else
        : > "$TMPD/style.block"
      fi
      POLICY_MSG="policy block is customized or stale (differs from the selected source assembly); if you customized it, this is expected; if not, re-run install"
      case "$WS" in
        yes)
          if cmp -s "$TMPD/installed.block" "$TMPD/style.block"; then
            ok "policy block matches source assembly (with working-style)"
          else
            warn "$POLICY_MSG"
          fi
          ;;
        no)
          if cmp -s "$TMPD/installed.block" "$TMPD/plain.block"; then
            ok "policy block matches source assembly (default)"
          else
            warn "$POLICY_MSG"
          fi
          ;;
        *)
          if cmp -s "$TMPD/installed.block" "$TMPD/plain.block" || cmp -s "$TMPD/installed.block" "$TMPD/style.block"; then
            ok "policy block matches a source assembly"
            warn "manifest incomplete (no working_style); re-run install to record it"
          else
            warn "$POLICY_MSG"
            warn "manifest incomplete (no working_style); re-run install to record it"
          fi
          ;;
      esac
    fi
  elif [ "$MARKERS_OK" != "1" ]; then
    warn "policy comparison skipped (marker pair not exactly 1/1)"
  elif [ -z "$TMPD" ]; then
    warn "policy comparison skipped (mktemp unavailable)"
  fi
fi

# hook commands in settings that reference pathfinder helpers: the target
# must be a regular executable file that is not writable by others.
# settings-derived command strings are never printed.
if [ -f "$SETTINGS" ]; then
  if command -v jq >/dev/null 2>&1; then
    CMDS="$(jq -r '.hooks // {} | .[]? | .[]? | .hooks? // [] | .[]? | .command? // empty' "$SETTINGS" 2>/dev/null || true)"
    for s in $PF_SCRIPTS; do
      printf '%s\n' "$CMDS" | grep -q "$s" || continue
      p="$PF_BIN/$s"
      if [ ! -f "$p" ] || [ -h "$p" ]; then
        warn "settings reference $s in a hook command but it is missing or a symlink; the configured hook command cannot run"
        continue
      fi
      if [ ! -x "$p" ]; then
        warn "settings reference $s in a hook command but it is not executable; the configured hook command cannot run"
        continue
      fi
      if [ "$MODE_OK" = "1" ]; then
        M="$(get_mode "$p" 2>/dev/null || true)"
        if [ -n "$M" ] && gw_writable "$M"; then
          warn "hook helper $s is group/world writable (mode $M); it cannot be trusted; fix its permissions"
        fi
      fi
      if [ "$SOURCE_OK" = "1" ] && [ -f "$REPO/scripts/$s" ]; then
        if ! cmp -s "$REPO/scripts/$s" "$p"; then
          warn "referenced hook helper $s differs from the local checkout; re-run install to sync"
        fi
      fi
    done
  else
    warn "exact hook-reference validation skipped (jq not available)"
  fi
fi

echo "---"
if [ "$FAILS" -gt 0 ]; then
  echo "result: $FAILS failure(s)"
  exit 1
fi
echo "result: ok"
exit 0
