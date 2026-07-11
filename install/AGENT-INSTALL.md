# pathfinder - Agent Install Runbook

This document is for an AI agent (Claude Code) installing pathfinder on a user's machine. Follow the steps in order. Prefer merging over overwriting. A human can follow the same steps by hand.

## Minimum version

**Claude Code v2.1.198 or later.**

Why: as of 2.1.198 the built-in Explore agent inherits the main-session model (pathfinder overrides it to haiku), subagent frontmatter for `model` / `effort` / `disallowedTools` is required behavior, and the product surface pathfinder targets is documented from that line forward.

Preflight must detect the version. If undetectable, stop and say so clearly. If below minimum, refuse install (or hard-warn and require explicit user override).

Revalidated against Claude Code docs (2026-07): model aliases include `best`, `opus`, `sonnet`, `haiku`, `fable`; settings keys `model` and `fallbackModel` (array); hooks `SubagentStart`, `SubagentStop`, `SessionEnd`.

## What you are installing

pathfinder is a global multi-model orchestration layer for Claude Code. Configuration only, not a runtime product. It touches:

| Target | Change |
|---|---|
| `~/.claude/settings.json` | Prefer `model: "best"`, add `fallbackModel`, optionally extend `availableModels`, optionally merge telemetry hooks |
| `~/.claude/agents/` | Seven role files: scout, Explore, mech-executor, executor, verifier, light-verifier, security-executor |
| `~/.claude/CLAUDE.md` | One `## Orchestration` block between `<!-- pathfinder:begin -->` and `<!-- pathfinder:end -->` |
| `~/.claude/pathfinder/` | `VERSION`, optional `bin/pathfinder-log.sh`, `logs/` |

Source of truth: this repository's `templates/` and `scripts/`. Local clone preferred; otherwise fetch from the same ref (tag or SHA) the user named. Never fall back to `main` when the user pinned a ref.

## Trust caveat (state this to the user)

The approval gate is **a convention the runbook asks agents to follow**, not a technical enforcement boundary. A non-compliant agent or user can always write files. Trust also requires reading the templates and preferably pinning a tag or commit.

## Portability

Prefer Read / Write / Edit tools over shell for file ops. Shell helpers under `scripts/` are **POSIX-only** (macOS, Linux, WSL). Native Windows without a POSIX shell is runbook-only: skip shell helpers, use file tools, validate JSON yourself if `jq` is missing.

## Updating an existing install

When the user asks to **update**:

1. Detect installed version from `<!-- pathfinder vX.Y.Z -->` in `~/.claude/CLAUDE.md`, or `~/.claude/pathfinder/VERSION`.
2. Fetch `VERSION` and `CHANGELOG.md` from the same ref you were invoked from.
3. If already current, say so and stop. Else show changelog entries between installed and latest, then proceed with Steps 1-4 after approval.
4. Never overwrite a customized agent without showing the diff and asking.

## Step 1 - Preflight (read-only)

1. **Claude Code version:** run `claude --version`. Parse `x.y.z`. If missing or unparseable: **stop** ("version undetectable"). If `< 2.1.198`: **refuse** unless the user explicitly overrides in writing.
2. Read `~/.claude/settings.json` (note `model`, `fallbackModel`, `availableModels`, existing `hooks`). Missing file is fine (create later).
3. Read `~/.claude/CLAUDE.md` if present. Count `pathfinder:begin` / `pathfinder:end`.
4. List `~/.claude/agents/`. Read frontmatter `name:` on **every** agent file. Flag collisions with pathfinder names: `scout`, `Explore`, `mech-executor`, `executor`, `verifier`, `light-verifier`, `security-executor`.
5. Check `CLAUDE_CODE_SUBAGENT_MODEL`. If set, flag it: it overrides every per-agent `model` frontmatter and defeats tiering. Recommend unset. Do not unset without approval.
6. Note whether hooks already reference pathfinder logging.

## Step 2 - Present the plan and get approval

Show a table of every change: file, create/merge/replace/skip, and backup line. **Do not write anything until the user approves.** This is a convention the runbook asks agents to follow, not a technical enforcement boundary. State that to the user once.

Also ask (default **no**): "Include the personal working-style policy section? Default is no (personal preferences should not become silent team-wide policy)."

Also ask (default **yes** if hooks are available on this version): "Install best-effort telemetry hooks (SubagentStart / SubagentStop / SessionEnd -> pathfinder-log.sh)?" If the user declines or the environment cannot run POSIX hooks, install diagnostics only and do not invent orchestrator self-logging.

## Step 3 - Apply (only after approval)

### 3.1 Backup and directories

```bash
mkdir -p ~/.claude/backups ~/.claude/agents ~/.claude/pathfinder/logs ~/.claude/pathfinder/bin
# settings: first pathfinder install only - preserve pre-pathfinder state
ls ~/.claude/backups/settings.json.pathfinder-* >/dev/null 2>&1 || \
  cp ~/.claude/settings.json ~/.claude/backups/settings.json.pathfinder-$(date +%Y%m%d-%H%M%S) 2>/dev/null || true
# CLAUDE.md: every run
cp ~/.claude/CLAUDE.md ~/.claude/backups/CLAUDE.md.pathfinder-$(date +%Y%m%d-%H%M%S) 2>/dev/null || true
```

If settings did not exist pre-install, record that uninstall should **remove** the `model` key rather than restore a value.

