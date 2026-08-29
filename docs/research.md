# Fable 5 Multi-Model Orchestration - Research Report

> pathfinder applies this research as a Claude Code configuration layer.


## Purpose

This document began as a sourced research pass from early July 2026 on how to maximize the value of Claude Fable 5.
It covers Fable's strengths, the quota economics of Claude subscriptions, the multi-model orchestration mechanisms Claude Code officially provides, and the community's measured patterns.
Pathfinder's three-layer architecture (see [design.md](./design.md)) is the applied conclusion of this research.
The model lineup, prices, alias behavior, effort guidance, and safety-routing sections were revalidated against official Anthropic and Claude Code documentation on 2026-08-28 after the releases of Opus 5 and Sonnet 5.

## Contents

- [Fable 5: positioning and strengths](#fable-5-positioning-and-strengths)
- [When not to use Fable 5](#when-not-to-use-fable-5)
- [Subscription quota economics](#subscription-quota-economics)
- [Official Claude Code mechanisms](#official-claude-code-mechanisms)
- [Community measurements and patterns](#community-measurements-and-patterns)
- [Effort tiering](#effort-tiering)
- [Generational shift in prompting](#generational-shift-in-prompting)
- [Sources](#sources)

## Fable 5: positioning and strengths

| Item | Value |
|---|---|
| Model ID | `claude-fable-5` |
| API pricing | $10 / $50 per MTok (2× Opus 5) |
| Context / output | 1M (default is the maximum) / 128K |
| Release | GA 2026-06-09; briefly pulled under export controls, restored 07-01 |
| Data retention | Mandatory 30 days - ZDR orgs get 400 on every request |

The official prompting guide lists seven advantage areas, under one core principle: **"the longer and more complex the task, the larger Fable 5's lead."**

| Advantage area | Notes |
|---|---|
| Long-horizon autonomy | Goal-directed runs sustained over days |
| First-shot correctness | Well-specified complex problems done right the first time |
| Vision | Dense technical diagrams; proactively uses bash/crop tools on blurry or flipped images |
| Enterprise workflows | End-to-end financial analysis, spreadsheets, decks, documents |
| Code review & debugging | At launch, bug-finding recall was clearly above the then-current Opus 4.8 baseline, including repo-history search |
| Ambiguity | Notably better at navigating under-specified asks |
| Delegated collaboration | Dispatching and sustaining parallel subagents is markedly more reliable - a born orchestrator |

Representative launch benchmarks used Opus 4.8 as the comparison: SWE-Bench Pro 80.3% (Opus 4.8: 69.2%) and Cognition FrontierCode 29.3% (Opus 4.8: 13.4%).
Both are Anthropic-self-reported figures using its own scaffolding or system card, not independent verification, and they should not be read as comparisons against the later Opus 5 release.

## When not to use Fable 5

| Scenario | Why | Use instead |
|---|---|---|
| Routine feature work, focused debugging, test generation, routine PR review | Opus 5 is the recommended starting point for most agent workloads and costs half as much per token | Opus 5 |
| High-volume, latency-sensitive pipelines | High-effort single requests can run minutes | Sonnet / Haiku |
| Security work (defensive included) | A dedicated Opus 5 role keeps this work off the main Fable session and provides the intended high-effort tier, although flagged cybersecurity requests can still fall back to Opus 4.8 and some biology requests can be refused | Opus 5 with explicit fallback-aware handling |
| ZDR organizations | 30-day retention is a hard requirement | Unavailable |
| Mechanical, token-heavy work | Renames, test runs, formatting don't need frontier reasoning | Haiku / Sonnet |

> **Tip:** Start with the cheapest model that reliably completes the task, compare cost per completed task rather than cost per token, and escalate to Fable 5 when Opus 5 visibly fails or the task needs Fable's longer-horizon autonomy.

## Subscription quota economics

| Mechanism | Detail |
|---|---|
| Two-layer limits | 5-hour rolling window + weekly cap; the pool is shared across Claude Code / Claude.ai / Cowork |
| Two weekly buckets | A shared "all models" bucket + an **additional Sonnet-only bucket** (since Nov 2025) - Sonnet usage counts against the shared bucket too (current builds reportedly drain both), so it's not a fully separate pool, but it does materially extend what Sonnet work can draw |
| Fable 5 multiplier | Official UI wording: "Uses your limits ~2x faster than Opus"; heavy agentic use burns much steeper in practice (one extreme report: a Max $200 user exhausting the 5-hour window in 13 minutes) |
| Relative unit price (API proxy) | Fable 5 = 2× Opus 5; Opus 5 = 2.5× Sonnet 5; Sonnet 5 is permanently $2/$10 per MTok as of Anthropic's 2026-08-10 update; Haiku 4.5 is $1/$5 |
| Official stance | Absolute token numbers per plan were never published; only the plan multipliers (Max 5x/20x) and the ~2× Fable rate are official |

Fable 5's launch-period subscription timeline:

| Date | Event |
|---|---|
| 2026-06-09 | GA; included free in Pro/Max/Team (weighted ~2× Opus) |
| 2026-06-12 | Export-control suspension |
| 2026-07-01 | Restored, with a "max 50% of weekly limit" cap |
| 2026-07-07 | Official five-day extension of subscription inclusion |
| After 2026-07-12 | Usage-credit access began varying by plan and seat; current Claude Code behavior checks organization availability and prompts for usage-credit consent when required |

> **Warning:** This is why alias-based degradation remains important.
> The documented `best` alias selects Fable 5 where the organization has access and otherwise resolves to the latest Opus model.
> Usage-credit consent is handled separately by Claude Code, and `fallbackModel` still does not trigger on billing-class errors.

## Official Claude Code mechanisms

All verified line-by-line against official docs (code.claude.com - sub-agents, model-config, settings pages):

| Mechanism | Detail |
|---|---|
| Subagent `model` frontmatter | Accepts aliases (`sonnet`/`opus`/`haiku`/`fable`), full model IDs, `inherit` (the default when omitted) |
| Subagent `effort` frontmatter | `low`/`medium`/`high`/`xhigh`/`max`, overrides session effort per agent |
| Global agents directory | `~/.claude/agents/` (user level); project level is `.claude/agents/`; same-name conflicts resolve by scope priority |
| Model resolution order | `CLAUDE_CODE_SUBAGENT_MODEL` env → Agent tool's per-invocation `model` param → frontmatter → main conversation model |
| `best` alias | Fable 5 where the org has access, otherwise latest Opus - the built-in frontier-degradation mechanism |
| `fallbackModel` (settings) / `--fallback-model` | An ordered switch chain; fires on overload/unavailability (never on auth/billing/rate-limit errors), with a notice |
| `opusplan` alias | Opus thinks in plan mode, auto-switches to Sonnet for execution - the built-in "strong model thinks, cheap model acts" |
| `availableModels` (settings) | An allowlist constraining the main session, subagent frontmatter, and Task model params alike; values outside it are silently skipped in favor of inheritance |
| Current direct-API aliases | `opus` resolves to Opus 5, `sonnet` resolves to Sonnet 5, and `haiku` resolves to Haiku 4.5; Opus 5 requires Claude Code 2.1.219 or later |
| Provider-specific aliases | Claude Platform on AWS currently uses Opus 5 / Sonnet 4.6; Amazon Bedrock and Google Cloud's Agent Platform use Opus 5 / Sonnet 4.5; Microsoft Foundry uses Opus 4.6 / Sonnet 4.5 |
| 1M context | Fable 5 and Sonnet 5 have native 1M context; current Opus models support 1M subject to provider and plan behavior; the `[1m]` suffix remains available for `sonnet`, `opus`, and `opusplan` aliases where selection is needed |
| CLAUDE.md and models | CLAUDE.md **cannot** change the main model (settings / `/model` / `--model` do) - CLAUDE.md governs delegation behavior policy |
| Built-in Explore agent | Since v2.1.198 it inherits the main conversation model (Opus-capped on the Claude API); a same-name user-level `Explore.md` overrides it back to Haiku |
| Version pinning | `ANTHROPIC_DEFAULT_OPUS_MODEL` etc. pin aliases to specific versions (relevant for third-party provider deployments) |

## Community measurements and patterns

| Pattern / measurement | Numbers or approach | Source |
|---|---|---|
| **Official first-party benchmark** (2026-07-08) | Fable 5 orchestrator + Sonnet 5 workers: **96% of all-Fable performance at 46% of the cost** on BrowseComp (86.8% vs 90.8% accuracy, $18.53 vs $40.56/problem); the inverse advisor pattern (Sonnet executor consulting a Fable advisor): ~92% at ~63% on SWE-bench Pro - the orchestrator split wins on both axes | Anthropic ([@ClaudeDevs thread](https://x.com/ClaudeDevs/status/2074606058128224365); [multi-agent docs](https://platform.claude.com/docs/en/managed-agents/multi-agent)) |
| 12-worker audit cost comparison | All-Fable $14.50; Fable+Sonnet $6.10 (−58%); Fable+Haiku $3.70 (−74%); orchestrator premium only $1.75 | Developers Digest |
| Token-cost-reduction claims | Orchestrator + cheap subagents commonly claimed at 5-10×; individual claims up to −90% | Various community posts |
| Explore telemetry | ~36% of API calls in Sonnet-selected sessions actually ran on Haiku (old built-in Explore behavior) - proof that cheap exploration is a huge volume | mirin.pro |
| Marketplace tiering conventions | Tier 0 Fable (longest horizon) → Tier 1 Opus (architecture/security/critical) → Tier 3 Sonnet (docs/tests) → Tier 4 Haiku (fast ops) | wshobson/agents (199 agents) |
| Handoff pattern | Five-role pipeline (ORCHESTRATOR/SCOUT/GUARD/BUILD/CHECK) exchanging `.handoff/` JSON files - auditable, resumable | clouatre.ca |
| Mechanical discipline | PreToolUse "Spawn Guard" blocks under-specified delegations, Stop hook blocks unfinished wrap-ups - hooks enforce what prompts only suggest | Rylaa/fable5-orchestrator |
| Security workers pinned to Opus | Community reports motivated routing security work away from Fable; current official docs clarify that Opus 5 also has classifiers and can fall back to Opus 4.8 for flagged cybersecurity requests | Hacker News plus current Claude Code model configuration docs |

## Effort tiering

Effort is the second-biggest quota lever.
Current Claude Code documentation defines `high` as the default balance of intelligence and token use on Fable 5, Opus 5, and Sonnet 5.

| Target | Recommended effort | Why |
|---|---|---|
| Fable 5 main session | `high` (the default) | Official balance for most tasks |
| Fable 5 longest-horizon tasks | `xhigh` | >30-minute, million-token-budget runs; pair with a large `max_tokens` (64K up) |
| `max` | Rarely | Diminishing returns, prone to overthinking |
| Recon / mechanical subagents | `low` | High-volume, low-judgment work; low effort = fewer tool calls and less preamble |
| Judgment executors / verifier | `high` | Current-model default and the documented balance of intelligence and token use |
| Security executor | `high` | Correctness over cost |

## Generational shift in prompting

| Finding | Applied implication |
|---|---|
| Over-prescriptive prompts/skills written for previous models **reduce** Fable 5 output quality | Subtract, don't add: state goals and constraints, delete step-by-step scaffolding |
| A well-specified single first turn performs best | Delegation rule: one-shot specs - goal, constraints, done-criteria, paths |
| "Give the reason, not only the request" measurably helps | Every delegation spec includes the why |
| Fresh-context verifiers beat self-critique (official wording) | The `verifier` role is the core of the quality gate |
| Requiring progress claims to be audited against tool results nearly eliminates fabricated status reports | Written into the executor/verifier system prompts |
| Asking the model to restate internal reasoning triggers the `reasoning_extraction` refusal category | Policy and agent prompts avoid such instructions |

## Sources

| Category | Links |
|---|---|
| Official | [Current model lineup](https://platform.claude.com/docs/en/models/overview) · [Choosing a model](https://platform.claude.com/docs/en/docs/about-claude/models/choosing-a-model) · [Introducing Claude Opus 5](https://www.anthropic.com/news/claude-opus-5) · [Introducing Claude Sonnet 5](https://www.anthropic.com/research/claude-sonnet-5) · [Introducing Claude Fable 5](https://platform.claude.com/docs/en/about-claude/models/introducing-claude-fable-5.md) · [Launch announcement](https://www.anthropic.com/news/claude-fable-5-mythos-5) · [Prompting Fable 5](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-fable-5.md) · [Effort](https://platform.claude.com/docs/en/build-with-claude/effort.md) · [Redeploying Fable 5](https://www.anthropic.com/news/redeploying-fable-5) · [Limits update](https://www.anthropic.com/news/higher-limits-spacex) · [Decoupling the brain from the hands](https://www.anthropic.com/engineering/managed-agents) |
| Claude Code docs | [Subagents](https://code.claude.com/docs/en/sub-agents) · [Model config](https://code.claude.com/docs/en/model-config) · [Settings](https://code.claude.com/docs/en/settings) |
| Subscription & limits | [Models, usage and limits in Claude Code](https://support.claude.com/en/articles/14552983) · [What is the Max plan](https://support.claude.com/en/articles/11049741) · [BleepingComputer: not permanently leaving](https://www.bleepingcomputer.com/news/artificial-intelligence/claude-fable-5-isnt-permanently-leaving-subscriptions-anthropic-says/) · [Forbes: five-day extension](https://www.forbes.com/sites/sandycarter/2026/07/07/claude-fable-5-extends-by-five-more-days-10-moves-to-make-now/) |
| Community measurements | [Developers Digest: orchestrator playbook](https://www.developersdigest.tech/blog/fable-5-orchestrator-model-playbook) · [mirin.pro: Haiku telemetry](https://mirin.pro/blog/claude-code-subagents-haiku-telemetry/) · [Upstash: cost control](https://upstash.com/blog/keep-claude-fable-5-costs-under-control) · [TrueFoundry: limits measured](https://www.truefoundry.com/blog/claude-code-limits-explained) |
| Community patterns | [Rylaa/fable5-orchestrator](https://github.com/Rylaa/fable5-orchestrator) · [wshobson/agents](https://github.com/wshobson/agents) · [clouatre.ca: subagent architecture](https://clouatre.ca/posts/orchestrating-ai-agents-subagent-architecture/) · [MindStudio: orchestrator policy](https://www.mindstudio.ai/blog/smart-orchestrator-cheaper-sub-agent-models-claude-code) · [HN discussion](https://news.ycombinator.com/item?id=48752030) |
