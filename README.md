![pathfinder](docs/assets/pathfinder.png)

Pathfinder is **global configuration for [Claude Code](https://code.claude.com)**. It is not a standalone CLI, not a runtime, not a model router, and not an enforcement system. You install a set of plain files under `~/.claude/` (agent definitions, a policy text block, a couple of settings keys, optional shell hooks), and Claude Code reads them the same way it reads any other configuration.

## The problem it solves

If one frontier model handles an entire coding session, most of your subscription quota goes to work that never needed frontier reasoning: searching files, running tests, bulk edits, documentation. Pathfinder gives Claude Code **delegation guidance and specialist roles** so the expensive model spends its effort where judgment matters and cheaper models carry the volume. Claude Code itself decides whether to delegate on any given task, based on the agent descriptions and the policy text; pathfinder shapes those decisions, it does not force them.

## How one task flows

Say you ask for a bug fix in an unfamiliar part of the codebase:

1. The **main session** (your chosen model) reads the request and plans.
2. It sends reconnaissance to `scout` or `Explore`, low-cost roles that locate the relevant files and report back with `file:line` findings.
3. The fix itself goes to `executor` (judgment work) or `mech-executor` (fully-specified mechanical work), depending on what the plan calls for.
4. Before reporting done, an independent **verifier** with fresh context tries to refute the claim that the fix works. Verifiers never fix anything; they return CONFIRMED or REFUTED with evidence.

Anything security-sensitive (auth, secrets, crypto, validation) is routed to `security-executor` instead of running in the main session.

## What you get

- Seven specialist roles with model and effort set per role (see table below).
- A policy block that tells the orchestrating session when to delegate, when not to, and how much verification each kind of work needs.
- Tiered verification: none / light / standard / heavy.
- Optional local telemetry (which subagent started and stopped, session end) and an optional update reminder.
- An install runbook with diagnostics, updates, and uninstall.

| Role | Model alias | Effort | Used for |
|---|---|---|---|
| `scout` | haiku | low | Read-only lookups |
| `Explore` | haiku | low | Overrides the built-in Explore (pins cheap recon) |
| `mech-executor` | sonnet | low | Fully-specified mechanical work |
| `executor` | opus | medium | Implementation needing judgment |
| `light-verifier` | sonnet | low | Light check of mechanical work |
| `verifier` | opus | medium | Standard and heavy verification |
| `security-executor` | opus | high | Security-sensitive work |

| Verification level | Role | When |
|---|---|---|
| none | - | Trivial work the user skips |
| light | `light-verifier` | Mechanical `mech-executor` output |
| standard | `verifier` | Judgment / multi-file features |
| heavy | `verifier` (exhaustive) | Security, auth, secrets, crypto, financial |

Model names never appear in the policy prose, only role names. Each role's model binding lives in one place (its file's frontmatter), so a model generation change is a one-line edit per role.

## Prerequisites

- Claude Code **v2.1.198 or later**.
- A POSIX shell (macOS, Linux, WSL) only if you want the optional helper scripts (diagnostics, telemetry, update reminder). The configuration itself works anywhere Claude Code runs.
- A restart of Claude Code may be needed after install, because the agents directory is scanned at startup.

## What it changes, and what it does not

Installed under `~/.claude/`:

| Path | What lands there |
|---|---|
| `settings.json` | Adds a `fallbackModel` chain; proposes `model: "best"` only with your approval; merges optional hook entries. Unrelated keys untouched. |
| `agents/` | Seven role files. |
| `CLAUDE.md` | One clearly marked policy block between `pathfinder:begin` and `pathfinder:end` markers. Text outside the markers is never touched. |
| `pathfinder/` | Version stamp, install manifest, checklist copy, optional helper scripts, optional logs. |

It does **not** modify project files by default, does not grant permissions, does not enable bypass-permissions mode, does not weaken `permissions.deny`, and does not override managed, project, or local settings. The installer shows you a plan and waits for approval before writing; that approval gate is a convention the runbook asks agents to follow, not a technical enforcement boundary.

## Install

```text
Read install/AGENT-INSTALL.md from this pathfinder checkout
and follow it to install pathfinder into my global Claude Code configuration.
Show me the full plan of changes and get my approval before writing anything.
```

