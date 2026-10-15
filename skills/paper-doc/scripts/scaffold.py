"""Create a portable paper-doc starter using only the Python standard library."""

import argparse
from datetime import date
from html import escape
from pathlib import Path
import re
import shutil
import sys


RECIPES = {
    'documentation': [
        ('overview', 'Overview', 'Explain the purpose, audience, and scope.'),
        ('concepts', 'Core concepts', 'Define the vocabulary and responsibilities the reader needs.'),
        ('usage', 'How it works', 'Walk through a concrete input, output, and failure path.'),
        ('operations', 'Operations and limits', 'Describe prerequisites, recovery, and known limitations.'),
        ('references', 'Sources and open questions', 'Cite the source material and make unknowns explicit.'),
    ],
    'spec': [
        ('brief', 'Decision brief', 'State the problem, proposed outcome, and decision status.'),
        ('requirements', 'Requirements', 'Define use cases, constraints, invariants, and non-goals.'),
        ('design', 'Proposed design', 'Describe contracts, data, boundaries, and important failure modes.'),
        ('tradeoffs', 'Alternatives and tradeoffs', 'Record the options, chosen approach, and consequences.'),
        ('delivery', 'Acceptance and delivery', 'Define observable acceptance criteria and rollout if relevant.'),
        ('references', 'Sources and open questions', 'Cite requirements and current behavior; label unresolved choices.'),
    ],
    'summary': [
        ('bottom-line', 'Bottom line', 'State the conclusion without overstating the evidence.'),
        ('findings', 'Key findings', 'Select the most important findings and connect them to evidence.'),
        ('implications', 'Implications', 'Explain supported consequences or next steps.'),
        ('references', 'Sources and caveats', 'List sources, scope, and meaningful uncertainty.'),
    ],
}


def replace_slot(html, slot, text):
    pattern = rf'(<[^>]+\bid="{re.escape(slot)}"[^>]*>).*?(</[^>]+>)'
    return re.sub(pattern, lambda match: match[1] + escape(text) + match[2], html, count=1, flags=re.S)


def section_html(number, key, title, prompt):
    return f'''    <section class="s" id="{key}">
      <div class="wrap">
        <div class="eyebrow"><span class="n">{number}</span>Draft section</div>
        <h2>{escape(title)}</h2>
        <p class="sub">{escape(prompt)}</p>
        <div class="prose"><p>Replace this starter with source-based content for the intended reader.</p></div>
      </div>
    </section>'''


def scaffold(destination, title, kind, with_c4, subtitle, document_date):
    destination = destination.expanduser().absolute()
    if destination.exists() and (not destination.is_dir() or any(destination.iterdir())):
        raise ValueError(f'Destination must be an empty directory: {destination}')
    if not destination.parent.is_dir():
        raise ValueError(f'Parent directory does not exist: {destination.parent}')
    if destination.is_symlink():
        raise ValueError('Destination must not be a symlink')
    template = Path(__file__).resolve().parents[1] / 'assets' / 'template'
    html = (template / 'index.html').read_text(encoding='utf-8')
    html = re.sub(r'<title>.*?</title>', lambda _: f'<title>{escape(title)} · Paper Doc</title>', html)
    html = re.sub(r'<h1 id="doc-title">.*?</h1>', lambda _: f'<h1 id="doc-title" class="compact-title">{escape(title)}</h1>', html, flags=re.S)
    lede = subtitle or f'A working {kind} draft. Replace the starter text with verified content.'
    html = re.sub(r'<meta name="description" content="[^"]*">', lambda _: f'<meta name="description" content="{escape(lede, quote=True)}">', html)
    for slot, text in {
        'doc-kind': kind.title(), 'doc-date': document_date, 'doc-status': 'Draft',
        'doc-purpose': kind.title(), 'doc-audience': 'Specify the intended reader',
        'doc-fact-status': 'Draft, starter content to replace', 'doc-lede': lede,
    }.items():
        html = replace_slot(html, slot, text)
    slug = re.sub(r'[^a-z0-9]+', '-', title.lower()).strip('-') or 'document'
    html = html.replace('data-doc-id="paper-doc-specimen"', f'data-doc-id="{slug}"')
    html = html.replace('A field guide to clear technical writing', escape(kind.title() + ' · Working draft'))
    html = html.replace('A reusable design specimen. Keep the whole folder together when sharing.', 'Draft document. Keep the whole folder together when sharing.')
    recipes = list(RECIPES[kind])
    if with_c4:
        recipes.insert(2, ('architecture', 'Architecture', 'Replace the illustrative model with the intended architecture.'))
    sections = []
    for number, (key, heading, prompt) in enumerate(recipes, start=1):
        if key == 'architecture':
            section = re.search(r'<!-- C4-SECTION-START -->(.*?)<!-- C4-SECTION-END -->', html, re.S).group(1).strip()
            section = re.sub(r'<span class="n">3</span>', f'<span class="n">{number}</span>', section, count=1)
            sections.append(section)
        else:
            sections.append(section_html(number, key, heading, prompt))
    html = re.sub(r'(<main id="main">).*?(</main>)', lambda m: m[1] + '\n' + '\n'.join(sections) + '\n  ' + m[2], html, flags=re.S)
    nav = ''.join(f'<a href="#{key}">{escape(heading)}</a>' for key, heading, _ in recipes)
    html = re.sub(r'(<div class="nav-links">).*?(</div>)', lambda m: m[1] + nav + m[2], html, flags=re.S)
    outline = ''.join(f'<div class="stage"><div class="roman">{roman}.</div><h3>{escape(heading)}</h3><p>{escape(prompt)}</p></div>' for roman, (_, heading, prompt) in zip(['I', 'II', 'III'], recipes[:3]))
    html = re.sub(r'(<div class="agenda" id="doc-outline">).*?(\n        </div>)', lambda m: m[1] + '\n          ' + outline + m[2], html, flags=re.S)
    files = ['theme.css', 'document.js']
    if with_c4:
        files += ['c4.css', 'model.js', 'c4.js', 'c4-ui.js']
    else:
        html = re.sub(r'^.*(?:href="c4.css"|src="(?:model|c4|c4-ui).js").*\n', '', html, flags=re.M)
    # All checks and rendering happen before creating the output directory.
    destination.mkdir(exist_ok=True)
    for name in files:
        shutil.copyfile(template / name, destination / name)
    (destination / 'index.html').write_text(html, encoding='utf-8', newline='\n')
    return destination / 'index.html'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('output', type=Path)
    parser.add_argument('--title', required=True)
    parser.add_argument('--kind', choices=RECIPES, default='documentation')
    parser.add_argument('--c4', action='store_true', help='Include the fictional C4 starter and explorer assets')
    parser.add_argument('--subtitle')
    parser.add_argument('--date', default=date.today().isoformat(), help='Document date, defaults to today')
    args = parser.parse_args()
    try:
        path = scaffold(args.output, args.title, args.kind, args.c4, args.subtitle, args.date)
    except (OSError, ValueError) as error:
        print(f'Cannot scaffold paper-doc: {error}', file=sys.stderr)
        return 1
    print(f'Created: {path}')
    print(path.as_uri())
    print('Starter only: replace example prose, metadata, sources, and any illustrative model before sharing.')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
