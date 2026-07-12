# pathfinder - Agent Install Runbook

This document is for an AI agent (Claude Code) installing pathfinder on a user's machine. Follow the steps in order. Prefer merging over overwriting. A human can follow the same steps by hand.

## Minimum version

**Claude Code v2.1.198 or later.**

Why: as of 2.1.198 the built-in Explore agent inherits the main-session model (pathfinder overrides it to haiku), subagent frontmatter for `model` / `effort` / `disallowedTools` is required behavior, and the product surface pathfinder targets is documented from that line forward.

Preflight must detect the version. If undetectable, stop and say so clearly. If below minimum, refuse install (or hard-warn and require explicit user override).

Revalidated against Claude Code docs (2026-07): model aliases include `best`, `opus`, `sonnet`, `haiku`, `fable`; settings keys `model` and `fallbackModel` (array); hooks `SubagentStart`, `SubagentStop`, `SessionEnd`, `SessionStart`.

## What you are installing

pathfinder is a global multi-model orchestration layer for Claude Code. Configuration only, not a runtime product. It touches:

| Target | Change |
|---|---|
| `~/.claude/settings.json` | Prefer `model: "best"`, add `fallbackModel`, optionally extend `availableModels`, optionally merge telemetry and version-watch hooks |
| `~/.claude/agents/` | Seven role files: scout, Explore, mech-executor, executor, verifier, light-verifier, security-executor |
| `~/.claude/CLAUDE.md` | One `## Orchestration` block between `<!-- pathfinder:begin -->` and `<!-- pathfinder:end -->` |
| `~/.claude/pathfinder/` | `VERSION`, `INSTALL` manifest, `REVALIDATION.md` copy, optional `bin/` helpers, `logs/` |
| `~/.claude/backups/pathfinder/` | Private backup directory for pre-change copies |

Source of truth: this repository's `templates/` and `scripts/`. Local clone preferred; otherwise fetch from the same ref (tag or SHA) the user named. Never fall back to `main` when the user pinned a ref.

## Security and trust (state the caveats to the user)

- Pathfinder installs executable hook scripts and global Claude Code configuration. The user should review the source before installing.
- Use a trusted local checkout or a pinned commit. A branch name is not an immutable security pin; when the user names a tag, resolve and record its full commit at install time (`source_commit` in the manifest).
- Never run installation, update, diagnostics, or hook setup with sudo or as another user.
- Any process able to modify `~/.claude/` can alter hooks, agents, or instructions. This is a local-account trust boundary, not a sandbox.
- Pathfinder does not grant permissions, enable bypass-permissions mode, weaken `permissions.deny`, or override managed, project, or local settings. Never add or modify `permissions.allow`, `permissions.deny`, `defaultMode`, `bypassPermissions`, or `skipDangerousModePermissionPrompt`.
- The approval gate below is **a convention this runbook asks agents to follow**, not a technical enforcement boundary. A non-compliant agent or user can always write files.

## Write discipline (applies to every pathfinder-owned write)

Applies to: `INSTALL`, `VERSION`, the `REVALIDATION.md` copy, installed bin scripts, newly created root agent files, and backups.

1. **Parent directories first.** Every pathfinder-owned directory component must be a real directory, not a symlink: `~/.claude/pathfinder/`, `~/.claude/pathfinder/bin/`, `~/.claude/pathfinder/logs/`, `~/.claude/backups/pathfinder/`, and `~/.claude/agents/` when creating a root agent. If any component is a symlink, stop and ask the user to resolve it; never write through it.
2. **Destination file.** If the destination exists and is a symlink, stop and ask; never replace or write through a symlink.
3. **Atomic replace.** Create a uniquely named temporary regular file in the target directory under `umask 077` (for example `mktemp "$dir/name.XXXXXX"`), write the content, set the intended mode (600 for data, 700 for scripts the user runs), then `mv` it over the destination. Remove the temp file on every failure path.
4. **Private modes.** Every pathfinder-created directory is mode 700. Backups live under `~/.claude/backups/pathfinder/` (created 700) so no permissions change is needed on the shared `~/.claude/backups/`; settings backups can contain sensitive configuration and get mode 600.
5. **Mode checks.** Where a permission mode must be read, use `stat -f %Lp <path>` (BSD) or `stat -c %a <path>` (GNU); if neither works, state that the mode check was skipped. Never parse `ls -l`.

