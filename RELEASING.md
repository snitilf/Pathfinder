# Releasing

Maintainer checklist. Keep these stamps in sync:

1. Bump `VERSION`.
2. Update `<!-- pathfinder vX.Y.Z -->` in `templates/claude-md/00-header.md`.
3. Add a `CHANGELOG.md` entry.
4. Commit (human), then tag and publish:

```bash
git tag vX.Y.Z
git push && git push --tags
gh release create vX.Y.Z --title "vX.Y.Z" --notes-from-tag
```

If `templates/agents/*.md` changed, keep them identical to a known-good install source before tagging.
