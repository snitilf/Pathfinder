#!/usr/bin/env python3
"""Check Pathfinder's source contract without loading user configuration."""

import argparse
import json
import re
import shutil
import sys
from pathlib import Path


def check(root, stage=None):
    root = root.resolve(strict=True)
    sources = []

    def source(relative):
        path = root / relative
        resolved = path.resolve(strict=True)
        if not resolved.is_relative_to(root) or not resolved.is_file():
            raise ValueError(f"source must be a contained regular file: {relative}")
        sources.append((resolved, relative))
        return resolved.read_text()

    def frontmatter(relative):
        lines = source(relative).splitlines()
        if not lines or lines[0] != "---":
            raise ValueError(f"missing frontmatter: {relative}")
        try:
            end = lines.index("---", 1)
        except ValueError:
            raise ValueError(f"unclosed frontmatter: {relative}") from None
        fields = {}
        for line in lines[1:end]:
            key, separator, value = line.partition(":")
            if separator:
                if key in fields:
                    raise ValueError(f"duplicate frontmatter key: {relative}")
                fields[key] = value.strip()
        return fields

    manifest = json.loads(source(".claude-plugin/plugin.json"))
    if not isinstance(manifest, dict) or manifest.get("name") != "pathfinder":
        raise ValueError("manifest must name the pathfinder plugin")
    version = source("VERSION").strip()
    if not re.fullmatch(r"\d+\.\d+\.\d+", version) or manifest.get("version") != version:
        raise ValueError("manifest version must match a valid VERSION")
    expected = ["./templates/agents/scout.md", "./templates/agents/verifier.md"]
    if manifest.get("agents") != expected:
        raise ValueError("manifest must declare exactly the scout and verifier templates")
    passive = {"name", "version", "description", "author", "repository", "license", "homepage", "keywords", "agents"}
    if set(manifest) - passive:
        raise ValueError("unexpected plugin surface; review manifest fields")
    for path in ("hooks", "commands", "agents", ".mcp.json", ".lsp.json", "settings.json", "workflows"):
        if (root / path).exists() or (root / path).is_symlink():
            raise ValueError(f"unexpected default plugin surface: {path}")
    for role, relative in zip(("scout", "verifier"), expected):
        fields = frontmatter(relative)
        if fields.get("name") != role or not fields.get("description"):
            raise ValueError(f"invalid role name or description: {relative}")
        if not fields.get("model") or not fields.get("effort"):
            raise ValueError(f"role model and effort must be explicit: {relative}")
    roles = sorted(path.name for path in (root / "templates/agents").glob("*.md"))
    if roles != ["scout.md", "verifier.md"]:
        raise ValueError("canonical templates must contain exactly two roles")
    skills = sorted(path.parent.name for path in (root / "skills").glob("*/SKILL.md"))
    if skills != ["review", "work"]:
        raise ValueError("plugin must contain exactly work and review skills")
    for skill in skills:
        fields = frontmatter(f"skills/{skill}/SKILL.md")
        if fields.get("name") != skill or fields.get("disable-model-invocation") != "true":
            raise ValueError(f"skill must have its expected name and require invocation: {skill}")
        if "allowed-tools" in fields or "model" in fields:
            raise ValueError(f"skill must preserve permissions and main model: {skill}")
    source("README.md")
    source("LICENSE")
    if json.loads(source("templates/settings.snippet.json")) != {}:
        raise ValueError("settings snippet must preserve user settings")
    policy = "".join(source(f"templates/claude-md/{name}") for name in
                     ("00-header.md", "10-core.md", "20-verification.md", "90-footer.md"))
    lines = [line.strip() for line in policy.splitlines()]
    begin, end = "<!-- pathfinder:begin -->", "<!-- pathfinder:end -->"
    if lines.count(begin) != 1 or lines.count(end) != 1 or lines.index(begin) >= lines.index(end):
        raise ValueError("optional policy must have one ordered standalone marker pair")
    if lines.count(f"<!-- pathfinder v{version} -->") != 1:
        raise ValueError("optional policy stamp must match VERSION")
    if stage is not None:
        stage = stage.resolve(strict=True)
        if stage == root or root.is_relative_to(stage) or stage.is_relative_to(root) or any(stage.iterdir()):
            raise ValueError("staging requires an empty directory outside the source")
        for path, relative in sources:
            target = stage / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(path, target)
    print(f"OK: Pathfinder {version} plugin source, two roles and two explicit skills")
    print("result: ok (source only; no installed configuration or live model checked)")


def main():
    if sys.version_info < (3, 9):
        print("FAIL: Python 3.9 or later is required", file=sys.stderr)
        return 1
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("root", type=Path)
    parser.add_argument("--stage", type=Path)
    args = parser.parse_args()
    try:
        check(args.root, args.stage)
    except (OSError, ValueError, TypeError) as error:
        message = "".join(character for character in str(error) if character.isprintable())
        print(f"FAIL: {message}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
