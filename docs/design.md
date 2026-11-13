# Pathfinder design

Pathfinder is an optional set of Claude Code preferences. The main session owns implementation and final decisions. Helpers earn their place when they isolate broad searches or provide an independent check. Delegation itself is not a success measure.

## Two roles

`scout` searches many files for a bounded question and returns locations with evidence. It requests `haiku` at `low` effort and has only `Read`, `Glob`, and `Grep`. Quick reads stay in the main session. Its findings are inputs to a decision, not a code or security review.

`verifier` independently exercises substantial or risky changes. It requests `opus` at `high` effort. It returns CONFIRMED, REFUTED, or INCOMPLETE and never repairs findings. Security-sensitive and financial changes receive deeper checks of abuse cases and trust boundaries. Small changes need relevant checks without an automatic second agent.

Both roles are leaves: they do their own work and never delegate further. The main session handles recovery and corrections. A failed check is useful evidence; an unrun check is incomplete.

The separate `Explore`, implementation, light-review, and security-executor templates from v1 are removed. Their useful instructions belong in the main session or the single verifier. Existing installed v1 files require explicit migration; deleting a template does not remove anything from a user's machine.

## User-owned settings

Pathfinder does not select the main model, set fallback chains, or expand permissions. `templates/settings.snippet.json` is an empty object. Leave the user's existing settings intact.

Agent model and effort fields are requested defaults. Claude Code can override them per call, through environment settings, provider restrictions, or fallback. Check the model that actually ran before drawing conclusions about usage. The dated facts and source links live in [research.md](./research.md).

## Optional policy and native packaging

The plugin carries the two agent definitions as one unit. It does not replace the built-in Explore agent or silently install global instructions. The short fragments in `templates/claude-md/` are an optional policy for users who want explicit delegation and review preferences. The personal working-style fragment remains a separate opt-in.

Keep detailed procedures in skills that load when used. Use Claude Code's built-in review, verification, and usage tools where they fit. Pathfinder adds preferences for independent checks rather than a second execution system. See the [official plugin overview](https://code.claude.com/docs/en/plugins).

## Evidence and limits

Evaluate task completion, correction cycles, elapsed time, and whole-session usage with and without Pathfinder. Agent-only token counts omit the main session and cannot prove total savings. Matching a role's requested model proves neither correct delegation nor correct output.

Retain optional logging only for questions native reports cannot answer. Existing log formats and historical records can remain readable without becoming a prerequisite for the plugin. A verifier's edit-tool denylist reduces accidental changes, but Bash can still write. Review instructions do not create a security sandbox.
