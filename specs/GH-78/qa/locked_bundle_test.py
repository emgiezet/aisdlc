"""Verify the exact GH-78 bundle, then audit the publication cutoff against npm."""

from concurrent.futures import ThreadPoolExecutor
from datetime import datetime
import json
from pathlib import Path
import shutil
import subprocess
import sys
from tempfile import TemporaryDirectory
from urllib.parse import quote
from urllib.request import urlopen

ROOT = Path(__file__).resolve().parents[3]
TOOLS = ROOT / "plugins/slop-guard/tools"
LOCK = "plugins/slop-guard/tools/node/package-lock.json"
CUTOFF = datetime.fromisoformat("2026-10-30T09:56:41+00:00")
EXPECTED = {
    "@eslint/js": "9.39.5",
    "eslint": "9.39.5",
    "eslint-plugin-n": "18.5.0",
    "eslint-plugin-react-hooks": "7.1.1",
    "eslint-plugin-security": "4.2.1",
}


def test_uc_1_strict_locked_install():
    with TemporaryDirectory() as scratch:
        work = Path(scratch)
        for name in ("package.json", "package-lock.json"):
            shutil.copyfile(TOOLS / "node" / name, work / name)
        subprocess.run(
            ["npm", "ci", "--ignore-scripts", "--strict-peer-deps", "--engine-strict"],
            cwd=work,
            check=True,
        )
        for name, expected in EXPECTED.items():
            actual = json.loads((work / "node_modules" / name / "package.json").read_text())["version"]
            if actual != expected:
                raise ValueError(f"{name}: installed {actual}, expected {expected}")
        version = subprocess.check_output([work / "node_modules/.bin/eslint", "--version"], text=True).strip()
        advertised = json.loads((TOOLS / "tools.lock.json").read_text())["tools"]["eslint-stack"]["version"]
        if version != f"v{advertised}":
            raise ValueError(f"ESLint reports {version}, tool lock advertises {advertised}")
    print(f"GH-78 UC-1: installed all five exact versions; ESLint reports {version}")


def versions(lock):
    return {(entry.get("name", loc.rsplit("node_modules/", 1)[-1]), entry["version"])
            for loc, entry in lock["packages"].items() if loc and not entry.get("link")}


def publication(pin):
    name, version = pin
    with urlopen(f"https://registry.npmjs.org/{quote(name, safe='')}", timeout=30) as response:
        raw = json.load(response)["time"][version]
    when = datetime.fromisoformat(raw.replace("Z", "+00:00"))
    if when > CUTOFF:
        raise ValueError(f"{name}@{version} published {raw}, after cutoff {CUTOFF.isoformat()}")
    return when, name, version


def test_uc_2_publication_cutoff(base):
    baseline = json.loads(subprocess.check_output(["git", "show", f"{base}:{LOCK}"], cwd=ROOT))
    new = versions(json.loads((ROOT / LOCK).read_text())) - versions(baseline)
    with ThreadPoolExecutor(max_workers=8) as workers:
        when, name, version = max(workers.map(publication, sorted(new)))
    print(f"GH-78 UC-2: {len(new)} introduced versions within hold; newest {name}@{version} at {when.isoformat()}")


if __name__ == "__main__":
    test_uc_1_strict_locked_install()
    test_uc_2_publication_cutoff(sys.argv[1] if len(sys.argv) == 2 else "9c912df")