## Source binding (git checkouts)

- Diagnostics may inspect a dirty checkout; read-only comparison is fine.
- **Every source-based install, upgrade, or repair write requires a clean git worktree.** If the checkout is dirty, stop before asking for approval and ask the user to commit, stash, or point at a separate immutable checkout.
- Resolve the full commit before presenting the plan: `git -C "$repo" rev-parse HEAD`. Record it as `source_commit`.
- Immediately before every write, re-check all of: HEAD equals the recorded commit; `git -C "$repo" diff --quiet`; `git -C "$repo" diff --cached --quiet`; and `git -C "$repo" status --porcelain -- templates scripts docs install VERSION` is empty. Any mismatch: make **zero writes**, regenerate the diffs and the plan, and obtain approval again.
- Non-git sources: no commit binding is possible; say so in the plan ("immutable source binding unavailable").

## Portability

Prefer Read / Write / Edit tools over shell for file ops. Shell helpers under `scripts/` are **POSIX-only** (macOS, Linux, WSL). Native Windows without a POSIX shell is runbook-only: skip shell helpers, use file tools, validate JSON yourself if `jq` is missing.

## Updating an existing install

When the user asks to **update**, detect the installed version (from `<!-- pathfinder vX.Y.Z -->` in `~/.claude/CLAUDE.md` or `~/.claude/pathfinder/VERSION`) and the source version (repo `VERSION`), then branch:

| Source vs installed | Behavior |
|---|---|
| Source newer | Show changelog entries between installed and latest, then run Steps 1-4 after approval |
| Source equal | Run the read-only **integrity check** below; report "current and intact" and stop, or present a **repair plan** and get approval |
| Source older | **Stop.** Explain that the local checkout predates the installation. Do not apply source-based repairs or copy bytes from the older source |
| Version unorderable (either VERSION malformed) | **Stop source-based updates.** Report the problem; require a usable checkout or explicit user direction |

**Integrity check (source equal):** manifest present, parseable, schema supported, and its `version` matches installed VERSION; checklist copy present; every root agent present; every hook helper referenced by settings hooks present and executable.

**Repair scope (only with approval, and only from a clean worktree):**

- Missing expected root agent: offer to create it only after a tree-wide collision check for that `name:` anywhere under `~/.claude/agents/` (collision: report, do not create).
- Existing-but-different agent: show the diff; never overwrite without explicit approval.
- Missing `VERSION`, checklist copy, `INSTALL`, or a settings-referenced executable hook helper: list each explicitly in the repair plan.
- Policy-block content drift: report only; never auto-repair (the user may have customized it).
- Source checkout unavailable: offer only repairs that need no source bytes; otherwise report.

This is also how pre-1.1.0 installs (no manifest, no checklist copy) heal when their version already matches the source.

## Step 1 - Preflight (read-only)

1. **Claude Code version:** run `claude --version`. Parse `x.y.z`. If missing or unparseable: **stop** ("version undetectable"). If `< 2.1.198`: **refuse** unless the user explicitly overrides in writing.
2. Read `~/.claude/settings.json` (note `model`, `fallbackModel`, `availableModels`, existing `hooks`). Missing file is fine (create later).
3. Read `~/.claude/CLAUDE.md` if present. Count `pathfinder:begin` / `pathfinder:end`.
4. **Scan `~/.claude/agents/` recursively** (Claude Code discovers agents in subdirectories too and requires unique `name:` values across the whole tree). Read frontmatter `name:` from every `.md` file at any depth; parse only the YAML frontmatter between the first `---` pair, never body text. Flag: duplicate names anywhere; any file (nested or root) claiming a pathfinder name: `scout`, `Explore`, `mech-executor`, `executor`, `verifier`, `light-verifier`, `security-executor`.
5. Check `CLAUDE_CODE_SUBAGENT_MODEL`. If set, flag it: it overrides every per-agent `model` frontmatter and defeats tiering. Recommend unset. Do not unset without approval.
6. Note whether hooks already reference pathfinder logging or version-watch.
7. If installing from a git checkout: check the worktree is clean (see Source binding). If dirty, stop here.

