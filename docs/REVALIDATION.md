# Revalidation checklist

Pathfinder's coupling to Claude Code is a small, enumerable surface: model aliases, settings keys, hook events and payload fields, subagent frontmatter, and agent discovery. Everything else in the repo is role-based policy prose that no Claude Code update can break. Re-run this checklist when Claude Code updates; the optional version-watch hook (`templates/hooks/pathfinder-version-watch.md`) injects a reminder at session start when the version changes. The install places a reference copy of this file at `~/.claude/pathfinder/REVALIDATION.md` so any session can read it; fixes are applied in the repo checkout, because the update targets below are repo files.

Claims below were last verified 2026-07-11 against the linked pages (see `docs/VERIFICATION-REPORT.md` section 1 for the quoted wording).

## Claims

| # | Claim | Source | Update together if it drifts |
|---|---|---|---|
| a | Alias `best` resolves to Fable 5 where the organization has access, otherwise the latest Opus model | https://code.claude.com/docs/en/model-config (model aliases table) | `templates/settings.snippet.json`, `README.md`, `install/AGENT-INSTALL.md` |
| b | `fallbackModel` is set in settings as a JSON array of aliases or model names | same page, fallback model chains | `templates/settings.snippet.json`, `install/AGENT-INSTALL.md` |
| c | Hook events `SubagentStart`, `SubagentStop`, `SessionEnd` exist with fields `session_id`, `agent_id`, `agent_type`, `last_assistant_message`, `agent_transcript_path`, `reason` | https://code.claude.com/docs/en/hooks | `templates/hooks/pathfinder-telemetry.md`, `scripts/pathfinder-log.sh` |
| d | Command hooks support `async: true` | same hooks page, command hook fields | `templates/hooks/pathfinder-telemetry.md` |
| e | Subagent frontmatter supports `model`, `effort`, `disallowedTools` | https://code.claude.com/docs/en/sub-agents | `templates/agents/*.md`, `install/AGENT-INSTALL.md` preflight |
| f | Built-in Explore inherits the main-session model unless overridden (pathfinder pins it to haiku) | https://code.claude.com/docs/en/sub-agents and https://code.claude.com/docs/en/model-config | `templates/agents/Explore.md`, `docs/design.md` |
| g | Minimum Claude Code version claim is **2.1.198** | preflight rationale in the install runbook | `install/AGENT-INSTALL.md`, `templates/hooks/*.md`, `README.md` |
| h | Agent discovery scans `~/.claude/agents/` recursively and requires unique `name:` values across the whole tree | https://code.claude.com/docs/en/sub-agents | `install/AGENT-INSTALL.md` preflight, `scripts/pathfinder-diag.sh` |
| i | The subagent transcript JSONL carries `message.id`, `message.model`, and `message.usage.{output_tokens, input_tokens, cache_read_input_tokens, cache_creation_input_tokens}`, with multiple snapshot lines sharing one `message.id` (the final snapshot holds the final counts) | https://code.claude.com/docs/en/hooks (transcript format) | `scripts/pathfinder-log.sh`, `templates/hooks/pathfinder-telemetry.md` |

Claim (i) is a new coupling surface added in v1.2.0 and has not yet had a live re-verification pass against the linked page; treat it as needing confirmation on the next revalidation run, not as already checked to the same standard as (a)-(h).

Also covered here: pin compliance in `scripts/pathfinder-stats.sh` maps the alias pinned in agent frontmatter (`haiku`, `sonnet`, `opus`) to the concrete model id observed in a transcript (for example `haiku` to `claude-haiku-4-5-*`) by family prefix, because haiku ids carry a date suffix and the others do not, so there is no single normalization rule. This mapping rides on the same frontmatter and hooks claims as (e) and (c) above; if the alias table or the id format changes, update `scripts/pathfinder-stats.sh` in the same pass.

Rules for applying drift:

- Update every file in the row in one pass so the snippet, runbook, and docs cannot disagree.
- If an alias disappears (for example `best`), pick the documented replacement and update the graceful-degradation story with it, not around it.
- If a hook field disappears, remove it from the telemetry doc table. The log helper now also extracts `models` and the four token fields from the transcript at `agent_transcript_path` (row i); adding, removing, or renaming any of those extraction keys is itself a drift event against row (i) and requires updating `scripts/pathfinder-log.sh` and `templates/hooks/pathfinder-telemetry.md` together, not just a null-default check.
- Never patch a claim by loosening its wording. Either the docs still support it or the row drifts.

## How to run this

Paste into a fresh Claude Code session from the pathfinder repo root:

> Fetch https://code.claude.com/docs/en/model-config, https://code.claude.com/docs/en/hooks, and https://code.claude.com/docs/en/sub-agents. Check every claim in the table in docs/REVALIDATION.md against the current wording, including model aliases and fallbackModel, hook schemas, subagent frontmatter fields, recursive agent discovery, Explore override behavior, and the minimum-version assumption. Report each claim as HOLDS or DRIFTED with the quoted evidence. For each drifted claim, update all files listed in its row together in one pass, then update the "last verified" date at the top of docs/REVALIDATION.md. Do not commit; list the changed files when done.
