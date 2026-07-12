# Changelog

All notable changes to pathfinder. Installed version is stamped in `~/.claude/CLAUDE.md` (`<!-- pathfinder vX.Y.Z -->`) and `~/.claude/pathfinder/VERSION`.

## v1.1.0 - 2026-07-12

Update mechanics, documentation, and installation trust boundary. The Claude Code documentation claims themselves were not re-verified in this release; the revalidation checklist keeps its prior date.

| Change | Notes |
|---|---|
| Install manifest | `~/.claude/pathfinder/INSTALL` (schema 1, key=value): repo path, ref, resolved `source_commit`, version, working-style choice; written atomically with private modes |
| Installed checklist copy | `docs/REVALIDATION.md` copied to `~/.claude/pathfinder/` so any session can read it |
| Version-watch notice hardened | 4-5 validated lines; installed checklist path; repo line only for a verified usable checkout; malformed state never reaches output |
| Drift diagnostics | `pathfinder-diag.sh` compares installed files against the local checkout: version ordering (update available vs checkout behind vs unorderable), byte drift on agents, helpers, checklist, and policy assembly; warn-only |
| Recursive agent discovery | Preflight and diagnostics scan `~/.claude/agents/` recursively; duplicate or nested pathfinder `name:` claims are failures; frontmatter-only parsing |
| Hook helper integrity | Referenced hook helpers must be regular executable files not writable by others; structural settings parsing via jq with an explicit skip note without it |
| Update and repair flow | Complete state machine (newer / equal / older / unorderable source); same-version integrity check and approval-gated repair heals pre-1.1.0 installs |
| Write discipline | Symlink-safe atomic writes for every pathfinder-owned file and parent directory; private backup dir `~/.claude/backups/pathfinder/` |
| Source binding | Clean-worktree requirement for source-based writes; commit re-check immediately before writing; zero writes on mismatch |
| Sanitized output | Diagnostics and the session-start notice never print raw values from mutable local files |
| README | Rewritten as a first-time-user onboarding page with an explicit security and trust section |
| Revalidation checklist | Adds the sub-agents documentation page and a recursive-discovery claim; runnable prompt covers all three doc pages |

## v1.0.0 - 2026-07-11

Initial release of pathfinder: a Claude Code multi-model orchestration configuration layer (role agents, policy, settings, optional hooks).

| Change | Notes |
|---|---|
| Markers and install paths | `pathfinder:begin/end`, install under `~/.claude/pathfinder/` |
| Seven roles | scout, Explore, mech-executor, executor, light-verifier, verifier, security-executor |
| Tiered verification policy | none / light / standard / heavy in default policy |
| Modular default policy | header + core + verification + footer; working-style opt-in only |
| Install / update / uninstall runbook | Plan-then-approve as a convention; idempotent upgrade; collision handling |
| Diagnostics | `scripts/pathfinder-diag.sh` (POSIX, optional) |
| Best-effort telemetry | Hooks for SubagentStart, SubagentStop, SessionEnd + `pathfinder-log.sh`; not an audit trail |
| Optional `.pathfinder/config.json` | Hint schema only; no project policy merge |
| Minimum Claude Code | v2.1.198 (preflight) |
| Settings snippet | `model: best`, `fallbackModel: [opus, sonnet]` (revalidated) |
