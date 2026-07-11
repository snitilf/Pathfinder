## Verification

Pick a verification level from risk, not habit. Prefer a fresh-context role over self-review for non-trivial work.

| Level | Role | When |
|---|---|---|
| none | - | Trivial work; single-line fixes; pure docs the user said not to verify |
| light | `light-verifier` | Mechanical output from `mech-executor` with named, re-runnable checks |
| standard | `verifier` | Judgment work, multi-file features, non-security bug fixes |
| heavy | `verifier` with exhaustive security instructions | `security-executor` output; auth; secrets; crypto; validation; financial logic |

Rules:

- Tell the verifier the claimed outcome and the paths or diff to exercise. Ask for CONFIRMED or REFUTED with evidence.
- Verifiers never fix anything. Route fixes to the appropriate executor, then re-verify if needed.
- Security-sensitive work always uses heavy verification (standard `verifier` role, maximum thoroughness on abuse cases and trust boundaries).
- Light verification catches missed tests and obvious breaks, not deep design flaws. Keep design review with the orchestrator for judgment work.
- If a project has `.pathfinder/config.json` with `default_verification`, treat it as a soft default hint for non-security work. Global security routing still wins.
