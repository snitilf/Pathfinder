# Changelog

All notable changes to pathfinder. Installed version is stamped in `~/.claude/CLAUDE.md` (`<!-- pathfinder vX.Y.Z -->`) and `~/.claude/pathfinder/VERSION`.

## v1.2.0 - 2026-07-18

Telemetry now answers what it exists to answer: which model a role ran on and what it cost. `pathfinder-stats.sh` turns that into routing, pin-compliance, and ungoverned-delegation reporting.

| Change | Notes |
|---|---|
| Log schema, five new fields | `SubagentStop` only: `models`, `output_tokens`, `input_tokens`, `cache_read_tokens`, `cache_creation_tokens`, read from the transcript at `agent_transcript_path`; existing six fields unchanged |
| Dedup by `message.id` | Multiple streaming snapshot lines share one message id; extraction takes the max per field per id, then sums across ids, instead of naive summing (naive summing inflated the input-side fields 140-240% and the output field 9.2%) |
| `<synthetic>` excluded | Synthetic error entries carry zero-usage lines and are excluded from `models` and from the sums; null/empty model strings excluded the same way |
| All-null on no data | Missing event type, missing or unreadable transcript, zero qualifying usage lines, or no jq: all five fields null, never `models: []` |
| `pathfinder-stats.sh`: routing table | `agent_type x models` with call counts and per-field token totals |
| `pathfinder-stats.sh`: pin compliance | Observed model matched to the frontmatter pin (`~/.claude/agents/*.md`) by alias-to-family prefix, not string equality; unrecognized aliases reported, never flagged as a violation |
| `pathfinder-stats.sh`: unattributed bucket | Empty-`agent_type` `SubagentStop` lines (roughly a third or more of the corpus and growing) reported as their own bucket, excluded from every role's compliance denominator, never hidden |
| `pathfinder-stats.sh`: schema buckets | `has("models")` distinguishes pre-v1.2.0 logs from v1.2.0 logs with a null transcript, so neither is misreported as the other |
| Version-watch notice | Folds the runnable revalidation command into the existing 4-5 line notice so acting on it is one paste |
| Roadmap pruned | Eval checklist adopted, external trace correlation folded in, several items dropped for no observed evidence; Change D (diag pin validation) cut and reasoned about in the roadmap rather than re-proposed |
| Usage-review methodology corrected | Pre/post spend comparison replaced with pin-compliance and counterfactual savings; dedup-by-`message.id` recorded as a required step after the review's own first-pass numbers were found wrong without it |

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
