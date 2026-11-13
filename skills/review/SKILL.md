---
name: review
description: Request an independent Pathfinder verifier for a claimed outcome or changed code. Returns evidence and unresolved findings without fixing the implementation.
disable-model-invocation: true
argument-hint: "[claimed outcome, diff or paths, acceptance conditions]"
---

Review the claim and scope supplied by the user: $ARGUMENTS

If the claim or scope is unclear, inspect the relevant diff and project instructions, then clarify only what is still missing. Do not claim to verify an unspecified outcome.

If you are already a subagent, perform the review yourself without further delegation.

From the main session, invoke `pathfinder:verifier` with the claimed result, the changed paths or diff, relevant project rules, and named acceptance conditions. Ask it to run the necessary checks independently and report CONFIRMED, REFUTED, or INCOMPLETE with evidence. For security-sensitive and financial changes, include abuse cases, error paths, and trust boundaries. Preserve the role's model and effort defaults unless the user or task requires another choice.

Report the verifier's findings and what its evidence covers. Do not edit files as part of this review. If the verifier is unavailable or a required check cannot run, report INCOMPLETE and the missing evidence. Do not replace independent verification with self-review and call it confirmed.

Do not commit, push, publish, install configuration, or change external state unless the user explicitly requests the action. Follow project rules and explicit user instructions before these preferences.
