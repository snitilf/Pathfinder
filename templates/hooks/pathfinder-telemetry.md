# Pathfinder telemetry hooks

Best-effort orchestration telemetry only. Not an audit trail, not a complete session record, not session history.

Field and option claims below are taken from the Claude Code hooks reference: https://code.claude.com/docs/en/hooks (fetched 2026-07-11). The log helper null-defaults any missing field; do not invent values the payload omits.

## Requirements

- Claude Code **v2.1.198** or later (pathfinder minimum).
- POSIX shell for `scripts/pathfinder-log.sh` (macOS, Linux, WSL). Native Windows without a POSIX shell: leave hooks uninstalled or adapt the command yourself; auto-logging is optional.
- Install the helper to a stable path, for example `~/.claude/pathfinder/bin/pathfinder-log.sh`, then point hooks at it.

## Events (documented names)

From the hooks reference event table:

| Event | Doc wording | Useful fields on stdin JSON (documented) |
|---|---|---|
| `SubagentStart` | "When a subagent is spawned" | `session_id` (common input), `hook_event_name`, `agent_id`, `agent_type` (SubagentStart input section) |
| `SubagentStop` | "When a subagent finishes" | same common fields, plus `agent_id`, `agent_type`, `agent_transcript_path`, `last_assistant_message` (SubagentStop input section) |
| `SessionEnd` | "When a session terminates" | `session_id` (common), `hook_event_name`, `reason` (SessionEnd input section) |

### Citations for fields

| Field | Where documented |
|---|---|
| `session_id` | Hooks reference, "Common input fields": current session identifier |
| `hook_event_name` | Present in SubagentStart / SubagentStop / SessionEnd JSON examples in the same page |
| `agent_id` | Common subagent fields and SubagentStart input: unique identifier for the subagent |
| `agent_type` | SubagentStart / SubagentStop input: agent name the matcher filters on (frontmatter `name` for custom agents) |
| `last_assistant_message` | SubagentStop input: text content of the subagent's final response |
| `agent_transcript_path` | SubagentStop input: subagent's own transcript path (nested under `subagents/`) |
| `reason` | SessionEnd input: why the session ended |

Do not invent token counts or duration. Duration is not listed on these events; the helper does not invent it. If a field is absent in your installed Claude Code version, the helper records null.

## Install into user settings

Merge a `hooks` object into `~/.claude/settings.json` (merge key by key; do not rewrite unrelated settings). Example:

```json
{
  "hooks": {
    "SubagentStart": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "$HOME/.claude/pathfinder/bin/pathfinder-log.sh",
            "timeout": 5,
            "async": true
          }
        ]
      }
    ],
    "SubagentStop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "$HOME/.claude/pathfinder/bin/pathfinder-log.sh",
            "timeout": 5,
            "async": true
          }
        ]
      }
    ],
    "SessionEnd": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "$HOME/.claude/pathfinder/bin/pathfinder-log.sh",
            "timeout": 3,
            "async": true
          }
        ]
      }
    ]
  }
}
```

### Citation for `async`

Hooks reference, command hook fields:

> `async` (optional): If `true`, runs in the background without blocking. See "Run hooks in the background".

`SessionEnd` has a short default timeout budget; keep the helper cheap. Prefer `async: true` so logging never blocks the agent loop.

## Limits (document these to users)

- Events can be missed if hooks are disabled, fail, time out, or run on an unsupported platform.
- Logs live under `~/.claude/pathfinder/logs/YYYY-MM-DD.jsonl` and may be empty.
- This is best-effort orchestration telemetry (which subagent started/stopped, session end). It is not ground truth of every tool call.
- A broken log path must not break a session: the helper soft-fails.

## If hooks cannot be installed

Ship diagnostics only (`scripts/pathfinder-diag.sh` / install runbook diagnostics). Do not instruct the orchestrator to append JSONL after each delegation.
