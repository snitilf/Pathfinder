---
name: work
description: Apply Pathfinder's optional working preferences to a task. Keep routine implementation in the main session, delegate bounded research, and independently verify substantial or risky changes.
disable-model-invocation: true
argument-hint: "[task and acceptance conditions]"
---

Apply these preferences to the task supplied by the user: $ARGUMENTS

If no task is supplied, ask for the task and its expected result. Do not invent work.

If you are already a subagent, do the assigned work yourself. Never delegate further.

Keep routine implementation, quick lookups, and final decisions in the main conversation. Delegate only a bounded independent question or work whose lengthy output would crowd this conversation. Use `pathfinder:scout` for broad read-only searches. Give it the question, relevant paths, constraints, and evidence required. Confirm facts that determine an important decision.

For substantial or risky changes, request an independent check from `pathfinder:verifier`. Give it the claimed outcome, changed paths or diff, and acceptance conditions. Security-sensitive and financial changes need abuse-case and trust-boundary checks. Small changes need relevant checks without an automatic extra agent. Use the role's requested model and effort unless the user or task requires another choice; do not override them merely to start a helper.

Correct findings in the main conversation. Recheck the affected acceptance conditions after corrections. Report CONFIRMED, REFUTED, or INCOMPLETE with the checks actually run. If the independent verifier cannot run, say that verification is incomplete. Self-review does not replace the independent check.

Do not commit, push, publish, install configuration, or change external state unless the user explicitly requests the action. Preserve the user's model settings and permissions. Follow project rules and explicit user instructions before these preferences.
