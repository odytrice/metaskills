---
description: Run dev-cycle across a batch of issues in dependency-ordered waves
---
Use the `burndown` skill to triage the batch of issues scoped by the arguments (labels, milestone, explicit issue numbers, or a board column; default is the board's Ready column), order them into waves, run `dev-cycle` for each with wave concurrency, then run the closing QA sweep and report.

$ARGUMENTS
