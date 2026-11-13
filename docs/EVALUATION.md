# Evaluate Pathfinder

Pathfinder has no measured savings or quality advantage yet. Role names and model matches show what ran, not whether the task succeeded.

## Compare completed tasks

Choose representative work from a real project: a small fix, a broad code search, a mechanical edit, a feature, and a security-sensitive change. Write the expected behavior and required checks before either run. Use at least two tasks in each category before drawing a conclusion.

Run each task twice from the same starting revision in separate disposable checkouts and fresh sessions. Keep the Claude Code version, provider, main model, effort, permissions, tool connections, and project instructions the same. One session uses native Claude Code without Pathfinder. The other loads the Pathfinder plugin and explicitly invokes `/pathfinder:work`. Do not leave a v1 policy or legacy role files active in either session. Change which condition runs first across tasks. Do not give either session the other session's solution.

Include the same independent final acceptance check in both conditions. Count its usage and elapsed time in both runs. Keep all intermediate reviews and retries in their run's totals. Use a fixed time or usage ceiling agreed before the comparison, and report tasks that exceed it as incomplete rather than dropping them.

## Record the result

Copy `docs/evaluation.csv` to a private results file. Add one row per run. Record the starting revision, task, condition, Claude Code version, provider, models, effort, acceptance result, failed checks, human corrections, and elapsed minutes. Record the usage source and its scope. Keep raw evidence links or private paths with the run.

For API sessions, record total billed usage across the main conversation, every helper, reviews, and retries. Preserve input, output, cache-read, and cache-write counts separately. Use the provider's actual bill when comparing dollars. For subscriptions, capture `/usage` before and after an otherwise isolated run and record the plan usage change if available. Shared account activity can make that change unusable. Mark missing or mixed measurements as unknown. Do not convert list-price estimates into claimed subscription savings.

Claude Code's `/usage` report covers more of the task than Pathfinder's optional helper log. The helper log omits main-session work and can miss events. Do not add its counts to a report that already includes those helpers. Model matches alone do not establish correctness, cost, or plan usage. Multi-model runs do not reveal why the model changed.

## Make the decision

Compare accepted work first. A cheaper unfinished task is not a saving. Keep a Pathfinder rule when repeated comparisons show better acceptance, fewer corrections, or lower total usage or elapsed time without worse acceptance. Remove rules that add work without a repeatable benefit. Treat a small sample as an early signal, not a general performance claim.

No real task comparison was run as part of the v2 source changes. The CSV contains a header only. Plugin validation and shell fixtures establish configuration behavior, not coding quality.

References: [Claude Code usage reports](https://code.claude.com/docs/en/costs) and [monitoring](https://code.claude.com/docs/en/monitoring-usage).