## Step 2 - Present the plan and get approval

Show a table of every change: file, create/merge/replace/skip, and backup line. **Do not write anything until the user approves.** This is a convention the runbook asks agents to follow, not a technical enforcement boundary. State that to the user once. Include the resolved `source_commit` in the plan when the source is a git checkout.

Also ask (default **no**): "Include the personal working-style policy section? Default is no (personal preferences should not become silent team-wide policy)."

Also ask (default **yes** if hooks are available on this version): "Install best-effort telemetry hooks (SubagentStart / SubagentStop / SessionEnd -> pathfinder-log.sh)?" If the user declines or the environment cannot run POSIX hooks, install diagnostics only and do not invent orchestrator self-logging.

Also ask: "Install the version-watch update reminder (SessionStart -> pathfinder-version-watch.sh)?"

## Step 3 - Apply (only after approval; re-verify source binding immediately before writing)

### 3.1 Backup and directories

Follow the Write discipline above for every step here.

```bash
umask 077
mkdir -p ~/.claude/backups/pathfinder ~/.claude/agents ~/.claude/pathfinder/logs ~/.claude/pathfinder/bin
# settings: first pathfinder install only - preserve pre-pathfinder state
ls ~/.claude/backups/pathfinder/settings.json.* >/dev/null 2>&1 || \
  cp ~/.claude/settings.json ~/.claude/backups/pathfinder/settings.json.$(date +%Y%m%d-%H%M%S) 2>/dev/null || true
# CLAUDE.md: every run
cp ~/.claude/CLAUDE.md ~/.claude/backups/pathfinder/CLAUDE.md.$(date +%Y%m%d-%H%M%S) 2>/dev/null || true
chmod 600 ~/.claude/backups/pathfinder/* 2>/dev/null || true
```

(Older installs may hold backups directly in `~/.claude/backups/` with a `*.pathfinder-*` suffix; leave those where they are.)

If settings did not exist pre-install, record that uninstall should **remove** the `model` key rather than restore a value.

### 3.2 settings.json - merge, key by key

Never rewrite the whole file. Never touch permission keys (see Security and trust).

| Key | Rule |
|---|---|
| `model` | If absent -> set `"best"`. If present and different -> **ask** (keep vs switch to `best`). `best` = Fable 5 when the org has access, else latest Opus. If already `"best"` -> no change. |
| `fallbackModel` | If absent -> `["opus", "sonnet"]` (overload/unavailability; distinct from `best` access fallback). If present -> leave and note. |
| `availableModels` | Only if the key already exists: ensure it contains `opus`, `sonnet`, `haiku`, and the chosen main-model value. If absent, do not add (absent = unrestricted). |
| `hooks` | Only what the user opted into: telemetry hooks per `templates/hooks/pathfinder-telemetry.md`, version-watch per `templates/hooks/pathfinder-version-watch.md`. Do not remove unrelated hooks. |

Validate JSON after edits.

### 3.3 Agent files

For each of the seven files in `templates/agents/`, target `~/.claude/agents/<same-name>.md`:

| Existing state | Action |
|---|---|
| Missing, no `name:` collision anywhere in the tree | Write |
| Exists, identical content | Skip |
| Exists, different content | Show diff; ask overwrite or keep. **Never silent clobber.** |
| Any file anywhere in the tree declares the same `name:` | Stop and ask |

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

All writes follow the Write discipline (symlink checks, atomic temp + rename, private modes).

- Write `~/.claude/pathfinder/VERSION` from repo `VERSION`.
- Copy `docs/REVALIDATION.md` to `~/.claude/pathfinder/REVALIDATION.md` **every run** (pathfinder-owned reference copy; plain overwrite via the atomic pattern).
- Write the `~/.claude/pathfinder/INSTALL` manifest, atomically:

