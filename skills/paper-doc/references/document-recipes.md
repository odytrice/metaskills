# Document recipes

Adapt the outline to the reader. The scaffold's example copy is a design
specimen, not a substitute for source-based authoring.

## Documentation

1. Overview: purpose, intended reader, scope, current status.
2. Concepts or architecture: vocabulary, boundaries, responsibilities.
3. How it works: one end-to-end path, concrete inputs and outputs.
4. Operations: prerequisites, usage, failure states, recovery, limitations.
5. References: source files, API docs, revision/date, open questions.

An architecture guide benefits from C1/C2 and a focused C3. An API reference
usually benefits more from request/response examples and a contract table.
Use details/summary for secondary explanations, not to hide the whole guide.

## Specification / RFC

1. Decision brief: problem, proposed outcome, status, owner if known.
2. Requirements: use cases, constraints, invariants, non-goals.
3. Design: data model, contracts, boundaries, and important flows.
4. Tradeoffs: alternatives, reason for the choice, unresolved questions.
5. Delivery: acceptance criteria, migration/rollout and rollback if relevant.
6. Evidence: links to requirements and current behavior.

Separate current behavior from proposed behavior in prose and in diagram
status labels. Do not claim a proposed component already exists. Acceptance
criteria should describe observable outcomes rather than implementation trivia.

## Summary / brief

1. Bottom line: a sentence or short paragraph stating the result.
2. Key findings: three to five points with evidence.
3. Implications or next steps: only actions the source actually supports.
4. Sources and caveats: short and specific.

Avoid forcing a C4 explorer into a prose-only summary. Omit the diagram scripts
and the architecture navigation link when there is no architectural question.
Use an airy masthead and a compact content body rather than padding the document.

## Architecture decision record

Use the spec shell, reduced to Context, Decision, Alternatives, Consequences,
and References. Record status/date and supersession if known. A table makes
tradeoffs legible; a C4 view is useful only if boundaries change.

## Evidence discipline

- Derive technical claims from supplied sources or inspected code.
- Distinguish observed, proposed, and illustrative information.
- Cite nearby for consequential claims; collect sources at the end for reuse.
- Mark unknowns rather than inventing numbers, deadlines, owners, or guarantees.
- Preserve source semantics when shortening. Avoid vague slogans.
- Do not carry fictional sample elements, demo dates, or sample metrics into
  the final document. Replace or remove all starter content.
