# Install and migrate Pathfinder

This guide describes user-requested installation and migration. Reading it does not authorize changes to a user's Claude Code configuration. Work in this repository does not install the plugin globally.

## Requirements and source

Use Claude Code v2.1.219 or later, the existing baseline for the role and effort configuration. The v2 source package uses no experimental Code Mode or new plugin engine constraint. Test the actual installed version with native validation. A newer version number alone does not establish compatibility.

Use a trusted checkout. If using a named release or commit, resolve its full commit and keep every source file from that commit. Never silently replace a pinned source with `main`. Review source changes before updating. Never run these operations with sudo.

## Local trial

From the checkout root:

```bash
claude --version
claude plugin validate .
sh scripts/pathfinder-diag.sh --plugin .
claude --plugin-dir "$PWD"
```

Use `sh scripts/check.sh` for strict validation of a clean source package. A personal ignored CLAUDE.md in a working checkout can cause native strict validation to warn because plugin-root instructions are not loaded. Do not remove or rewrite personal instructions to clear that warning.

The final command loads Pathfinder for that session. It does not install the plugin into global settings. It still starts a normal Claude session with the user's existing configuration. Finish the legacy migration below before judging v2 if v1 is already active.

Check that `/pathfinder:work`, `/pathfinder:review`, `pathfinder:scout`, and `pathfinder:verifier` are available. The built-in Explore agent remains unchanged. The plugin does not write its policy fragments into CLAUDE.md. A helper's presence does not prove it ran on the requested model.

Use this local loading command when you want Pathfinder. Persistent marketplace installation is not configured by this repository. See [Claude Code plugin installation](https://code.claude.com/docs/en/plugins) if you want to manage a reviewed package through a marketplace. Do not run marketplace registration or installation implicitly.

## Optional policy

Prefer the explicit `/pathfinder:work` skill before adding always-loaded instructions. If the user requests an installed policy, show the exact destination and diff first. Assemble only `00-header.md`, `10-core.md`, `20-verification.md`, and `90-footer.md` from `templates/claude-md/`, in that order. Add `60-working-style.md` before the footer only when explicitly requested.

Install the policy only in a scope where the plugin is loaded. A global policy that refers to unloaded `pathfinder:*` agents cannot work as written. Without the plugin, use native Claude behavior rather than claiming independent Pathfinder verification occurred.

Before replacing a policy, require exactly one standalone begin marker followed by exactly one standalone end marker. Reject reversed, repeated, unmatched, overlapping, or ambiguous markers. With no markers, append the reviewed block only after approval. Preserve all text outside the exact block. Confirm the final markers and preserve the original file for rollback.

## Migrate an existing v1 installation

This is a deliberate v1-to-v2 change, not an in-place seven-role update. Do not copy the two v2 templates over the legacy agents and leave the old policy active.

1. Inspect the installed `~/.claude/pathfinder/INSTALL`, `VERSION`, the marked block in `~/.claude/CLAUDE.md`, root role files, and Pathfinder hook entries in `~/.claude/settings.json`. Record which source commit originally supplied each owned file. Do not treat a filename or marker as proof that all its content is unmodified.
2. Present a concrete migration plan with exact files, diffs, hook entries, and backup destinations. Get approval before changing the installed configuration. Preserve the current main model, fallback chain, permissions, unrelated hooks, and all logs. Do not restore an entire old settings backup.
3. Create a private backup outside `~/.claude/agents/` before each approved edit. Record original paths, bytes, modes, and whether a file was absent. Use mode 700 directories and mode 600 backup data. Check every destination and parent directory for symlinks; stop instead of writing through them. Write changed files with private temporary files in the same directory and atomic rename. Re-read the approved input immediately before writing; if it changed, stop and regenerate the diff.
4. Remove only the approved v1 marked policy block. Require one standalone begin marker followed by one standalone end marker before editing. Preserve all outside text byte for byte. If the user customized the block, show those differences and decide where to retain the useful rules. Do not remove the whole CLAUDE.md file merely because Pathfinder used it.
5. Review these legacy root roles: `scout`, `Explore`, `mech-executor`, `executor`, `light-verifier`, `verifier`, and `security-executor`. Compare each installed file byte for byte against its template from the immutable recorded v1 source commit, for example with `git show <source_commit>:templates/agents/<role>.md`. Confirm that the commit is available and actually belongs to the installed source. Never compare a legacy role against a v2 template to establish ownership. Remove an approved root file only if it matches that v1 source. If the source is unavailable or the file differs, leave it intact and show the diff. Archive a customized role outside the active agents tree only after explicit approval. Do not sweep nested agents or unrelated files.
6. Identify optional Pathfinder logging and version-reminder hook entries by their exact configured commands and helper paths. Remove only the entries included in the approved plan. Keep unrelated entries in the same event arrays. If the user wants to retain logging, leave the helper and entries intact and review the [optional hook instructions](../templates/hooks/pathfinder-telemetry.md) separately. No hooks are part of the v2 plugin manifest. Keep logs and installed helper files unless their removal was separately requested.
7. Validate the edited settings JSON and make sure that model, fallback, permission, and unrelated hook values are unchanged. Make sure that outside policy text and preserved agent files match their backups. If legacy customized roles remain active, explain their possible influence before comparing v2 with native Claude.
8. Restart Claude Code using the local plugin command. Check skill and helper discovery. Run an explicitly requested small scout question and an independent review only when the user authorizes actual model work. Report skipped live checks as unexercised. Do not interpret successful source validation as a live helper test.

Do not change or delete the legacy `INSTALL`, `VERSION`, logs, or first-install settings backup merely to make them look like a v2 installation. They describe the old manual installation. Legacy diagnostics remain useful for that state; plugin-source diagnostics are separate.

## Optional helpers

Keep the logging and version reminder disabled unless the user wants information beyond native `/usage` reports. Existing logs remain readable with `scripts/pathfinder-stats.sh`. The helper log records helper usage only and is not a full-session cost report. See [evaluation](../docs/EVALUATION.md).

Review [telemetry](../templates/hooks/pathfinder-telemetry.md) and [version reminder](../templates/hooks/pathfinder-version-watch.md) before an explicit hook installation. Merge only the approved entries. Do not grant permissions or change the main model to make a hook run. Keep a stable executable helper path and retain backups of the exact changed settings entries.

## Remove v2 and roll back

For a local trial, exit Claude Code and start the next session without `--plugin-dir`. No plugin files need to be deleted from user configuration. Remove any optional v2 policy block only after the same ordered-marker and backup checks described above.

To undo a migration, first exit sessions using the plugin. Compare the current files with the recorded post-migration state. Restore only the approved legacy files, policy block, and hook entries from their private backups when their destinations still match that state. Preserve subsequent user edits; if a destination changed, show a three-way comparison and ask how to reconcile it. Do not restore the whole settings file over newer unrelated changes. Preserve original modes and absent-file state where appropriate. Restart with the previous loading method and check the restored configuration.

If a plugin was installed separately through a marketplace, disable or uninstall that named plugin using Claude Code's plugin manager. Do not delete other plugins, marketplace registrations, settings, or logs. Registry publication and global installation are separate actions and are not performed by these source changes.
