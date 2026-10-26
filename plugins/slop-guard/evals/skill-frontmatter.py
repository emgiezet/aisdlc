"""Offline eval: generated and shipped skills must load in strict skill hosts.

omp loads a portable plugin's skills only when the frontmatter is valid YAML and
follows the agentskills.io field set; any other key drops the skill with
"Unknown skill". This eval applies the same rules.

Run with Python + PyYAML 6.0.3: python3 plugins/slop-guard/evals/skill-frontmatter.py
"""

from pathlib import Path
import os
import subprocess
import tempfile
import unicodedata

import yaml


PLUGIN_ROOT = Path(__file__).resolve().parents[1]
ALLOWED_KEYS = {"name", "description", "license", "allowed-tools", "metadata", "compatibility"}


def name_error(name, directory):
    if not isinstance(name, str) or not name.strip():
        return "missing name"
    name = unicodedata.normalize("NFKC", name.strip())
    if len(name) > 64:
        return "name exceeds 64 characters"
    if name != name.lower():
        return "name must be lowercase"
    if name.startswith("-") or name.endswith("-") or "--" in name:
        return "name has a leading, trailing or doubled hyphen"
    if not all(char.isalnum() or char == "-" for char in name):
        return f"invalid name {name!r}"
    if name != unicodedata.normalize("NFKC", directory):
        return f"name {name!r} does not match directory {directory!r}"
    return None


def metadata_error(metadata, directory):
    unexpected = sorted(set(metadata) - ALLOWED_KEYS)
    if unexpected:
        return f"unexpected frontmatter field(s): {', '.join(unexpected)}"
    error = name_error(metadata.get("name"), directory)
    if error:
        return error
    description = metadata.get("description")
    if not isinstance(description, str) or not description.strip():
        return "description must be a non-empty string"
    if len(description) > 1024:
        return "description exceeds 1024 characters"
    for key in ("license", "allowed-tools", "compatibility"):
        if key in metadata and not isinstance(metadata[key], str):
            return f"{key} must be a string"
    if len(metadata.get("compatibility", "")) > 500:
        return "compatibility exceeds 500 characters"
    extra = metadata.get("metadata", {})
    if not isinstance(extra, dict) or not all(
        isinstance(key, str) and isinstance(value, str) for key, value in extra.items()
    ):
        return "metadata must map strings to strings"
    return None


def evaluate(skills, label):
    failures = 0
    files = sorted(skills.glob("*/SKILL.md"))
    if not (skills / "agent-discipline" / "SKILL.md").is_file():
        print(f"FAIL {label}: agent-discipline is missing")
        failures += 1
    for path in files:
        try:
            lines = path.read_text(encoding="utf-8").splitlines()
            if not lines or lines[0] != "---":
                raise ValueError("missing opening frontmatter delimiter")
            end = lines.index("---", 1)
            metadata = yaml.safe_load("\n".join(lines[1:end]))
            if not isinstance(metadata, dict):
                raise ValueError("frontmatter must be a mapping")
            error = metadata_error(metadata, path.parent.name)
            if error:
                raise ValueError(error)
        except (ValueError, yaml.YAMLError) as error:
            print(f"FAIL {label}/{path.parent.name}: {error}")
            failures += 1
    print(f"{label}: {len(files)} skills, {failures} failures")
    return failures


def main():
    with tempfile.TemporaryDirectory(prefix="slopguard-frontmatter-") as temporary:
        generated = Path(temporary) / "skills"
        subprocess.run(
            ["bash", str(PLUGIN_ROOT / "scripts" / "gen-skills")],
            env={**os.environ, "SLOPGUARD_SKILLS_DIR": str(generated)},
            check=True,
            stdout=subprocess.DEVNULL,
        )
        failures = evaluate(generated, "generated")
        failures += evaluate(PLUGIN_ROOT / "skills", "shipped")
    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
