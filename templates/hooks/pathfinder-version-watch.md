# Pathfinder version-watch hook

Best-effort tripwire only. It notices Claude Code version bumps and injects a revalidation reminder at session start. It is not a docs-drift detector and does not verify anything itself.

Facts below are taken from the Claude Code hooks reference: https://code.claude.com/docs/en/hooks (fetched 2026-07-11).

## Requirements

- Claude Code **v2.1.198** or later (pathfinder minimum).
- POSIX shell for `scripts/pathfinder-version-watch.sh` (macOS, Linux, WSL).
- The `claude` binary on PATH in the hook environment. Hook payloads carry no version field and there is no version environment variable, so the script runs `claude --version` itself.

## How it works

The script keeps the last-seen version in `~/.claude/pathfinder/last-version`.

- First run: records the current version silently and never fires.
- Version unchanged: exits silently.
- Version changed: updates the state file and prints a short notice to stdout. For `SessionStart`, stdout "is added as context for Claude", so the session starts with the reminder in view and Claude can offer to run the revalidation checklist (`docs/REVALIDATION.md` in the pathfinder repo).
- Any failure (missing binary, unparseable output, unwritable state): exits 0 silently. A broken watcher must never block a session.

## Install

Copy the script to a stable path, same convention as the log helper:

```sh
mkdir -p ~/.claude/pathfinder/bin
cp scripts/pathfinder-version-watch.sh ~/.claude/pathfinder/bin/
chmod +x ~/.claude/pathfinder/bin/pathfinder-version-watch.sh
```

Merge a `hooks` entry into `~/.claude/settings.json` (merge key by key; do not rewrite unrelated settings):

```json
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "startup",
        "hooks": [
          {
            "type": "command",
            "command": "$HOME/.claude/pathfinder/bin/pathfinder-version-watch.sh",
            "timeout": 5
          }
        ]
      }
    ]
  }
}
```

Wiring notes:

- Matcher is `"startup"` only. Documented `SessionStart` matchers are `startup`, `resume`, `clear`, and `compact`; restricting to `startup` keeps the notice from re-firing mid-work after `/clear`, compaction, or a resume.
- Synchronous on purpose (no `async`). Stdout-as-context requires the hook to complete before the session proceeds. The cost is roughly one second to spawn `claude --version`; the `timeout` of 5 seconds bounds the worst case.

## Limits (document these to users)

- Detects version bumps only, not documentation changes. Behavior changes normally ship with a version, but nothing guarantees it.
- A version bump does not mean anything pathfinder uses actually changed. The notice is a prompt to check, not a finding.
- Missed runs are normal if hooks are disabled, fail, time out, or run on a platform without a POSIX shell.
- First run after install records silently; the hook only fires from the second version onward.
