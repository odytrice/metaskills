# Review Output Format

PR mode posts this as the PR comment (under the `**Review complete**` header line); local mode prints it. Omit empty sections and severity groups; Overall Assessment and Summary are always present.

```md
### Code Review

**Overall Assessment: <Approve | Changes requested | Critical issues found>**

### Findings

#### Critical
- `path/to/file:line` - what is wrong, why it matters, what should change.

#### High
#### Medium
#### Low

### Risk Analysis

- **Production stability / Security / Data integrity / Operations:** Low/Medium/High, one sentence each.

### Validation

- `command` - result. Note anything not run and why.

### Open Questions

### Positive Observations

- 1-3 concrete strengths, only when real and specific.

### Harness Feedback

- Only when a finding recurs or reveals a missing durable guardrail: the `AGENTS.md` rule (usually § Review Notes) or `checklist.md` line that would have caught it.

### Summary

One paragraph: scope, behavioral impact, next steps with the most important first. Local mode: state whether the commit is blocked.
```

## Assessment

- `Approve`: no Critical/High, no blocking validation failure, remaining observations minor.
- `Changes requested`: High or important Medium findings to fix before merge/commit.
- `Critical issues found`: any Critical, or a validation failure indicating production breakage.

## Severity (only these four)

- **Critical**: data exposure, auth bypass, cross-tenant access, destructive data loss, secret leak, production outage.
- **High**: broken core workflow, wrong business logic in a primary feature, authorization regression, migration risk.
- **Medium**: important edge case, missing test for risky behavior, degraded UX on a primary path.
- **Low**: maintainability or minor correctness with limited blast radius.

Every finding carries `path:line`; group by severity, not file. No actionable findings: write `No critical issues found.` under Findings. Never fabricate elapsed time, actor handles, or job URLs.
