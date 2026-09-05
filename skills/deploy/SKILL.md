---
name: deploy
description: Review-gate, commit, push, and deploy through the project's CI/CD pipeline; monitor to completion and verify rollouts, per AGENTS.md. Use when asked to deploy, ship, release, push to an environment, or promote to production.
---

# Deploy

Review uncommitted changes, gate on the outcome, commit, push, monitor the pipeline to completion, verify the rollout. Never edit or create source files here; if the gate blocks, report and stop.

Project facts from `AGENTS.md`: **§ Environments** (URL, context, namespace, images, deployment names, smoke checks), **§ Branch Map**, **§ Repositories** (app repo; deployment repo and sibling path), **§ Build & Validation** (commands, commit convention), **§ CI Pipeline** (optional: job names, durations, polling; absent: `gh run watch <run-id> --exit-status`, polling about every 60 s). Any other section missing: name it and stop.

## Gates (stop and ask)

Target environment unclear; **production not explicitly requested** (never infer it); secrets in source-controlled config or manifests; branch or commit unclear, or the branch does not map to the target per § Branch Map; required validation failed; unrelated local changes would enter the artifact. Never deploy production from a dirty tree; commit as part of a deploy only when the user asked to ship those specific changes.

## Process

1. **State**: `git status --short`, `git branch --show-current`, `git rev-parse HEAD`, `git diff`, `git diff --cached`. Confirm the branch maps to the target.
2. **Review gate**: uncommitted changes go through `code-review` local mode. Critical/High: stop. Medium/Low or none: proceed and include them in the report. Clean tree and the user wants what is committed: skip to 4.
3. **Validate** with the § Build & Validation commands for the changed files when practical; record anything skipped and why.
4. **Commit and push**: `git add <paths>` explicitly, never `git add -A` (it sweeps in `.tmp-*`, `.worktrees/`, unrelated edits); never commit secrets (warn and unstage); subject per the commit convention; push to the branch § Branch Map assigns to the target. Production: only on explicit instruction, typically merging the integration branch into the production branch and pushing.
5. **Monitor**: `gh run list --limit 3` (add `--repo <slug>` for another repo); wait roughly the expected total from § CI Pipeline before the first check, else `gh run watch`; poll `gh run view <run-id>` until status is `completed`; never report a pass without observing the conclusion. If the app pipeline updates a separate deployment repo, wait about 30 s for its run and monitor it the same way. On failure `gh run view <run-id> --log-failed` and identify the failing job, step, and root cause. Report a per-job table (job, duration, status) using § CI Pipeline names or the actual ones.
6. **Rollout** (Kubernetes targets, when § Environments documents them), per listed deployment:

   ```sh
   kubectl get pods -n <namespace> --context <context>
   kubectl rollout status deploy/<deployment> -n <namespace> --context <context>
   kubectl logs -n <namespace> deploy/<deployment> --context <context> --tail=50
   ```

   Then the smoke checks § Environments defines; none documented: say so rather than inventing them.

## Infrastructure-Only Changes

Manifest-only change with a local sibling deployment repo (§ Repositories): edit the target environment's overlay there, `git pull --rebase` first (the app pipeline also pushes image tags there), commit and push to its default branch; never overwrite user edits.

## Rollback

Before a production deploy know the previous image tags, Kubernetes revision, and migration rollback or forward-fix strategy. Roll back only on user approval or an established incident procedure: `kubectl rollout undo deploy/<deployment> -n <namespace> --context <context>`.

## Report

Target; commit SHA and image tags; review-gate outcome; validation; per-job table; rollout and smoke results; skipped checks and why. Never print secret values.
