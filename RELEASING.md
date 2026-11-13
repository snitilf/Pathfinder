# Releasing

Release preparation stays local. Agents do not commit, tag, push, or publish. The maintainer controls those actions.

Keep `VERSION`, `.claude-plugin/plugin.json`, the optional policy stamp in `templates/claude-md/00-header.md`, and the current changelog entry in sync. Run `sh scripts/check.sh` from a clean release checkout. Record the native Claude Code version and every skipped integration check in the verification report.

Before a release, test plugin discovery and both skills in a disposable Claude Code session. Exercise the migration guide against a temporary v1 installation that includes customized agent files, unrelated settings and hooks, and saved logs. Check that rollback restores only the selected changes.

Use `docs/EVALUATION.md` for any quality or usage claim. Passing configuration checks does not establish better coding results. The repository contains no measured v2 advantage until a real task comparison is recorded.

The maintainer reviews the diff and creates small commits using `type(scope): summary`. This repository does not authorize agents to push to a real remote or to push a default branch.
