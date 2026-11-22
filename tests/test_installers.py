#!/usr/bin/env python3
"""Isolated installer regression tests; no dependencies or live config writes.

Run: python tests/test_installers.py (Windows) or python3 tests/test_installers.py (Linux)
Exercises sync.ps1 on Windows (auto-discovering Windows PowerShell 5.1 and pwsh)
and sync.sh on Linux/Unix. Fixtures use resolved temp paths because installers
deliberately reject symlinked or junctioned ancestors.
"""

import errno
import os
from pathlib import Path
import shutil
import stat
import subprocess
import tempfile
import unittest


REPO = Path(__file__).resolve().parents[1]
MANIFEST = '.metaskills-manifest'
ROOTS = ('.claude/skills', '.config/opencode/skill', '.codex/skills',
         '.config/opencode/command', '.codex/prompts',
         '.config/opencode/agent', '.claude/agents', '.codex/agents')
POWERSHELL = shutil.which('powershell.exe') if os.name == 'nt' else None
PWSH = shutil.which('pwsh') if os.name == 'nt' else None
SYMLINK_SKIP_ERRNOS = tuple(
    getattr(errno, name)
    for name in ('EPERM', 'EACCES', 'ENOSYS', 'EOPNOTSUPP')
    if hasattr(errno, name)
)


def write(path, text):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(text.encode('utf-8'))


def is_reparse_link(path):
    if path.is_symlink():
        return True
    if os.name == 'nt':
        try:
            return bool(os.lstat(path).st_file_attributes & stat.FILE_ATTRIBUTE_REPARSE_POINT)
        except OSError:
            return False
    return False


def snapshot(root, ignore_top=()):
    result = {}

    def walk(directory):
        for path in sorted(directory.iterdir(), key=lambda p: p.name):
            if directory == root and path.name in ignore_top:
                continue
            name = str(path.relative_to(root))
            if is_reparse_link(path):
                try:
                    target = os.readlink(path)
                except OSError:
                    target = None
                result[name] = ('link', target)
            elif path.is_dir():
                result[name] = ('dir',)
                walk(path)
            else:
                result[name] = ('file', path.read_bytes(), path.stat().st_mtime_ns)

    walk(root)
    return result


