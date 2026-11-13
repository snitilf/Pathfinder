# Pathfinder roadmap

The v2 implementation plan is in [IMPLEMENTATION-PLAN.md](IMPLEMENTATION-PLAN.md). Local verification evidence is in [VERIFICATION-V2.md](VERIFICATION-V2.md). A version number does not imply publication or a completed global migration.

## Next evidence

Run the controlled comparisons in [EVALUATION.md](EVALUATION.md) before claiming better results or lower usage. Check whole-task acceptance, corrections, elapsed time, and total usage. Record native and Pathfinder conditions separately. No real comparison results are included in this repository yet.

Test live discovery, scout execution, independent review, and any optional transcript logging on the actual provider before describing that integration as exercised. Validate the migration and rollback procedure against a disposable copy of a real v1 installation before applying it to user configuration.

## Add only when needed

Consider persistent marketplace distribution after the local plugin proves useful. Keep native installation and update management rather than building a separate package manager.

Add a helper or hook only when repeated tasks expose a gap that the main conversation, the two current helpers, and native Claude Code tools cannot cover. Do not infer a need for more roles from model matches alone. Persistent memory, shared scratchpads, enforcement hooks, automatic model routing, and experimental Code Mode integration require specific evidence before inclusion.
