# Usage examples

## Start a local session

From the Pathfinder checkout, after handling any legacy installation:

```bash
claude plugin validate .
claude --plugin-dir "$PWD"
```

## Work with optional preferences

```text
/pathfinder:work Fix the empty-input bug in the parser. Preserve the existing API and run the relevant parser checks.
```

The main session implements the fix. A broad search can go to `pathfinder:scout`. A substantial or risky change receives an independent `pathfinder:verifier` check. A small fix does not automatically need another agent.

For research without implementation:

```text
Use pathfinder:scout to locate where authentication tokens are validated. Return file:line evidence and anything you could not establish.
```

A scout locates code. Security judgments require a deeper review rather than treating search results as a security audit.

## Request an independent review

```text
/pathfinder:review Check the parser diff against empty input, malformed input, and the existing parser tests. Report what you actually ran.
```

```text
/pathfinder:review Check the session-cookie change against the stated authentication rules. Include abuse cases, error paths, and trust boundaries.
```

The reviewer reports CONFIRMED, REFUTED, or INCOMPLETE and never fixes its findings. The main session handles corrections and requests a recheck of the affected conditions. If the verifier cannot run, independent verification remains incomplete.

## Check source and legacy helpers

```bash
sh scripts/check.sh
sh scripts/pathfinder-diag.sh --plugin .
sh scripts/pathfinder-diag.sh
sh scripts/pathfinder-stats.sh
```

The plugin-source diagnostic is separate from the no-argument legacy installation diagnostic. Optional statistics read existing local logs and do not establish whole-session savings. Logs can be absent when hooks are disabled. For plugin role defaults, point `PATHFINDER_AGENTS_DIR` at this checkout's `templates/agents` directory when using the statistics helper. Without an explicit directory, plugin defaults remain unknown. This does not change or install the agents, and defaults from a checkout do not establish what a different installed plugin version loaded.

Use Claude Code's `/usage` reports first. Follow [EVALUATION.md](EVALUATION.md) for a controlled task comparison. No illustrative token numbers are presented as measured v2 results.
