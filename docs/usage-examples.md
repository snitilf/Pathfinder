# Usage examples

## Install (local checkout)

```text
Read install/AGENT-INSTALL.md from this pathfinder checkout
and follow it to install pathfinder into my global Claude Code configuration.
Show me the full plan of changes and get my approval before writing anything.
```

Pin a release when installing from the network (replace TAG):

```text
Read https://raw.githubusercontent.com/<owner>/pathfinder/<TAG>/install/AGENT-INSTALL.md
and follow it to install pathfinder. Fetch every template from that same <TAG>, never from main.
Show me the full plan of changes and get my approval before writing anything.
```

## Delegation

- "Find where auth tokens are validated" -> orchestrator should use `scout` or `Explore`.
- "Rename FooService to BarService across the package and update imports" -> `mech-executor`, then `light-verifier` if checks are mechanical.
- "Add rate limiting to the public API with sensible defaults" -> `executor`, then standard `verifier`.
- "Review and harden session cookie handling" -> `security-executor`, then heavy `verifier`.

## Light verify

After a mechanical bulk edit:

```text
Have light-verifier check that the rename is complete and tests pass on the paths you listed.
```

## Diagnostics

```bash
# posix only (macos, linux, wsl)
./scripts/pathfinder-diag.sh
./scripts/pathfinder-stats.sh
```

Or ask in session: "Run pathfinder diagnostics" (agent follows the install runbook checklist).

## Optional project hint

Place at the project root:

```
.pathfinder/config.json
```

Example: `examples/.pathfinder/config.json`. Tools and docs may read it; the global install never merges project policy. Prefer native `.claude/` for rules that must apply.

## Telemetry note

If hooks are installed, JSONL under `~/.claude/pathfinder/logs/` is best-effort orchestration telemetry. Empty logs are normal. Missing logs are not an error.
