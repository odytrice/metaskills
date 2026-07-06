# Review Output Format

Both modes use this structure. PR mode posts it as the PR comment (with the
`**Review complete** -- [View PR](<url>)` header line from the skill); local mode
prints it to the user.

```md
### Code Review

**Overall Assessment: <assessment>**

### Findings

#### Critical
- `path/to/file:line` - What is wrong, why it matters, and what should change.

#### High
- `path/to/file:line` - ...

#### Medium
- `path/to/file:line` - ...

#### Low
- `path/to/file:line` - ...

### Risk Analysis

- **Production stability:** Low/Medium/High with one sentence.
- **Security:** Low/Medium/High with one sentence.
- **Data integrity:** Low/Medium/High with one sentence.
- **Operations/deployment:** Low/Medium/High with one sentence.

### Validation

- `command` - result.
- Note any validation that was not run and why.

### Open Questions

- Question or assumption, if any.

### Positive Observations

- 1-3 concrete strengths, only when they are real and specific.

### Harness Feedback

- Only when a finding recurs or reveals a missing durable guardrail: propose a
  concrete `AGENTS.md` rule or checklist line that would have caught it.

### Summary

One paragraph: change scope, behavioral impact, and recommended next steps, with the
most important action item first. In local mode, state explicitly whether the commit
is blocked.
```

## Assessment Labels

- `Approve` -- no Critical or High findings, no blocking validation failures, and
  remaining observations are minor.
- `Changes requested` -- High or important Medium findings that should be fixed before
  merge/commit.
- `Critical issues found` -- any Critical finding, or a validation failure that
  indicates a production-breaking issue.

## Severity Ladder

Use only these four severities (never "Warning" or "Suggestion"):

- **Critical**: data exposure, auth bypass, cross-tenant/cross-user data access,
  destructive data loss, secret leak, production outage.
- **High**: broken core workflow, incorrect business logic in a primary feature,
  credential/authorization regression, migration risk.
- **Medium**: important edge case, missing test for risky behavior, degraded UX in a
  primary path.
- **Low**: maintainability or minor correctness issue with limited blast radius.

## Rules

- Always include the file path and line number for each finding.
- Group findings by severity, not by file.
- If a severity group or section has no content, omit it (except Overall Assessment
  and Summary, which are always required).
- If there are no actionable findings, say `No critical issues found.` under Findings
  and list only concise observations that matter for merge/commit confidence.
- Keep descriptions concise but actionable.
- Do not fabricate elapsed time, actor handles, or job URLs; use neutral wording when
  metadata is unavailable.