### 3.2 settings.json - merge, key by key

Never rewrite the whole file.

| Key | Rule |
|---|---|
| `model` | If absent -> set `"best"`. If present and different -> **ask** (keep vs switch to `best`). `best` = Fable 5 when the org has access, else latest Opus. If already `"best"` -> no change. |
| `fallbackModel` | If absent -> `["opus", "sonnet"]` (overload/unavailability; distinct from `best` access fallback). If present -> leave and note. |
| `availableModels` | Only if the key already exists: ensure it contains `opus`, `sonnet`, `haiku`, and the chosen main-model value. If absent, do not add (absent = unrestricted). |
| `hooks` | Only if user opted into telemetry: merge SubagentStart / SubagentStop / SessionEnd command hooks calling the installed log helper (see `templates/hooks/pathfinder-telemetry.md`). Do not remove unrelated hooks. |

Validate JSON after edits.

### 3.3 Agent files

For each of the seven files in `templates/agents/`, target `~/.claude/agents/<same-name>.md`:

| Existing state | Action |
|---|---|
| Missing, no `name:` collision | Write |
| Exists, identical content | Skip |
| Exists, different content | Show diff; ask overwrite or keep. **Never silent clobber.** |
| Different file declares same `name:` | Stop and ask |

`Explore` shadowing the built-in Explore agent is intentional (pin to haiku).

### 3.4 CLAUDE.md policy block - one active orchestration block

Assemble default policy **only** from:

1. `templates/claude-md/00-header.md`
2. `templates/claude-md/10-core.md`
3. `templates/claude-md/20-verification.md`
4. `templates/claude-md/90-footer.md`

If the user opted into working-style, append `templates/claude-md/60-working-style.md` **before** the footer (still inside the begin/end pair). Default assembly **excludes** working-style.

#### Marker install / upgrade (precise)

Count `pathfinder:begin` and `pathfinder:end`.

| Condition | Action |
|---|---|
| begin or end count `>1`, or counts unequal (unmatched pair), or overlapping/ambiguous blocks | **Stop and ask.** Never greedy multi-block replace. |
| Exactly one begin and one end (one pair) | Replace exactly that pathfinder begin..end block with the new assembly (idempotent upgrade). |
| Both counts `0`; file missing | Create file with assembled block. |
| Both counts `0`; file exists | Append assembled block at end (or after first heading). |

**Invariant after install:** exactly one active pathfinder orchestration block (one begin and one end).

Do not modify content outside the markers you are replacing/removing.

### 3.5 pathfinder home

- Write `~/.claude/pathfinder/VERSION` from repo `VERSION`.
- If telemetry opted in: copy `scripts/pathfinder-log.sh` to `~/.claude/pathfinder/bin/pathfinder-log.sh`, `chmod +x`.
- Optionally copy `pathfinder-diag.sh` and `pathfinder-stats.sh` next to it (POSIX).
- Second, separate opt-in: the version-watch hook. Same pattern - copy its script to `~/.claude/pathfinder/bin/`, `chmod +x`, and add a `SessionStart` hook entry per `templates/hooks/pathfinder-version-watch.md`.

### 3.6 Project-local config

Do **not** write project files by default. Document only:

- Optional `.pathfinder/config.json` in a project root.
- Schema: `default_verification` (`none`|`light`|`standard`|`heavy`), `logging` (boolean).
- Discovery: if present, tools and docs may read it; the global install never merges project policy. Project behavior that must take effect belongs in native `.claude/` instructions and settings.

## Step 4 - Verify and hand off

1. Settings JSON parses.
2. All seven agent files present under `~/.claude/agents/`.
3. Exactly one `pathfinder:begin` and one `pathfinder:end` in `~/.claude/CLAUDE.md`.
4. Version stamp present; `~/.claude/pathfinder/VERSION` matches.
5. Tell the user to **restart** Claude Code (agents directory scan / model setting).
6. After restart: `/model` should show the default; ask which subagent types are available (expect seven pathfinder roles).
7. Optionally run `pathfinder-diag.sh`.
8. Summarize changes, skips, backups, whether hooks were installed, and that JSONL is best-effort orchestration telemetry only (may be empty).

## Uninstall

On request:

1. Delete the seven pathfinder agent files only if content matches templates or user confirms after diff.
2. Remove the pathfinder begin..end block from `~/.claude/CLAUDE.md`; delete the file only if empty and user confirms.
3. Settings: restore `model` from the **oldest** `settings.json.pathfinder-*` backup if that backup had a model; else remove the pathfinder-set `model` if you set it. Remove `fallbackModel` only if the user wants. Remove pathfinder hook entries only if you installed them and the user wants them gone. Leave unrelated keys alone.
4. Leave `~/.claude/pathfinder/logs` unless the user asks to delete logs.
5. Optionally remove `~/.claude/pathfinder/` entirely if empty of user data the user wants kept.

## Diagnostics checklist (mirrors pathfinder-diag.sh)

- Claude version >= 2.1.198
- settings.json parses; model / fallback noted
- CLAUDE_CODE_SUBAGENT_MODEL warning if set
- Marker counts 1/1 for pathfinder
- Seven agents; no duplicate `name:` frontmatter
- pathfinder VERSION present
- Hooks mentioned only if telemetry installed
- Logs dir may be empty (normal)
