# Review Output Format

PR: post under `**Review complete**`; local: print. Omit empty sections/severity groups except required Overall Assessment and Summary.

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

- Recurring finding/missing durable guardrail only: propose an `AGENTS.md` rule (usually § Review Notes) or `checklist.md` line to catch it.

### Summary

One paragraph: scope, behavioral impact, priority-ordered next steps. Local: state whether commit is blocked.
```

## Assessment

- `Approve`: no Critical/High, no blocking validation failure, remaining observations minor.
- `Changes requested`: High or important Medium findings, or Needs diagnosis, to resolve before merge/commit.
- `Critical issues found`: any Critical, or a validation failure indicating production breakage.

## Severity (only these four)

- **Critical**: data exposure, auth bypass, cross-tenant access, destructive data loss, secret leak, production outage.
- **High**: broken core workflow, wrong business logic in a primary feature, authorization regression, migration risk.
- **Medium**: important edge case, missing test for risky behavior, degraded UX on a primary path.
- **Low**: maintainability or minor correctness with limited blast radius.

**Needs diagnosis** (`checklist.md` § Bug fixes) is plan-level, outside the severity ladder: state it first under Open Questions with the criteria and evidence; never a developer revision item.

Every finding needs `path:line`; group by severity, not file. No actionable findings: `No critical issues found.` under Findings. Never fabricate elapsed time, actor handles, or job URLs.
