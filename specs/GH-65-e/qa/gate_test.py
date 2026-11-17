#!/usr/bin/env python3
"""Unit tests for the shipped gate's decisions; detector behavior uses real-tool suite."""
import json
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[3]
PLUGIN = ROOT / 'plugins/slop-guard'
RULE = 'slopguard.react.href-js-scheme'
AP = 'AP-TS-SEC-004'


class GateTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.work = Path(self.temp.name)
        self.plugin = self.work / 'plugin'
        shutil.copytree(PLUGIN / 'rules/opengrep', self.plugin / 'rules/opengrep')
        self.results = []
        for file in sorted((self.plugin / 'rules/opengrep').glob('*.yaml')):
            entries = re.split(r'^\s*- id:\s*', file.read_text(), flags=re.M)[1:]
            for entry in entries:
                rule = entry.splitlines()[0].strip()
                ap = re.search(r'^\s+ap_id:\s*(\S+)', entry, re.M).group(1)
                for fixture in (PLUGIN / 'tests/fixtures').glob(f'*/bad/{ap}*.*'):
                    self.results.append({'check_id': rule, 'path': '__SAMPLES__/' + str(fixture.relative_to(PLUGIN / 'tests/fixtures'))})

    def drive(self, results=None, raw=None, status=0, skip=False):
        payload = raw if raw is not None else json.dumps({'results': self.results if results is None else results, 'errors': []})
        tool = self.work / 'opengrep'
        tool.write_text('#!/usr/bin/env python3\nimport sys\nprint(' + repr(payload) + '.replace("__SAMPLES__", sys.argv[-1]))\nsys.exit(' + str(status) + ')\n')
        tool.chmod(0o755)
        script = '''
set -uo pipefail
PLUGIN_ROOT="$1"; _IT_FIXTURES="$2"; _IT_CUR_PROJ="$3"; tool="$4"
PASS=0; FAIL=0
it_project() { mkdir -p "$_IT_CUR_PROJ/vendor/bin"; }
lock_bin() { printf opengrep; }
it_ok() { printf 'PASS %s\n' "$1"; PASS=$((PASS+1)); }
it_bad() { printf 'FAIL %s: %s\n' "$1" "$2"; FAIL=$((FAIL+1)); }
'''
        # Separate helper definition keeps the skip boundary explicit.
        script += 'it_skip_unless_tool() { printf "SKIP opengrep\\n"; return 1; }\n' if skip else 'it_skip_unless_tool() { ln -s "$tool" "$_IT_CUR_PROJ/vendor/bin/opengrep"; }\n'
        script += '. "$5"\n[ "$FAIL" -eq 0 ]\n'
        return subprocess.run(['bash', '-c', script, 'gate-test', str(self.plugin), str(PLUGIN / 'tests/fixtures'), str(self.work / 'project'), str(tool), str(PLUGIN / 'tests/integration/opengrep.sh')], text=True, capture_output=True)

    def test_UC_13_accepts_complete_exact_id_ap_results(self):
        """UC-13: complete exact-ID/AP results pass."""
        result = self.drive()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_UC_13_missing_own_bad_hit_names_rule(self):
        """UC-13: absent own bad result fails with rule ID."""
        result = self.drive([r for r in self.results if r['check_id'] != RULE])
        self.assertNotEqual(result.returncode, 0)
        self.assertIn(f'FAIL GH-65-e UC-13: {RULE} detects its own {AP} fixture', result.stdout)

    def test_UC_13_other_rule_cannot_satisfy_own_ap(self):
        """UC-13: another rule cannot supply the required hit."""
        results = [dict(r, check_id='slopguard.other.rule') if r['check_id'] == RULE else r for r in self.results]
        result = self.drive(results)
        self.assertIn(f'FAIL GH-65-e UC-13: {RULE} detects its own {AP} fixture', result.stdout)

    def test_UC_13_failed_scan_cannot_pass_with_valid_results(self):
        """UC-13: nonzero scans cannot satisfy the contract."""
        result = self.drive(status=2)
        self.assertIn(f'FAIL GH-65-e UC-13: {RULE}', result.stdout)
        self.assertNotEqual(result.returncode, 0)

    def test_UC_13_invalid_json_cannot_pass(self):
        """UC-13: invalid JSON cannot satisfy the contract."""
        result = self.drive(raw='not JSON')
        self.assertIn(f'FAIL GH-65-e UC-13: {RULE}', result.stdout)
        self.assertNotEqual(result.returncode, 0)

    def test_UC_13_discovers_new_rule_and_reports_missing_hit(self):
        """UC-13: newly configured rules enter the gate automatically."""
        with (self.plugin / 'rules/opengrep/qa-new.yaml').open('w') as file:
            file.write('rules:\n  - id: slopguard.qa.new-rule\n    metadata:\n      ap_id: AP-TS-SEC-004\n')
        result = self.drive()
        self.assertIn('FAIL GH-65-e UC-13: slopguard.qa.new-rule detects its own AP-TS-SEC-004 fixture', result.stdout)

    def test_UC_14_good_hit_outside_own_ap_names_offending_rule(self):
        """UC-14: a different AP's good fixture still fails the offending ID."""
        result = self.drive(self.results + [{'check_id': RULE, 'path': '__SAMPLES__/php/good/AP-PHP-SEC-001.php'}])
        self.assertIn(f'FAIL GH-65-e UC-14: {RULE} is silent across all good fixtures', result.stdout)
        self.assertNotEqual(result.returncode, 0)

    def test_UC_13_offline_missing_tool_skips_without_scanning(self):
        """UC-13: missing OpenGrep preserves the offline skip."""
        result = self.drive(skip=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, 'SKIP opengrep\n')


if __name__ == '__main__':
    unittest.main(verbosity=2)
