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

On `SubagentStop` only, the helper also reads the transcript at `agent_transcript_path` and appends five more fields to the log line: `models`, `output_tokens`, `input_tokens`, `cache_read_tokens`, `cache_creation_tokens`. All five are `null` when unavailable: any other event, a missing or unreadable transcript, a transcript with zero qualifying usage lines, or jq absent. `models` is otherwise a sorted, distinct, non-empty array of model strings; it is never `[]`.

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
| `message.id` (transcript) | Subagent transcript JSONL: identifies one assistant message; a message can appear across several streaming snapshot lines, so extraction dedups by this key (max per field) before summing |
| `message.model` (transcript) | Subagent transcript JSONL: the model that produced the assistant message; source of the `models` field |
| `message.usage.output_tokens` (transcript) | Subagent transcript JSONL: per-message output token count |
| `message.usage.input_tokens` (transcript) | Subagent transcript JSONL: per-message input token count |
| `message.usage.cache_read_input_tokens` (transcript) | Subagent transcript JSONL: per-message cache-read token count |
| `message.usage.cache_creation_input_tokens` (transcript) | Subagent transcript JSONL: per-message cache-creation token count |

Do not invent values. Read token counts and models from `agent_transcript_path`; when the transcript is absent, unreadable, or carries no qualifying usage lines, record null, never a fabricated value. Duration is still not recorded: it is not listed on these events and the helper does not invent it. If a field is absent in your installed Claude Code version, the helper records null.

Privacy: extraction reads only the model string (`message.model`) and integer token counts (`message.usage.*`) out of the transcript. No prompt text, no source code, and no transcript prose ever enters the log line.

A run whose `models` array holds more than one entry is a **multi-model run**, not a "fallback". A run can span models either because `fallbackModel` triggered, or because an unpinned agent picked up a mid-session `/model` change; telemetry records the set observed and cannot tell which case produced it. Report the set and let a human judge; do not label it fallback.

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
