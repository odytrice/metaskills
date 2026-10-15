"""Portable scaffold regressions. No third-party packages or browser required."""

from html.parser import HTMLParser
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


SCRIPT = Path(__file__).resolve().parents[1] / 'skills' / 'paper-doc' / 'scripts' / 'scaffold.py'


class Document(HTMLParser):
    def __init__(self, text):
        super().__init__()
        self.ids = []
        self.anchors = []
        self.assets = []
        self.headings = 0
        self.feed(text)

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if 'id' in attrs:
            self.ids.append(attrs['id'])
        if tag == 'a' and attrs.get('href', '').startswith('#'):
            self.anchors.append(attrs['href'][1:])
        if tag in ('link', 'script'):
            url = attrs.get('href') or attrs.get('src')
            if url and not url.startswith('http'):
                self.assets.append(url)
        if tag == 'h1':
            self.headings += 1


class ScaffoldTests(unittest.TestCase):
    def run_scaffold(self, output, *args):
        return subprocess.run([sys.executable, str(SCRIPT), str(output), '--title', 'Queue <API> & "status"', *args], capture_output=True, text=True, encoding='utf-8')

    def test_every_recipe_with_and_without_diagrams(self):
        with tempfile.TemporaryDirectory() as temporary:
            for kind in ('documentation', 'spec', 'summary'):
                for c4 in (False, True):
                    with self.subTest(kind=kind, c4=c4):
                        output = Path(temporary) / f'{kind}-{c4}'
                        result = self.run_scaffold(output, '--kind', kind, *(['--c4'] if c4 else []))
                        self.assertEqual(result.returncode, 0, result.stderr)
                        text = (output / 'index.html').read_text(encoding='utf-8')
                        document = Document(text)
                        self.assertEqual(document.headings, 1)
                        self.assertEqual(len(document.ids), len(set(document.ids)), 'IDs must be unique')
                        self.assertTrue(set(document.anchors) <= set(document.ids), 'all section links must resolve')
                        self.assertTrue(all((output / asset).is_file() for asset in document.assets))
                        self.assertEqual('data-c4="example"' in text, c4)
                        self.assertEqual((output / 'c4.js').exists(), c4)
                        self.assertIn('Queue &lt;API&gt; &amp; &quot;status&quot;', text)
                        self.assertIn((output / 'index.html').as_uri(), result.stdout)
                        self.assertNotIn('Systems, <i>explained.', text)
                        self.assertNotIn('Clarity before completeness', text)

    def test_existing_work_is_not_overwritten(self):
        with tempfile.TemporaryDirectory() as temporary:
            output = Path(temporary) / 'existing'
            output.mkdir()
            note = output / 'notes.txt'
            note.write_text('User work', encoding='utf-8')
            result = self.run_scaffold(output)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn('empty directory', result.stderr)
            self.assertEqual(note.read_text(encoding='utf-8'), 'User work')
            self.assertFalse((output / 'index.html').exists())

    def test_nonexistent_parent_fails_without_creating_it(self):
        with tempfile.TemporaryDirectory() as temporary:
            parent = Path(temporary) / 'missing'
            result = self.run_scaffold(parent / 'document')
            self.assertNotEqual(result.returncode, 0)
            self.assertFalse(parent.exists())


if __name__ == '__main__':
    unittest.main()
