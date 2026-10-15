# Paper and ink

## Origin and dependencies

Extracted from the user's IcePanel interview-prep webpage: the warm-paper CSS,
editorial composition, and custom SVG `C4Diagram` implementation. This is the
prep page's design, not IcePanel's own product UI. No interview content, company
architecture, personal details, screenshots, or external logos are needed.

The source page used vanilla JavaScript, native SVG, CSS, and Google Fonts.
References in its prose to frameworks were descriptions of other products,
not dependencies of the webpage. The bundled engine preserves its model/view
approach and features while generalizing the controls and improving keyboard,
file-origin, reduced-motion, and narrow-screen behavior.

## Tokens

| Token | Value | Role |
|---|---|---|
| `--paper` | `#f3efe6` | Warm stock, body background |
| `--sheet` | `#fbf9f4` | Cards and controls |
| `--paper2` | `#ebe5d8` | Selected or secondary surface |
| `--ink` | `#1d1b18` | Headings and primary text |
| `--ink2` | `#4b463e` | Secondary prose |
| `--ink3` | `#8a8377` | Decorative/tertiary labels, not essential body text |
| `--rule` | `#ddd5c5` | Hairline divisions |
| `--rule2` | `#c3b9a5` | Stronger divisions |
| `--red` | `#b3261e` | Editorial annotation and active state |
| `--blue` | `#23477a` | Links and C4 people/systems |
| `--green` | `#2f6b4f` | Positive status |
| `--gold` | `#8a6200` | Caution |
| `--hl` | `rgba(247, 222, 110, .55)` | Highlighter underline |

Use the bundled inline SVG noise texture. The subtle paper grain, 3px radii,
and restrained shadow are part of the aesthetic. Do not substitute pure white,
large rounded corners, glossy gradients, or saturated card backgrounds.

## Type and measure

- `--serif`: Newsreader, Iowan Old Style, Georgia, serif.
- `--sans`: Inter, system-ui, Segoe UI, sans-serif.
- `--mono`: JetBrains Mono, ui-monospace, Menlo, monospace.
- Body: 16px / 1.62. Prose width: approximately 72 characters.
- Masthead: `clamp(54px, 8.4vw, 116px)`, weight 400, line-height .95,
  letter-spacing -.04em. Use `.compact-title` for unusually long titles.
- Section title: `clamp(34px, 4vw, 52px)`. Card title: 22px.
- Metadata: 10.5 to 12px mono, uppercase, letter-spacing .10 to .18em.
- Lede and section introduction: 20 to 21px serif with 1.5 line-height.
- Wrapper: 1180px maximum, 32px side padding; 20px on small screens.

## Composition

Start with the sticky, horizontally scrollable section navigation, then a
newspaper-style masthead: metadata row, thin rule, centred title and italic
phrase, serif lede, and a fact/outline split. Close it with a double rule.
Use 72px section spacing, red numbered eyebrows, and an ink rule above each h2.
Scale down section spacing and stack columns on mobile.

Alternate useful patterns: plain prose, two-column explanation, three short
findings, ruled comparison table, callout, diagram, FAQ, evidence appendix.
Do not use every pattern in every document. Summaries may need only three
sections and no interactive controls beyond navigation.

## Component vocabulary

The runnable specimen demonstrates these classes. Keep HTML semantic.

```html
<section class="s" id="decision">
  <div class="wrap">
    <div class="eyebrow"><span class="n">2</span>Decision</div>
    <h2>One durable record</h2>
    <p class="sub">A short explanation of what matters here.</p>
    <div class="grid g2">
      <article class="card glow"><span class="badge ice">Chosen</span><h3>Option A</h3><p>Reason.</p></article>
      <article class="card"><h3>Tradeoff</h3><p>Cost and consequence.</p></article>
    </div>
  </div>
</section>
```

| Pattern | Classes/markup |
|---|---|
| Columns | `.grid.g2`, `.grid.g3`, `.grid.g4`; children use `min-width: 0` |
| Cards | `.card`, `.glow` (ink rule), `.o`/`.warn` (red), `.ok` (green) |
| Labels | `.badge`, `.badge.ice`, `.badge.o`, `.badge.mint`, `.badge.amber` |
| Highlight | `<mark>`; yellow lower-half underline |
| Quote | `<blockquote class="quote">` with optional `<cite>` |
| Ruled note | `.script` with `.who` label |
| Table | `.table-scroll` wrapping `<table class="t">`; proper th scope |
| Code | `<pre><code>`; preserve whitespace; horizontal scrolling inside |
| FAQ | `<details class="qa"><summary>Question</summary><div class="a">Answer</div></details>` |
| Checklist | `.check` label, checkbox `data-check="unique-key"`, then span |
| Timeline | `.timeline`, `.ev`, `.d`; `.hot` marks an important event |
| Figures | `.shot` button with image, caption, `data-lightbox`; native dialog |
| Side notes | `.doc-note`; optional `[data-notes-toggle]` button |
| Reveal | `.reveal`; progressive enhancement, visible if JS fails |
| Source list | Numbered list with real links, dates/revisions when relevant |

Essential content should not live only in an inspector, tooltip, or image.
Use descriptive link text, meaningful image alt text, visible focus rings,
labelled buttons, and native details/dialog elements. Headings form a logical
hierarchy. Do not make ordinary cards clickable when details/summary will do.

## Portability and print

Use relative files and classic scripts; keep data in `model.js`. Google Fonts
are optional network enhancements. Document-specific identity is set through
`body[data-doc-id]`; path isolation prevents checklist collisions.

Print styling removes sticky toolbars, opens details for printing through the
document runtime, reveals all prose, and avoids splitting small cards. The
diagram prints the current view, not all model views. For a full architecture
printout, author separate static views or a textual appendix explicitly.
