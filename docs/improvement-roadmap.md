# Improvement roadmap (deferred)

Ideas only.
No templates, no installer hooks, no partial implementations beyond what a release explicitly adopts.

## Adopted (v1.2.0)

- Eval checklist: adopt.
  This release is its own evidence - the dedup and privacy fixture list, the hand-reconstructed ground-truth check, and the pin-compliance verification in `scripts/pathfinder-stats.sh` are the eval checklist in practice.
- External trace correlation (previously item 9, optional correlation with an external execution trace): folded into the adopted work.
  Change A (`scripts/pathfinder-log.sh` model/token capture) is a partial delivery - session id was already present, and the transcript-derived model and token fields are the first slice of trace correlation. Full correlation with an external execution trace remains open but is no longer a separate roadmap line.

## Deferred (pending friction-log answers)

Both items below stay on the roadmap because Part 3 of `docs/usage-review.md` (the friction log) was never answered - the 2026-07-16 review ran three days early and stopped before Part 3.
Revisit once a friction log exists.

- Resilience beyond two-strike (stronger partial-result policy).
- Scratchpad / shared summaries.

## Dropped

- Triage / router role: drop.
  Roles showed near-100% pin compliance (2,361 role calls since Jul 11, all but two explainable exceptions on-pin); no mis-routing evidence to justify a triage step.
- Recovery role: drop. No evidence.
- Meta-review of orchestration patterns: drop. No evidence.
- Workflow templates: drop. No evidence.
- Human modes (strict/balanced/autonomous): drop. Native project settings and the verification tiers proved sufficient.

## Cut: Change D (diag validates pins)

Considered for v1.2.0 and cut before implementation.
Not re-propose without new evidence.

Change D would have had `scripts/pathfinder-diag.sh` validate that each role ran on its pinned model.
The problem: it needs an independent expectation of each role's pin, and there is no independent source left to check against.
Change B (`scripts/pathfinder-stats.sh` pin compliance) deliberately treats installed frontmatter (`~/.claude/agents/*.md`) as the source of truth for the pin - that is the thing D would be checking, so D cannot reuse it without checking a value against itself.

That leaves two options, both rejected:

1. Read the pin from repo templates instead. This duplicates the existing byte-drift check, which already compares installed frontmatter against repo templates whenever a repo is present.
2. Hardcode a pin table inside diag. This creates a new internal drift surface (the hardcoded table itself can go stale) that nothing revalidates.

Against zero observed drift this week, both forms fail the roadmap's own evidence rule: a fix proposed with no drift to fix.