```
schema=1
repo=<absolute canonical path: cd "$repo" && pwd -P>
ref=<the tag/branch the user named, if any; informational>
source_commit=<full commit from git rev-parse HEAD, git sources only>
version=<repo VERSION>
working_style=<yes|no per the user's choice>
installed_at=<YYYY-MM-DD>
```

  Omit `repo`, `ref`, and `source_commit` lines that do not apply (network installs, non-git sources). Exactly one line per key; readers treat duplicate keys as an invalid manifest.
- If telemetry opted in: copy `scripts/pathfinder-log.sh` to `~/.claude/pathfinder/bin/pathfinder-log.sh`, mode 700.
- If version-watch opted in: copy `scripts/pathfinder-version-watch.sh` the same way.
- Optionally copy `pathfinder-diag.sh` and `pathfinder-stats.sh` next to them (POSIX).

### 3.6 Project-local config

Do **not** write project files by default. Document only:

- Optional `.pathfinder/config.json` in a project root.
- Schema: `default_verification` (`none`|`light`|`standard`|`heavy`), `logging` (boolean).
- Discovery: if present, tools and docs may read it; the global install never merges project policy. Project behavior that must take effect belongs in native `.claude/` instructions and settings.

## Step 4 - Verify and hand off

1. Settings JSON parses; no permission keys were added or changed.
2. All seven agent files present under `~/.claude/agents/`; no `name:` collisions anywhere in the tree.
3. Exactly one `pathfinder:begin` and one `pathfinder:end` in `~/.claude/CLAUDE.md`.
4. Version stamp present; `~/.claude/pathfinder/VERSION` matches; `INSTALL` manifest present, parseable, and its `version` matches; checklist copy present.
5. Every hook helper referenced by settings hooks exists and is executable (mode not group/world writable).
6. Tell the user to **restart** Claude Code (agents directory scan / model setting).
7. After restart: `/model` should show the default; ask which subagent types are available (expect seven pathfinder roles).
8. Optionally run `pathfinder-diag.sh`.
9. Summarize changes, skips, backups, which hooks were installed, and that JSONL is best-effort orchestration telemetry only (may be empty).

## Uninstall

On request:

1. Delete the seven pathfinder agent files only if content matches templates or user confirms after diff.
2. Remove the pathfinder begin..end block from `~/.claude/CLAUDE.md`; delete the file only if empty and user confirms.
3. Settings: restore `model` from the **oldest** settings backup under `~/.claude/backups/pathfinder/` (or legacy `~/.claude/backups/settings.json.pathfinder-*`) if that backup had a model; else remove the pathfinder-set `model` if you set it. Remove `fallbackModel` only if the user wants. Remove pathfinder hook entries only if you installed them and the user wants them gone. Leave unrelated keys alone.
4. Remove `~/.claude/pathfinder/INSTALL`, `~/.claude/pathfinder/REVALIDATION.md`, and `~/.claude/pathfinder/last-version` when removing the version-watch hook.
5. Leave `~/.claude/pathfinder/logs` unless the user asks to delete logs.
6. Optionally remove `~/.claude/pathfinder/` entirely if empty of user data the user wants kept.

## Diagnostics checklist (mirrors pathfinder-diag.sh)

Health (failures):

- Claude version >= 2.1.198
- Marker counts 1/1 for pathfinder
- Seven root agents present; no duplicate `name:` anywhere under `~/.claude/agents/` (recursive); no nested file claiming a pathfinder role name

Health (warnings):

- settings.json parses; model / fallback noted
- CLAUDE_CODE_SUBAGENT_MODEL warning if set
- pathfinder VERSION and INSTALL manifest present, valid, and mutually consistent
- pathfinder-owned directories are real private directories (no symlinks, not group/world writable)
- Hook helpers referenced by settings hooks exist, are regular executable files, and are not writable by others
- Logs dir may be empty (normal)

Drift vs the local checkout (warnings only; requires a valid manifest with a usable `repo`):

- Repo VERSION vs installed VERSION: equal / update available / checkout predates install / unorderable
- Installed agents, helpers, checklist copy, and policy block byte-compared against the source; differences are reported as "customized or stale", never auto-fixed
