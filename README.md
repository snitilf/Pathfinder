![pathfinder](docs/assets/pathfinder.png)

# Pathfinder

Pathfinder is an optional Claude Code plugin for broad code searches and independent review. Routine coding stays in the main conversation. It does not select your main model, change permissions, or promise lower usage.

## Try it locally

Use Claude Code v2.1.219 or later. From this checkout:

```bash
claude plugin validate .
claude --plugin-dir "$PWD"
```

The plugin loads for that session. No global installation or marketplace is required. Native validation can warn about a personal ignored CLAUDE.md at the checkout root; that file is not plugin context. The local check command below validates a clean source package strictly. If you have Pathfinder v1 installed, follow the [migration guide](install/AGENT-INSTALL.md) first so its global policy does not remain active alongside v2.

Inside Claude Code:

```text
/pathfinder:work Fix the failing parser test. Keep the public API unchanged.
/pathfinder:review Check the parser fix against the failing case and existing tests.
```

`work` applies the optional delegation and review preferences to your task. `review` requests an independent verifier. Both skills run only when you invoke them. Loading the plugin makes its agents available for Claude to select when appropriate; it does not automatically load these skill bodies or install global policy.

## What it adds

| Helper | Requested defaults | Purpose |
|---|---|---|
| `pathfinder:scout` | Haiku, low effort | Answer a bounded question across many files with locations and evidence |
| `pathfinder:verifier` | Opus, high effort | Exercise substantial or risky changes independently and report findings |

Helpers do their own work and never delegate further. The verifier reports CONFIRMED, REFUTED, or INCOMPLETE. It does not fix findings. Security-sensitive and financial changes receive deeper checks of abuse cases and trust boundaries.

The agent templates are the source of truth for these defaults. Per-call settings, environment overrides, provider restrictions, and Claude Code fallback can change the model or effort that actually runs. The verifier can run tests with Bash, so its edit-tool denylist is not a security sandbox.

## What stays under your control

Your main model, fallback chain, permissions, built-in Explore agent, and global instructions remain unchanged. The plugin has no default hooks, servers, or telemetry. It uses Claude Code's native plugin, skill, and subagent support rather than a separate runtime.

The short policy fragments under `templates/claude-md/` are available for an optional manual policy. They are not loaded by the plugin. Add them only after reviewing the [install guide](install/AGENT-INSTALL.md), and only where this plugin is active. Personal working-style rules remain a separate opt-in.

## Check whether it helps

Start with Claude Code's `/usage` reports. Pathfinder has no measured quality or savings advantage yet. Use the [task comparison guide](docs/EVALUATION.md) to compare accepted work, corrections, elapsed time, and complete usage with and without Pathfinder.

Optional legacy shell helpers remain available for existing logs and installations. They are not required by the plugin and are not enabled automatically. They require a POSIX shell on macOS, Linux, or WSL. Agent-only logs omit main-session work and cannot establish total savings.

```bash
sh scripts/check.sh
sh scripts/pathfinder-diag.sh --plugin .
sh scripts/pathfinder-stats.sh
```

The first command runs local source checks. The second checks plugin source rather than a global installation. Running diagnostics without `--plugin` checks a legacy v1 installation. Configuration checks do not prove live model behavior.

Local source checks require `jq`, Python 3.9 or later, and a POSIX shell. Native validation also requires Claude Code; the check reports it as skipped when Claude Code is unavailable.

## Documentation

- [Install, migrate, remove, and roll back](install/AGENT-INSTALL.md)
- [Usage examples](docs/usage-examples.md)
- [Design](docs/design.md) and [dated official-source research](docs/research.md)
- [Compatibility checklist](docs/REVALIDATION.md)
- [Implementation plan](docs/IMPLEMENTATION-PLAN.md) and [v2 verification report](docs/VERIFICATION-V2.md)
- [Task evaluation](docs/EVALUATION.md)

The v2 source package is prepared locally. No marketplace publication, global migration, or live task comparison is implied by its version number.

## License

[MIT](LICENSE)
