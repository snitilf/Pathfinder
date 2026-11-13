# Pathfinder research

Official documentation checked on 2026-11-13. These are dated configuration facts, not a benchmark of Pathfinder. The earlier Fable-specific pricing, quota, and performance claims are no longer the basis for the design.

## Model settings

`best` now selects the same model as `opus`; it does not select Fable. On the direct Anthropic API, the `opus`, `sonnet`, and `haiku` aliases currently resolve to Opus 5.5, Sonnet 5.5, and Haiku 5.5. Other providers can resolve the same aliases to earlier releases. Aliases follow provider defaults over time; use explicit versions only when reproducibility requires them.

Fallback remains a separate mechanism. A configured `fallbackModel` chain can handle overload and availability errors. It does not make cheaper delegation automatic or recover from every error. Pathfinder preserves the user's main model and fallback settings.

Source: [model configuration](https://code.claude.com/docs/en/model-config).

## Requested role defaults

The current model order is a per-invocation model parameter, agent frontmatter, `CLAUDE_CODE_SUBAGENT_MODEL`, then the main model. Setting `CLAUDE_CODE_SUBAGENT_MODEL_FORCE=1` changes that behavior: it forces the configured subagent model, or the main model if none is configured. Provider restrictions and fallback can also change the observed model.

A per-invocation effort parameter overrides the agent's effort field; `CLAUDE_CODE_EFFORT_LEVEL` overrides both. These controls mean role defaults are preferences, not enforcement. Inspect `/tasks` during a run to see its model and selected effort.

Source: [subagent model and effort configuration](https://code.claude.com/docs/en/sub-agents#choose-a-model).

## Native tools to reuse

Claude Code includes `/code-review` for code review and `/verify` for exercising changes against a running app. They have different scopes; neither automatically proves every acceptance condition. `/verify` is invoked explicitly. `/doctor prompt-audit` can inspect outdated or conflicting instructions. Skill bodies load when used, which makes them a better home for detailed procedures than always-loaded instructions.

Source: [skills and bundled verification tools](https://code.claude.com/docs/en/skills).

`/usage` reports session token usage. Eligible subscription plans also receive recent usage breakdowns and recommendations. API list-price estimates are not a subscription bill. Attribution shares can overlap and do not equal savings. Measure complete tasks and include main-session work when comparing configurations.

Source: [usage and costs](https://code.claude.com/docs/en/costs).

Plugins package agents, skills, and other components as one installable unit. Pathfinder uses that native distribution mechanism instead of requiring a global model override. Its optional policy remains a preference the user can inspect and adopt.

Source: [plugin overview](https://code.claude.com/docs/en/plugins).

## What this evidence does not prove

The documentation establishes that these mechanisms exist. It does not establish that Pathfinder improves quality, saves quota, or finishes tasks faster. Passing helper-script tests establishes only the behavior those tests exercise. A real comparison needs the same task conditions, independently checked outcomes, and complete usage records. Keep such results separate from claims about configuration compatibility.
