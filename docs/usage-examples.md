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

Since v1.2.0, `pathfinder-stats.sh` also reports a routing table, pin compliance against installed agent frontmatter, an unattributed bucket, and schema buckets. The output below is real script output run against a small synthetic fixture log built for illustration only, not against any real usage:

```text
schema buckets (SubagentStop = 8):
  schema v1 (pre-v1.2.0, no model data ever captured): 3 (37.5%)
  schema v2, models null (v1.2.0, no transcript available): 0 (0.0%)
  schema v2, models present (real data): 5 (62.5%)

unattributed: no agent_type from the hook, no transcript
  2 of 8 SubagentStop (25.0%)
  these carry an empty-string agent_type; they cannot be attributed to any
  role and are excluded from the per-role compliance denominators below,
  reported here so the denominator is never silently shrunk.

routing table (agent_type x models, SubagentStop with model data):
  scout:
    claude-haiku-4-5-20251001    calls=1 out=1200 in=90 cache_read=15000 cache_creation=800
    (no model data: 1 lines)
  executor:
    claude-sonnet-5              calls=1 out=900 in=60 cache_read=4000 cache_creation=300
    claude-opus-4-8              calls=1 out=5400 in=420 cache_read=210000 cache_creation=30000
  workflow-subagent (unpinned):
    claude-opus-4-8              calls=1 out=18000 in=1200 cache_read=9000 cache_creation=500
  general-purpose (unpinned):
    claude-fable-5+claude-opus-4-8 calls=1 out=3000 in=250 cache_read=1200 cache_creation=90

pin compliance (observed model vs frontmatter pin; alias-to-family by prefix):
  scout              pin=haiku
                     compliant=1 / 1 with model data (100.0%), off-pin=0
                     (also: 1 calls with no model data, not counted; total calls=2)
                     observed claude-haiku-4-5-20251001  x1 (matches pin)
  executor           pin=opus
                     compliant=1 / 2 with model data (50.0%), off-pin=1
                     (also: 0 calls with no model data, not counted; total calls=2)
                     observed claude-sonnet-5            x1 (OFF-PIN)
                     observed claude-opus-4-8            x1 (matches pin)

ungoverned delegation (types with no pinned model):
  workflow-subagent: calls=1
                     observed claude-opus-4-8            x1
  general-purpose: calls=1
                     observed claude-fable-5             x1
                     observed claude-opus-4-8            x1
  report only, not an accusation: these types have no pinned model. whether
  a model was set explicitly or inherited from the calling session is not
  distinguishable from telemetry (the log records no session model), so no
  inheritance judgement is made here.
```

## Optional project hint

Place at the project root:

```
.pathfinder/config.json
```

Example: `examples/.pathfinder/config.json`. Tools and docs may read it; the global install never merges project policy. Prefer native `.claude/` for rules that must apply.

## Telemetry note

If hooks are installed, JSONL under `~/.claude/pathfinder/logs/` is best-effort orchestration telemetry. Empty logs are normal. Missing logs are not an error. Since v1.2.0, `SubagentStop` lines also carry model and token fields extracted from the subagent transcript, null when unavailable; see the diagnostics output above.
