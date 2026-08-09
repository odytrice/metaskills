---
name: deploy
description: Review, commit, push, and deploy the current project through its CI/CD pipeline, resolving environments, branches, repositories, and job timings from the project's AGENTS.md; monitors the pipeline to completion and verifies Kubernetes rollouts.
---

# Deploy

Review uncommitted changes, gate on review outcome, commit, push, and monitor the CI/CD pipeline to completion. All project facts come from `AGENTS.md` at the repository root; this skill contains none.

During this workflow you must not edit or create source files; only analyze, report, commit, push, and monitor. If the review gate surfaces blocking issues, report them and stop so the developer can fix them first.

## Resolve Project Facts First

Read `AGENTS.md` and resolve:

| Fact | AGENTS.md section |
|------|-------------------|
| Environments (URL, cluster/context, namespace, Docker images) | § Environments |
| Branch → environment → CI workflow mapping | § Branch Map |
| App repo slug, deployment repo slug + local sibling path | § Repositories |
| Build/test/lint commands | § Build & Validation |
| CI job names, expected durations, polling cadence | § CI Pipeline (optional) |

If § Environments, § Branch Map, § Repositories, or § Build & Validation is missing, say so and stop; do not guess. If § CI Pipeline is absent, fall back to `gh run watch <run-id> --exit-status` with a generic poll of about 60 seconds.

## Safety Gates

Stop and ask before deploying if any of these are true:

- Target environment is unclear.
- **Production deployment was not explicitly requested.** Prod deploys happen ONLY on an explicit production instruction from the user; never infer one.
- Secrets are present in source-controlled config or Kubernetes manifests.
- Current branch or commit is unclear, or the branch does not map to the intended environment per § Branch Map.
- Required validation failed.
- There are unrelated local changes that would affect the deployment artifact.

Never deploy to production from a dirty tree. Only commit local changes as part of a deploy when the user explicitly asks to ship those specific changes.

## Process

### Step 1: Gather State

```powershell
git status --short
git branch --show-current
git rev-parse HEAD
git diff
git diff --cached
```

Confirm the current branch maps to the intended environment via § Branch Map. Ask before pushing if the target is unclear.

### Step 2: Review Gate

If there are uncommitted changes, run the `code-review` skill in LOCAL mode on them. Read the full content of significantly changed files for context beyond the diff.

- **Any Critical or High finding**: do NOT commit. Report the findings and stop.
- **Only Medium/Low findings or none**: proceed, and include the findings in the deploy summary.

If the tree is already clean and the user asked to deploy what is committed, skip to Step 4.

### Step 3: Validate

Run the validation commands from § Build & Validation appropriate to the changed files (backend, frontend, or full build) before committing when practical. If a validation command is skipped, record why in the deploy summary.

### Step 4: Commit & Push

1. Stage the intended changes (`git add -A`, or scoped paths if unrelated files are present).
2. Commit with a clear, concise message matching the style of recent commits: imperative mood, no prefix, one sentence.
3. **Never commit files that contain secrets**: `.env` files, credentials, user-specific config overrides, API keys. Warn if any are staged and unstage them before committing.
4. Push to the remote branch that § Branch Map assigns to the target environment. For production, do this only when explicitly instructed; it typically means merging the integration branch into the production branch and pushing it.

### Step 5: Monitor Pipeline

1. Find the triggered run:

```powershell
gh run list --limit 3
```

2. If § CI Pipeline documents expected durations, wait roughly the expected total time before the first status check; otherwise use:

```powershell
gh run watch <run-id> --exit-status
```

with a poll of about 60 seconds.

3. Poll until the run completes:

```powershell
gh run view <run-id>
```

4. If the app pipeline updates a separate deployment repo (per § Repositories), also verify the deployment repo's run:

```powershell
gh run list --repo <deployment-repo-slug> --limit 3
```

5. On failure, fetch logs and identify the failing job, the failing step, and the root-cause error:

```powershell
gh run view <run-id> --log-failed
```

6. Report a per-job status table using the job names from § CI Pipeline (or the actual job names from `gh run view`):

```
| Job    | Duration | Status        |
|--------|----------|---------------|
| <job>  | Xm Xs    | Passed/Failed |
```

### Step 6: Verify Rollout (Kubernetes targets)

When AGENTS.md documents a deployment repo and cluster details, verify the rollout using the cluster context and namespace from § Environments:

```powershell
kubectl get pods -n <namespace> --context <context>
kubectl rollout status deploy/<server-deployment> -n <namespace> --context <context>
kubectl rollout status deploy/<web-deployment> -n <namespace> --context <context>
kubectl logs -n <namespace> deploy/<server-deployment> --context <context> --tail=50
```

Run any post-deploy smoke checks AGENTS.md defines (health endpoint, login page, key pages responding).

## Infrastructure-Only Changes

If the change is only to deployment manifests (configmaps, ingress, image tags) and a local sibling deployment repo exists per § Repositories:

1. Edit files in the deployment repo's overlay for the target environment.
2. Commit and push to the deployment repo's default branch; its workflows apply the overlays.
3. The app CI pipeline also pushes image-tag updates to the deployment repo; run `git pull --rebase` there before pushing, and never overwrite user edits.

## Rollback

Before a production deploy, know the previous image tags and Kubernetes revision, and the migration rollback or forward-fix strategy. Roll back only when the user approves or an established incident procedure requires it:

```powershell
kubectl rollout undo deploy/<server-deployment> -n <namespace> --context <context>
kubectl rollout undo deploy/<web-deployment> -n <namespace> --context <context>
```

## Completion Report

Report: target environment; commit SHA and image tags; review-gate outcome; validation run and results; per-job pipeline status table; rollout/smoke results; any skipped checks and why. Never print secret values from logs, manifests, or config.