Updates are idempotent: re-run the install from a newer checkout and it upgrades in place, or repairs missing pathfinder-owned files at the same version. Uninstall follows the same runbook.

## Security and trust

- Pathfinder installs executable hook scripts and global Claude Code configuration. Review the source before installing.
- Install from a trusted local checkout or a pinned commit. A branch name is not an immutable security pin; when you pin a tag, the installer resolves and records its full commit.
- Never run install, update, diagnostics, or hook setup with sudo or as another user.
- Anything that can modify `~/.claude/` can alter hooks, agents, or instructions. That is a local-account trust boundary, not a sandbox, and pathfinder does not change it.
- Verifier roles have edit tools denied, but this reduces write surface rather than eliminating it: Bash can still write. Verifiers are a quality mechanism, not a security sandbox.

## Telemetry and the update reminder (both optional)

If you opt in, hooks call a small local script on `SubagentStart`, `SubagentStop`, and `SessionEnd`, appending JSONL lines (timestamp, event type, session and agent IDs) under `~/.claude/pathfinder/logs/`. On `SubagentStop` only, it also reads the subagent's own transcript and appends five more fields: `models` (the distinct model strings observed, sorted), `output_tokens`, `input_tokens`, `cache_read_tokens`, and `cache_creation_tokens`. All five are null when the transcript is missing, unreadable, or carries no usable data. The privacy promise holds: it records only the model string and integer token counts, nothing else - no prompts, no source code, no transcript prose in the current helper. It is best-effort only - missed events are normal, and it is not an audit trail or a complete session record. If hooks cannot be installed, diagnostics still work; pathfinder never relies on a model remembering to log.

A second optional hook checks at session start whether Claude Code updated and, if so, injects a short reminder to re-check the handful of Claude Code facts pathfinder depends on (the checklist is `docs/REVALIDATION.md`, copied into `~/.claude/pathfinder/` at install). Claude Code ships often, so expect the reminder a few times a month; it fires once per version change and is deliberately unthrottled, because patch releases can carry behavior changes.

```bash
./scripts/pathfinder-diag.sh   # health check (POSIX)
./scripts/pathfinder-stats.sh  # summarize logs; empty logs are normal
```

## Project-local (optional)

Prefer native `.claude/` project settings and instructions for rules that must apply to a project. Optionally, a project may carry `.pathfinder/config.json` (see `examples/.pathfinder/config.json`) with `default_verification` and `logging` as hints; tools and docs may read it, and the global install never merges project policy.

## Fallback behavior

Role frontmatter uses model aliases (`opus`, `sonnet`, `haiku`), so bindings survive model releases. The suggested main-session setting is `best` (Fable 5 when available, else latest Opus), and `fallbackModel: ["opus", "sonnet"]` covers overload and unavailability. Security work stays on `security-executor` regardless of the main-session model.

## Updating and removing

- **Update**: re-run the install from a newer checkout; the runbook shows the changelog slice and upgrades the single policy block in place.
- **Check health**: `scripts/pathfinder-diag.sh` verifies version, files, markers, collisions, manifest, and drift against your checkout.
- **Uninstall**: tell Claude Code to follow the Uninstall section of `install/AGENT-INSTALL.md`. It removes the policy block and pathfinder agents, offers a settings restore from the first backup, and leaves logs unless you ask for their deletion.

## Docs

| Doc | Contents |
|---|---|
| [docs/research.md](./docs/research.md) | Sourced research behind the design |
| [docs/design.md](./docs/design.md) | Design rationale + v1 appendix |
| [docs/usage-examples.md](./docs/usage-examples.md) | Short practical examples |
| [docs/REVALIDATION.md](./docs/REVALIDATION.md) | The Claude Code facts pathfinder depends on, and how to re-check them |
| [docs/improvement-roadmap.md](./docs/improvement-roadmap.md) | Deferred ideas only |
| [install/AGENT-INSTALL.md](./install/AGENT-INSTALL.md) | Install, update, uninstall, diagnostics |

## Platforms

- Configuration and agents: any Claude Code host meeting the minimum version.
- Shell helpers: POSIX only (macOS, Linux, WSL). Native Windows without a POSIX shell uses the runbook's file-tool path; skip the helpers.

## License

[MIT](./LICENSE)
