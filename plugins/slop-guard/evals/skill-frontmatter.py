"""Offline eval: generated and shipped skills must load as YAML metadata.

Run with Python + PyYAML 6.0.3: python3 plugins/slop-guard/evals/skill-frontmatter.py
"""

from pathlib import Path
import os
import subprocess
import tempfile

import yaml


PLUGIN_ROOT = Path(__file__).resolve().parents[1]


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
            if metadata.get("name") != path.parent.name:
                raise ValueError("skill name does not match its directory")
            description = metadata.get("description")
            if not isinstance(description, str) or not description.strip():
                raise ValueError("description must be a non-empty string")
            if not isinstance(metadata.get("user-invocable"), bool):
                raise ValueError("user-invocable must be a boolean")
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
