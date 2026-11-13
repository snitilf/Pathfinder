# Revalidation checklist

Official documentation was consulted on 2026-11-13. This is a source review, not a claim that every provider, hook, or model ran successfully. The v2 verification report records commands actually exercised.

## Plugin and roles

- Run `claude --version` and `sh scripts/check.sh` from this checkout. The check validates a clean plugin package strictly. A personal ignored CLAUDE.md at the checkout root can warn during direct root validation and is not part of the package. Confirm the supported minimum against the features the plugin actually uses.
- Check the plugin manifest paths and version against `VERSION`. Confirm that `pathfinder:scout` and `pathfinder:verifier` are available in a trial session.
- Confirm that the plugin leaves the main model, fallback chain, permissions, and built-in Explore unchanged. No hook runs by default.
- Check role frontmatter against [subagent documentation](https://code.claude.com/docs/en/sub-agents). Model and effort fields are defaults, not an enforcement boundary. Per-call choices, environment overrides, provider mappings, and fallback behavior can change what runs.
- Check `/pathfinder:work` and `/pathfinder:review` discovery against [skill documentation](https://code.claude.com/docs/en/skills). Loading a plugin does not install its optional policy into CLAUDE.md.

## Models

Consult [model configuration](https://code.claude.com/docs/en/model-config). As reviewed on 2026-11-13, `best` equals `opus`. Direct Anthropic API family aliases resolve to Opus 5.5, Sonnet 5.5, and Haiku 5.5. Provider mappings and account access differ. Pathfinder does not set a main model or fallback chain.

If a role runs on a different model, check the per-call model, `CLAUDE_CODE_SUBAGENT_MODEL`, `CLAUDE_CODE_SUBAGENT_MODEL_FORCE`, `CLAUDE_CODE_EFFORT_LEVEL`, provider overrides, and Claude Code fallback notices. A model mismatch alone is not a routing failure or a security finding.

## Optional legacy helpers

Check [hook event schemas](https://code.claude.com/docs/en/hooks) before changing the opt-in helpers. `SubagentStart`, `SubagentStop`, `SessionEnd`, and `SessionStart` are the relevant events. Missing fields must remain unknown rather than fabricated.

The logger reads a subagent transcript to collect model names and usage. Its `message.id`, `message.model`, and `message.usage` assumptions are tested with fixtures. They require a separate real-transcript cross-check on the installed Claude Code version. Do not label that integration exercised unless an actual transcript was supplied. Repeated message snapshots must not count as separate requests.

The version reminder records the last version it saw. It does not track completed revalidation. Read its notice as a prompt to consult this checklist, not as proof of compatibility.

## After a change

Update the affected templates, manifest, helper scripts, tests, and current documentation together. Run `sh scripts/check.sh` and record the output in the verification report. Keep historical reports clearly marked. Do not update a verified date merely because the version reminder ran.