class InstallerCases:
    installer_kind = None
    shell_exe = None

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='metaskills-test-')
        self.addCleanup(self.temp.cleanup)
        self.base = Path(self.temp.name).resolve()
        self.home = self.base / 'home'
        self.home.mkdir()
        self.repo = self.base / 'repo'
        self.repo.mkdir()
        self.env = dict(
            os.environ,
            HOME=str(self.home),
            USERPROFILE=str(self.home),
            XDG_CONFIG_HOME=str(self.home / '.config'),
            POWERSHELL_TELEMETRY_OPTOUT='1',
        )
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
        if self.installer_kind == 'bash':
            command = [self.shell_exe, str(repo / 'sync.sh')]
            flag = {'check': '--check', 'dry': '--dry-run'}.get(mode)
            if flag:
                command.append(flag)
        elif self.installer_kind == 'powershell':
            command = [
                self.shell_exe,
                '-NoProfile',
                '-NonInteractive',
                '-ExecutionPolicy', 'Bypass',
                '-File', str(repo / 'sync.ps1'),
            ]
            flag = {'check': '-Check', 'dry': '-WhatIf'}.get(mode)
            if flag:
                command.append(flag)
        else:
            raise AssertionError(f'Unknown installer_kind: {self.installer_kind}')
        result = subprocess.run(
            command,
            env=self.env,
            cwd=repo,
            text=True,
            encoding='utf-8',
            errors='replace',
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            timeout=120,
        )
        self.assertEqual(result.returncode == 0, success, result.stdout)
        return result.stdout

    def home_snapshot(self):
        # PowerShell runtimes create USERPROFILE\AppData startup/cache dirs on launch.
        ignore = ('AppData',) if self.installer_kind == 'powershell' else ()
        return snapshot(self.home, ignore_top=ignore)

    def assert_rejected_read_only(self, expected=None):
        before = self.home_snapshot()
        outside = snapshot(self.base / 'outside') if (self.base / 'outside').is_dir() else None
        for mode in ('', 'dry'):
            output = self.run_installer(mode, success=False)
            if expected is not None:
                self.assertIn(expected, output)
            self.assertEqual(self.home_snapshot(), before)
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
        before = self.home_snapshot()
        self.run_installer('dry')
        self.assertEqual(self.home_snapshot(), before)
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
            winerror = getattr(error, 'winerror', None)
            if (os.name == 'nt' and winerror == 1314) or (
                os.name != 'nt' and error.errno in SYMLINK_SKIP_ERRNOS
            ):
                self.skipTest(f'Symlink creation unavailable: {error}')
            raise

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
        # Larger than the 64 KiB pipe buffer, so piping into an early-exiting
        # matcher under pipefail would fail deterministically.
        text = ('---\r\nname: demo\r\ndescription: Fixture skill\r\n---\r\n'
                + 'Body line padding the skill past the pipe buffer.\r\n' * 1500)
        self.assertGreater(len(text.encode('utf-8')), 64 * 1024)
        write(self.repo / 'skills/demo/SKILL.md', text)
        self.run_installer('check')
        self.run_installer()
        self.assertEqual((self.home / ROOTS[0] / 'demo/SKILL.md').read_bytes(),
                         text.encode('utf-8'))

    def test_crlf_skill_frontmatter_wrong_name(self):
        write(self.repo / 'skills/demo/SKILL.md',
              '---\r\nname: demox\r\ndescription: Fixture skill\r\n---\r\nBody\r\n')
        self.assertIn("frontmatter name != 'demo'", self.run_installer('check', success=False))
        self.assert_rejected_read_only()

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
        bad_space = self.repo / 'skills/demo/space name.md'
        write(bad_space, 'unsafe space name\n')
        self.assert_rejected_read_only()
        bad_space.unlink()

        reserved = self.repo / 'skills/demo/CON.txt'
        try:
            write(reserved, 'unsafe on Windows\n')
        except OSError:
            if os.name == 'nt':
                return
            raise
        if os.name == 'nt' and reserved.name not in {p.name for p in reserved.parent.iterdir()}:
            return
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
        before = self.home_snapshot()
        self.run_installer('dry')
        self.assertEqual(self.home_snapshot(), before)
        self.run_installer()
        root = self.home / ROOTS[-1]
        write(root / MANIFEST, 'worker.toml\nobsolete\n')
        write(root / 'obsolete', 'owned')
        before = self.home_snapshot()
        self.run_installer('dry')
        self.assertEqual(self.home_snapshot(), before)

    def test_repository_lint_and_dry_run_isolated(self):
        self.run_installer('check', repo=REPO)
        before = self.home_snapshot()
        self.run_installer('dry', repo=REPO)
        self.assertEqual(self.home_snapshot(), before)

    def test_skill_missing_description_and_missing_skill_md(self):
        write(self.repo / 'skills/demo/SKILL.md', '---\nname: demo\n---\nBody\n')
        self.assertIn('skills/demo/SKILL.md has no description',
                      self.run_installer('check', success=False))
        self.assert_rejected_read_only('skills/demo/SKILL.md has no description')

        (self.repo / 'skills/demo/SKILL.md').unlink()
        self.assertIn('skills/demo has no SKILL.md',
                      self.run_installer('check', success=False))
        self.assert_rejected_read_only('skills/demo has no SKILL.md')

    def test_command_missing_arguments(self):
        write(self.repo / 'commands/demo.md', 'Use demo without args\n')
        self.assertIn('commands/demo.md does not pass $ARGUMENTS',
                      self.run_installer('check', success=False))
        self.assert_rejected_read_only('commands/demo.md does not pass $ARGUMENTS')

    def test_agent_dialect_body_mismatch(self):
        write(self.repo / 'agents/opencode/worker.md', '---\nname: worker\n---\nDifferent\n')
        self.assertIn('agents/worker: claude and opencode bodies differ',
                      self.run_installer('check', success=False))
        self.assert_rejected_read_only('agents/worker: claude and opencode bodies differ')

        write(self.repo / 'agents/opencode/worker.md', '---\nname: worker\n---\nBody\n')
        write(self.repo / 'agents/codex/worker.toml', "developer_instructions = '''\nDifferent\n'''\n")
        self.assertIn('agents/worker: claude and codex bodies differ',
                      self.run_installer('check', success=False))
        self.assert_rejected_read_only('agents/worker: claude and codex bodies differ')

    def test_agent_missing_dialect(self):
        files = {
            'claude': ('agents/claude/extra.md', '---\nname: extra\n---\nBody\n'),
            'opencode': ('agents/opencode/extra.md', '---\nname: extra\n---\nBody\n'),
            'codex': ('agents/codex/extra.toml', "developer_instructions = '''\nBody\n'''\n"),
        }
        for missing_dialect, (missing_rel, _) in files.items():
            with self.subTest(missing=missing_dialect):
                for dialect, (rel, content) in files.items():
                    path = self.repo / rel
                    if dialect == missing_dialect:
                        if path.exists():
                            path.unlink()
                    else:
                        write(path, content)
                expected = f'{missing_rel} missing'
                self.assertIn(expected, self.run_installer('check', success=False))
                self.assert_rejected_read_only(expected)

    def test_powershell_only_samples_rejected(self):
        cases = (
            ('fence.md', '```powershell', 'powershell fence in skills/demo/fence.md:1'),
            ('one-line-cmd.md', 'Set-Content out.txt "value"',
             'PowerShell-only command in skills/demo/one-line-cmd.md:1'),
            ('indented-cmd.md', 'Notes\n  Remove-Item tmp\n',
             'PowerShell-only command in skills/demo/indented-cmd.md:2'),
            ('gh-stop-parse.md', 'Notes\ngh --% issue view 1\n',
             'PowerShell-only command in skills/demo/gh-stop-parse.md:2'),
        )
        for filename, content, expected in cases:
            with self.subTest(file=filename):
                path = self.repo / 'skills/demo' / filename
                write(path, content)
                self.assertIn(expected, self.run_installer('check', success=False))
                self.assert_rejected_read_only(expected)
                path.unlink()

    def test_utf8_no_bom_byte_0x97_passes_check_and_install(self):
        text = 'Markers: \u25cf bullet and \u25c0 arrow\n'
        raw = text.encode('utf-8')
        self.assertFalse(raw.startswith(b'\xef\xbb\xbf'))
        self.assertIn(b'\x97', raw)
        write(self.repo / 'skills/demo/symbols.txt', text)
        write(self.repo / 'docs/symbols.html', f'<p>{text.strip()}</p>\n')
        self.assertIn('check: OK', self.run_installer('check'))
        self.run_installer()
        self.assertEqual((self.home / ROOTS[0] / 'demo/symbols.txt').read_bytes(), raw)

    def test_em_and_en_dash_rejected(self):
        cases = (
            ('em-one-line', 'one line \u2014 dash', 'em/en dash in notes.txt:1'),
            ('en-one-line', 'one line \u2013 dash', 'em/en dash in notes.txt:1'),
            ('em-multiline', 'clean line\nsecond \u2014 line\n', 'em/en dash in notes.txt:2'),
            ('en-multiline', 'clean line\nsecond \u2013 line\n', 'em/en dash in notes.txt:2'),
        )
        note = self.repo / 'notes.txt'
        for label, content, expected in cases:
            with self.subTest(case=label):
                write(note, content)
                self.assertIn(expected, self.run_installer('check', success=False))
                self.assert_rejected_read_only(expected)
                note.unlink()


