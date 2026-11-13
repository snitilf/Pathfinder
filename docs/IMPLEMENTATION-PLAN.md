# Pathfinder v2 implementation plan

The goal is a small optional Claude Code plugin for bounded research and independent review. Ordinary work stays in the main conversation. Model settings and permissions stay under the user's control.

## Step 1: simplify policy and roles

Keep scout and verifier. Remove the five overlapping role templates, blanket delegation, project hint configuration, and recommended global model changes. Keep security-specific review checks and explicit evidence requirements. Correct the current model guidance with official sources.

Acceptance: two canonical roles, no recursive delegation, risk-based review, no model or permission changes in the settings snippet, and no promises of savings or sandboxed review.

Verification: a separate read-only agent inspects the changed templates and documentation. Resolve material findings before step 2.

## Step 2: package and migrate

Add a native plugin manifest and an explicit review skill. Point the manifest at the canonical role files. Document a local trial, installation, removal, and reversible migration from v1. Keep logging and the version reminder optional. Do not install into the user's Claude configuration during this work.

Acceptance: plugin paths resolve, skill and agent names match, no default hooks or settings changes, and migration preserves customized files, unrelated settings, and logs. Provide a rollback path. Keep minimum-version claims tied to the features actually used.

Verification: a separate read-only agent checks packaging, available native validation, and migration instructions. A local validation command is not evidence of a live model run.

## Step 3: diagnostics and evaluation

Separate plugin source checks from legacy installation checks. Reject reversed policy markers, correct the version reminder's last-seen wording, and support plugin role names in optional statistics. Add regression fixtures and one local check command. Document a repeatable task comparison that measures correctness, corrections, elapsed time, and total usage.

Acceptance: existing log data remains readable, old installations stay diagnosable, new plugin checks pass, meaningful failure fixtures fail, and evaluation documents no invented measurements.

Verification: a separate read-only agent runs the complete local check and reviews the final diff for integration mistakes. Record evidence and any live checks that were not exercised in the verification report.

## Boundaries

Do not commit, push, publish, install globally, change personal hooks, or run billable Claude tasks. Preserve pre-existing untracked files. Plugin packaging changes distribution; it does not enforce model routing or guarantee better results.

## Completion

All three implementation steps passed separate independent verification on 2026-11-13. The final local gate passed 122 fixture assertions and strict native validation of a clean plugin package on Claude Code 2.1.322. See [VERIFICATION-V2.md](VERIFICATION-V2.md) for evidence and unexercised live checks. No user installation was changed.
