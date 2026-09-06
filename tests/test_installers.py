#!/usr/bin/env python3
"""Isolated installer regression tests; no dependencies or live config writes.

Run: python3 tests/test_installers.py
Both dialects run when their interpreters are available. Fixtures use resolved
temp paths because installers deliberately reject symlinked ancestors.
"""

import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


REPO = Path(__file__).resolve().parents[1]
MANIFEST = '.metaskills-manifest'
ROOTS = ('.claude/skills', '.config/opencode/skill', '.codex/skills',
         '.config/opencode/command', '.codex/prompts',
         '.config/opencode/agent', '.claude/agents', '.codex/agents')


def write(path, text):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(text.encode('utf-8'))


def snapshot(root):
    result = {}
    for path in sorted(root.rglob('*')):
        name = str(path.relative_to(root))
        if path.is_symlink():
            result[name] = ('link', os.readlink(path))
        elif path.is_dir():
            result[name] = ('dir',)
        else:
            result[name] = ('file', path.read_bytes(), path.stat().st_mtime_ns)
    return result


class InstallerCases:
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='metaskills-test-')
        self.addCleanup(self.temp.cleanup)
        self.base = Path(self.temp.name).resolve()
        self.home = self.base / 'home'
        self.home.mkdir()
        self.repo = self.base / 'repo'
        self.repo.mkdir()
        self.env = dict(os.environ, HOME=str(self.home), USERPROFILE=str(self.home),
                        XDG_CONFIG_HOME=str(self.home / '.config'),
                        POWERSHELL_TELEMETRY_OPTOUT='1')
        for script in ('sync.sh', 'sync.ps1'):
            shutil.copy2(REPO / script, self.repo / script)
        write(self.repo / 'skills/demo/SKILL.md',
              '---\nname: demo\ndescription: Fixture skill\n---\nBody\n')
        write(self.repo / 'commands/demo.md', 'Use demo with $ARGUMENTS\n')
        for dialect in ('claude', 'opencode'):
            write(self.repo / f'agents/{dialect}/worker.md', '---\nname: worker\n---\nBody\n')
        write(self.repo / 'agents/codex/worker.toml', "developer_instructions = '''\nBody\n'''\n")
        subprocess.run(['git', 'init', '-q', str(self.repo)], env=self.env, check=True)

    def run_installer(self, mode='', success=True, repo=None):
        repo = repo or self.repo
        if self.dialect == 'bash':
            command = ['bash', str(repo / 'sync.sh')]
            flag = {'check': '--check', 'dry': '--dry-run'}.get(mode)
        else:
            command = ['pwsh', '-NoLogo', '-NoProfile', '-NonInteractive',
                       '-File', str(repo / 'sync.ps1')]
            flag = {'check': '-Check', 'dry': '-WhatIf'}.get(mode)
        if flag:
            command.append(flag)
        result = subprocess.run(command, env=self.env, cwd=repo, text=True,
                                stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=120)
        self.assertEqual(result.returncode == 0, success, result.stdout)
        return result.stdout

    def assert_rejected_read_only(self):
        before = snapshot(self.home)
        outside = snapshot(self.base / 'outside') if (self.base / 'outside').is_dir() else None
        for mode in ('', 'dry'):
            self.run_installer(mode, success=False)
            self.assertEqual(snapshot(self.home), before)
            if outside is not None:
                self.assertEqual(snapshot(self.base / 'outside'), outside)

    def test_clean_install_reinstall(self):
        self.run_installer()
        for root in ROOTS:
            self.assertTrue((self.home / root / MANIFEST).is_file())
        write(self.home / ROOTS[0] / 'demo/extra.md', 'old')
        self.run_installer()
        self.assertFalse((self.home / ROOTS[0] / 'demo/extra.md').exists())
        self.assertEqual((self.home / ROOTS[0] / 'demo/SKILL.md').read_bytes(),
                         (self.repo / 'skills/demo/SKILL.md').read_bytes())

    def test_stale_deletion_and_unmanaged_legacy_preservation(self):
        root = self.home / ROOTS[0]
        write(root / 'obsolete/data', 'owned')
        write(root / MANIFEST, 'obsolete')  # No final newline.
        write(root / 'plan/user.md', 'unowned legacy')
        self.run_installer()
        self.assertFalse((root / 'obsolete').exists())
        self.assertEqual((root / 'plan/user.md').read_text(), 'unowned legacy')

    def test_unmanaged_collision_last_root(self):
        write(self.home / ROOTS[-1] / 'worker.toml', 'user content')
        self.assert_rejected_read_only()

    def test_invalid_manifest_all_roots_preflight(self):
        invalid = ('.', '..', '../outside', '/absolute', 'a/b', 'a\\b', 'C:escape',
                   'CON', 'nul.txt', 'COM1.md', 'trailing.', 'space name',
                   'demo\nDEMO\n', '\n', 'bad\x00name')
        for name in invalid:
            with self.subTest(name=repr(name)):
                write(self.home / ROOTS[-1] / MANIFEST, name)
                self.assert_rejected_read_only()

    def test_crlf_manifest(self):
        root = self.home / ROOTS[-1]
        write(root / MANIFEST, 'obsolete\r\n')
        write(root / 'obsolete', 'owned')
        self.run_installer()
        self.assertFalse((root / 'obsolete').exists())

    def test_malformed_cr_manifest(self):
        for text in ('a\rb\n', 'obsolete\r\r\n'):
            with self.subTest(text=repr(text)):
                write(self.home / ROOTS[-1] / MANIFEST, text)
                self.assert_rejected_read_only()

    def test_hard_linked_manifest_preserves_external_file(self):
        external = self.base / 'outside/manifest'
        write(external, 'obsolete\n')
        manifest = self.home / ROOTS[-1] / MANIFEST
        manifest.parent.mkdir(parents=True)
        os.link(external, manifest)
        write(manifest.parent / 'obsolete', 'owned')
        before = snapshot(self.home)
        self.run_installer('dry')
        self.assertEqual(snapshot(self.home), before)
        self.assertTrue(os.path.samefile(external, manifest))
        self.assertEqual(external.read_bytes(), b'obsolete\n')
        self.run_installer()
        self.assertEqual(external.read_bytes(), b'obsolete\n')
        self.assertFalse(os.path.samefile(external, manifest))
        self.assertEqual(manifest.read_text().splitlines(), ['worker.toml'])
        self.assertFalse((manifest.parent / 'obsolete').exists())

    def link(self, target, path, directory=False):
        path.parent.mkdir(parents=True, exist_ok=True)
        try:
            path.symlink_to(target, target_is_directory=directory)
        except OSError as error:
            self.skipTest(f'Symlink creation unavailable: {error}')

    def test_symlink_root(self):
        outside = self.base / 'outside'
        outside.mkdir()
        self.link(outside, self.home / ROOTS[-1], True)
        self.assert_rejected_read_only()

    def test_symlink_ancestor(self):
        outside = self.base / 'outside'
        outside.mkdir()
        self.link(outside, self.home / '.codex', True)
        self.assert_rejected_read_only()

    def test_symlink_manifest(self):
        outside = self.base / 'outside'
        write(outside / 'manifest', 'worker.toml\n')
        self.link(outside / 'manifest', self.home / ROOTS[-1] / MANIFEST)
        self.assert_rejected_read_only()

    def test_dangling_destination_symlink(self):
        self.link(self.base / 'missing', self.home / ROOTS[-1] / 'worker.toml')
        self.assert_rejected_read_only()

    def test_managed_nested_symlink(self):
        root = self.home / ROOTS[0]
        write(root / MANIFEST, 'obsolete\n')
        outside = self.base / 'outside'
        write(outside / 'data', 'untouched')
        self.link(outside, root / 'obsolete/link', True)
        self.assert_rejected_read_only()

    def test_source_symlink(self):
        outside = self.base / 'outside'
        write(outside / 'data', 'untouched')
        self.link(outside / 'data', self.repo / 'skills/demo/link.md')
        self.assert_rejected_read_only()

    def test_source_root_symlink(self):
        outside = self.base / 'outside'
        (self.repo / 'skills').rename(outside)
        self.link(outside, self.repo / 'skills', True)
        self.assert_rejected_read_only()

    def test_source_lint_before_mutations(self):
        write(self.repo / 'skills/demo/SKILL.md', 'invalid\n')
        self.assert_rejected_read_only()

    def test_crlf_skill_frontmatter(self):
        write(self.repo / 'skills/demo/SKILL.md',
              '---\r\nname: demo\r\ndescription: Fixture skill\r\n---\r\nBody\r\n')
        self.run_installer('check')

    def test_bidirectional_wrapper_lint(self):
        (self.repo / 'commands/demo.md').unlink()
        self.assert_rejected_read_only()
        write(self.repo / 'commands/demo.md', '$ARGUMENTS\n')
        write(self.repo / 'commands/orphan.md', '$ARGUMENTS\n')
        self.assert_rejected_read_only()

    def test_case_collision(self):
        write(self.home / ROOTS[-1] / 'WORKER.toml', 'user')
        self.assert_rejected_read_only()

    def test_invalid_source_name(self):
        write(self.repo / 'skills/demo/CON.txt', 'unsafe on Windows')
        self.assert_rejected_read_only()

    def test_stale_case_alias(self):
        root = self.home / ROOTS[-1]
        write(root / MANIFEST, 'obsolete\n')
        write(root / 'OBSOLETE', 'case alias')
        self.assert_rejected_read_only()

    def test_empty_source_sets(self):
        shutil.rmtree(self.repo / 'skills/demo')
        (self.repo / 'commands/demo.md').unlink()
        self.assert_rejected_read_only()

    def test_root_and_manifest_type_conflicts(self):
        root = self.home / ROOTS[-1]
        write(root, 'not a directory')
        self.assert_rejected_read_only()
        root.unlink()
        (root / MANIFEST).mkdir(parents=True)
        self.assert_rejected_read_only()

    def test_dry_run_clean_and_installed(self):
        before = snapshot(self.home)
        self.run_installer('dry')
        self.assertEqual(snapshot(self.home), before)
        self.run_installer()
        root = self.home / ROOTS[-1]
        write(root / MANIFEST, 'worker.toml\nobsolete\n')
        write(root / 'obsolete', 'owned')
        before = snapshot(self.home)
        self.run_installer('dry')
        self.assertEqual(snapshot(self.home), before)

    def test_repository_lint_and_dry_run_isolated(self):
        self.run_installer('check', repo=REPO)
        before = snapshot(self.home)
        self.run_installer('dry', repo=REPO)
        self.assertEqual(snapshot(self.home), before)


@unittest.skipUnless(shutil.which('bash') and os.name != 'nt', 'Unix Bash unavailable')
class BashTests(InstallerCases, unittest.TestCase):
    dialect = 'bash'


@unittest.skipUnless(shutil.which('pwsh'), 'pwsh unavailable')
class PowerShellTests(InstallerCases, unittest.TestCase):
    dialect = 'pwsh'


if __name__ == '__main__':
    unittest.main(verbosity=2)
