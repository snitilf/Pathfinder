# Changelog

All notable changes to pathfinder. Installed version is stamped in `~/.claude/CLAUDE.md` (`<!-- pathfinder vX.Y.Z -->`) and `~/.claude/pathfinder/VERSION`.

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
