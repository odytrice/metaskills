---
name: paper-doc
description: Generate documentation, specs, reports, architecture explainers, RFCs, briefs, and summaries as polished paper-and-ink HTML documents. Use for paper-doc requests or when the user wants the IcePanel prep aesthetic, an editorial document webpage, or interactive C4 documentation. Includes the theme, components, and dependency-free C4 explorer.
---

# Paper Doc

Turn source material into a readable, evidence-backed technical document using
the bundled paper-and-ink design. The default deliverable is a portable folder
with `index.html` that opens directly through a `file://` URL. The appearance
comes from the assets, not from reinterpreting a style description each time.

## Workflow

1. **Establish the document.** Infer audience, purpose, document type, and output
   location from the request. Read the consuming project's `AGENTS.md` and its
   relevant source material. Resolve project facts there; ask for missing facts
   that affect the document rather than inventing them. A pasted brief can be
   sufficient source material. Preserve explicit format requests; when editing
   an existing Markdown/Word/Google document, do not silently replace it with HTML.
2. **Choose a shape.** Read [document recipes](references/document-recipes.md).
   Lead with the conclusion or decision, then provide the detail that supports
   it. Use only sections and interactions that help this particular reader.
3. **Start from the real assets.** Read [design system](references/design-system.md).
   Resolve this skill's directory from the loaded skill location, then run:

   ```text
   python <skill-dir>/scripts/scaffold.py <output-dir> --title "Document title" --kind spec
   python <skill-dir>/scripts/scaffold.py <output-dir> --title "Architecture guide" --kind documentation --c4
   ```

   `--kind` accepts `documentation`, `spec`, or `summary`. The scaffold refuses
   a nonempty destination. Use the project interpreter (`python3` on systems
   without `python`) or copy the template assets with your file tools if Python
   is unavailable. The script prints the exact file URL. `assets/template/index.html`
   is also a complete, directly openable design specimen.
4. **Author the document.** Replace the specimen prose, metadata, sources,
   checklist items, and example architecture with the user's actual content.
   The generated heading outline is a starting point, not completed writing.
   Keep the theme and useful components. Remove filler and unused controls.
   Use HTML escaping for interpolated text; render untrusted source snippets as
   text, not executable markup. Keep main content in semantic HTML so it remains
   readable without JavaScript. Use a short masthead title with an italic phrase
   where natural; long technical titles can use a smaller heading.
5. **Add diagrams only when useful.** Read [C4 contract](references/c4.md) before
   changing `model.js`. Reuse `c4.js` and `c4-ui.js`, which implement the actual
   explorer from the reference design. They use native SVG and browser APIs,
   not Mermaid, D3, Pixi, or an IcePanel SDK. Use one shared model with several
   views, directional relationships, and optional runtime flows. Mark proposed
   or illustrative designs explicitly. Verify current architectures against
   source files. C4 is optional for a summary, release note, or decision memo.
6. **Verify in the browser.** Open the output's `file://` URL directly, without
   launching a server. Check desktop and a narrow mobile viewport, keyboard
   navigation, source links, print styling, and console errors. For a diagram,
   test inspect, drill down/up, tags, supporting systems, vocabulary, fit/zoom,
   flow steps, arrow text, and DSL export. Check reduced motion and confirm
   essential prose remains visible with JavaScript disabled. If browser tools
   cannot open file URLs, report that limitation rather than claiming visual QA.
7. **Deliver.** Return the path and file URL, briefly identify the included
   sections and diagrams, and describe any unresolved source gaps. Keep the
   entire output folder together because scripts/styles use relative paths.

## Design contract

- Warm textured paper, off-white sheets, dark ink, fine rules, restrained red.
- Newsreader for editorial headings and ledes; Inter for reading and controls;
  JetBrains Mono for metadata, labels, code, and identifiers. All have fallbacks.
- Preserve the masthead, double-rule separators, numbered section eyebrows,
  generous spacing, small-radius cards, and subtle shadow from the specimen.
- Prefer prose, ruled tables, and columns to a wall of cards. Do not turn the
  document into a generic dashboard, neon landing page, or pill-heavy UI.
- Use motion to orient: subtle reveals and diagram transitions. Respect reduced
  motion in both CSS and JavaScript. No automatic decorative animations.
- Give every diagram a title, scope, key, date/status, and readable relationships.
  Colours reinforce shapes and labels rather than replacing their meaning.
- No em or en dashes in authored copy. Use commas, colons, parentheses, or hyphens.

## Runtime and portability

The package has no npm dependencies or build step. Classic scripts load in this
order: `document.js`, `model.js`, `c4.js`, `c4-ui.js` (all deferred). The last
three and `c4.css` are optional. Avoid ES module imports and `fetch()` for local
document data because file-origin restrictions vary between browsers.

Google Fonts are the only default external requests. Offline rendering uses
local fallback fonts; exact offline typography needs locally bundled licensed
font files and `@font-face`. The runtime never fetches the original prep page.
Checklist storage is document-scoped and best-effort. Text and controls keep
working when storage, clipboard, or fullscreen APIs are unavailable.

## Bundled resources

| Resource | Purpose |
|---|---|
| `assets/template/index.html` | Working visual specimen and semantic component examples |
| `assets/template/theme.css` | Exact core palette, typography, paper texture, layout, components, responsive and print styles |
| `assets/template/document.js` | Reading progress, section tracking, reveals, notes toggle, checklist persistence, lightbox |
| `assets/template/c4.css` | Graph-paper canvas, SVG notation, inspector and flow styling |
| `assets/template/c4.js` | Model-driven SVG engine: hierarchy, roll-ups, pan/zoom, flows, DSL |
| `assets/template/c4-ui.js` | Reusable explorer toolbar, inspector, tags, breadcrumbs, export dialog |
| `assets/template/model.js` | Fictional, explicitly labelled C1/C2/C3 example to replace |
| `scripts/scaffold.py` | Portable, dependency-free starter generation |
| `references/design-system.md` | Tokens, composition rules, component markup, extraction provenance |
| `references/document-recipes.md` | Documentation, spec, summary, and ADR structures |
| `references/c4.md` | Model schema, layout, JS API, limitations, and QA checklist |
| `evals/evals.json` | Representative authoring prompts for later skill evaluation |