class PowerShellInstallerCases(InstallerCases):
    installer_kind = 'powershell'

    def junction(self, target, path):
        path.parent.mkdir(parents=True, exist_ok=True)
        result = subprocess.run(
            ['cmd', '/c', 'mklink', '/J', str(path), str(target)],
            text=True,
            encoding='utf-8',
            errors='replace',
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            timeout=30,
        )
        self.assertEqual(result.returncode, 0, result.stdout)
        self.addCleanup(lambda p=path: p.rmdir() if is_reparse_link(p) else None)

    def test_junction_root(self):
        outside = self.base / 'outside'
        write(outside / 'data', 'untouched')
        self.junction(outside, self.home / ROOTS[-1])
        self.assert_rejected_read_only('linked path:')

    def test_junction_ancestor(self):
        outside = self.base / 'outside'
        write(outside / 'data', 'untouched')
        self.junction(outside, self.home / '.codex')
        self.assert_rejected_read_only('linked path:')

    def test_junction_destination(self):
        outside = self.base / 'outside'
        write(outside / 'data', 'untouched')
        self.junction(outside, self.home / ROOTS[0] / 'demo')
        self.assert_rejected_read_only('linked path:')

    def test_junction_manifest(self):
        outside = self.base / 'outside'
        write(outside / 'data', 'untouched')
        self.junction(outside, self.home / ROOTS[-1] / MANIFEST)
        self.assert_rejected_read_only('linked path:')

    def test_junction_managed_nested(self):
        root = self.home / ROOTS[0]
        write(root / MANIFEST, 'obsolete\n')
        outside = self.base / 'outside'
        write(outside / 'data', 'untouched')
        self.junction(outside, root / 'obsolete/link')
        self.assert_rejected_read_only('linked path:')

    def test_junction_source_child(self):
        outside = self.base / 'outside'
        write(outside / 'data', 'untouched')
        self.junction(outside, self.repo / 'skills/demo/linked')
        self.assert_rejected_read_only('linked path:')

    def test_junction_source_root(self):
        outside = self.base / 'outside'
        (self.repo / 'skills').rename(outside)
        self.junction(outside, self.repo / 'skills')
        self.assert_rejected_read_only('linked path:')


@unittest.skipUnless(shutil.which('bash') and os.name != 'nt', 'Unix Bash unavailable')
class BashTests(InstallerCases, unittest.TestCase):
    installer_kind = 'bash'
    shell_exe = 'bash'


@unittest.skipUnless(os.name == 'nt' and POWERSHELL, 'Windows PowerShell 5.1 unavailable')
class WindowsPowerShellTests(PowerShellInstallerCases, unittest.TestCase):
    shell_exe = POWERSHELL


@unittest.skipUnless(os.name == 'nt' and PWSH, 'PowerShell 7+ (pwsh) unavailable')
class PowerShellCoreTests(PowerShellInstallerCases, unittest.TestCase):
    shell_exe = PWSH


if __name__ == '__main__':
    unittest.main(verbosity=2)
