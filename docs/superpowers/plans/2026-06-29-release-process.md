# Automated Release Process Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a Conventional-Commits-driven release process: release-please (manifest mode, single repo-wide semver) opens a release PR, and merging it tags `vX.Y.Z` and auto-publishes the CloudFormation template via the existing S3/CloudFront flow.

**Architecture:** release-please runs on push to `main` and maintains a release PR (bumps `version.txt` + manifest, regenerates `CHANGELOG.md`). Merging that PR creates the tag + GitHub Release; a second job in the same workflow, gated on `release_created`, calls the refactored `publish.yml` as a reusable workflow — sidestepping the well-known "a tag pushed by `GITHUB_TOKEN` doesn't trigger other workflows" trap. A separate PR-title lint enforces Conventional Commits on the squash-merge title that release-please consumes.

**Tech Stack:** GitHub Actions; `googleapis/release-please-action@v4`; `amannn/action-semantic-pull-request@v6`; `marocchino/sticky-pull-request-comment@v2`; AWS CLI via OIDC (`aws-actions/configure-aws-credentials@v6`); local validation with `jq` + `actionlint`.

## Global Constraints

Every task's requirements implicitly include this section. Values are copied verbatim from the spec (`docs/superpowers/specs/2026-06-29-release-process-design.md`).

- **Single repo-wide semver.** Tags are plain `vX.Y.Z` — no component prefix (`include-component-in-tag: false`).
- **Baseline:** `.release-please-manifest.json` and `version.txt` both seed `1.0.0`. `last-release-sha` = `0efe596163dd876432aab92a3028ba46d31ca664` (current `main` HEAD).
- **Pinned action versions:** `googleapis/release-please-action@v4`, `amannn/action-semantic-pull-request@v6`, `marocchino/sticky-pull-request-comment@v2`, `actions/checkout@v6`, `aws-actions/configure-aws-credentials@v6`.
- **AWS:** region `us-west-1`; repo vars `CFN_TEMPLATES_PUBLISHER_ROLE_ARN`, `CFN_TEMPLATES_BUCKET`, `CFN_TEMPLATES_DISTRIBUTION_ID`.
- **Conventional Commit types (12):** `feat`, `fix`, `perf`, `deps`, `revert`, `docs`, `chore`, `refactor`, `test`, `build`, `ci`, `style`. Visible in changelog: `feat`, `fix`, `perf`, `deps`, `revert`. The rest are `hidden: true`.
- **Every workflow file must pass `actionlint` with zero errors.**
- This is a config/CI plan, so the per-task rhythm is **make the change → verify with the exact command shown → commit** (there is no unit-test harness for YAML). Use the exact verify commands; they are real and run offline.

---

### Task 1: release-please version source of truth

Creates the three files that define the single repo-wide version and tell release-please how to behave. They change together (the version baseline), so they are one task.

**Files:**
- Create: `version.txt`
- Create: `.release-please-manifest.json`
- Create: `release-please-config.json`

**Interfaces:**
- Consumes: nothing.
- Produces: `release-please-config.json` (referenced by Task 3 as `config-file`), `.release-please-manifest.json` (referenced by Task 3 as `manifest-file`), root `version.txt` (rewritten by release-please on each release).

- [ ] **Step 1: Create `version.txt`**

The `simple` release type tracks the version here. Single line, no trailing newline issues (a trailing newline is fine).

```
1.0.0
```

- [ ] **Step 2: Create `.release-please-manifest.json`**

```json
{
  ".": "1.0.0"
}
```

- [ ] **Step 3: Create `release-please-config.json`**

```json
{
  "$schema": "https://raw.githubusercontent.com/googleapis/release-please/main/schemas/config.json",
  "release-type": "simple",
  "include-component-in-tag": false,
  "last-release-sha": "0efe596163dd876432aab92a3028ba46d31ca664",
  "changelog-sections": [
    { "type": "feat", "section": "Features" },
    { "type": "fix", "section": "Bug Fixes" },
    { "type": "perf", "section": "Performance Improvements" },
    { "type": "deps", "section": "Dependencies" },
    { "type": "revert", "section": "Reverts" },
    { "type": "docs", "section": "Documentation", "hidden": true },
    { "type": "chore", "section": "Miscellaneous Chores", "hidden": true },
    { "type": "refactor", "section": "Code Refactoring", "hidden": true },
    { "type": "test", "section": "Tests", "hidden": true },
    { "type": "build", "section": "Build System", "hidden": true },
    { "type": "ci", "section": "Continuous Integration", "hidden": true },
    { "type": "style", "section": "Styles", "hidden": true }
  ],
  "packages": {
    ".": { "package-name": "aws-ent-deploy-role" }
  }
}
```

- [ ] **Step 4: Verify JSON validity and key values**

Run:
```bash
jq empty release-please-config.json && \
jq empty .release-please-manifest.json && \
jq -e '.["release-type"]=="simple" and .["include-component-in-tag"]==false and .["last-release-sha"]=="0efe596163dd876432aab92a3028ba46d31ca664"' release-please-config.json >/dev/null && \
jq -e '(.["changelog-sections"] | map(.type)) == ["feat","fix","perf","deps","revert","docs","chore","refactor","test","build","ci","style"]' release-please-config.json >/dev/null && \
jq -e '.["."]=="1.0.0"' .release-please-manifest.json >/dev/null && \
[ "$(tr -d '[:space:]' < version.txt)" = "1.0.0" ] && \
echo "ALL OK"
```
Expected: prints `ALL OK` (and nothing else on stderr). Any `jq: error` or a missing `ALL OK` means a typo — fix it.

- [ ] **Step 5: Commit**

```bash
git add version.txt .release-please-manifest.json release-please-config.json
git commit -m "ci: add release-please config and version baseline"
```

---

### Task 2: Make `publish.yml` reusable via `workflow_call`

Refactor the existing publish workflow so it can be (a) called by the release workflow with an explicit version, and (b) still run manually for dev/prod. Remove the `push: tags` trigger (it cannot fire from release-please's bot token, and removing it prevents an accidental double-publish from a hand-pushed tag).

**Files:**
- Modify: `.github/workflows/publish.yml` (replace the whole file with the content below)

**Interfaces:**
- Consumes: nothing.
- Produces: `publish.yml` callable as `uses: ./.github/workflows/publish.yml` with inputs `environment` (string, default `prod`) and `version` (string, **required**); also retains `workflow_dispatch` (input `environment`: choice dev/prod). Consumed by Task 3.

- [ ] **Step 1: Replace `.github/workflows/publish.yml` with this exact content**

```yaml
name: Publish CFN templates

on:
  workflow_call:
    inputs:
      environment:
        description: Target environment
        type: string
        default: prod
      version:
        description: Version string to publish under (e.g. v1.2.3)
        type: string
        required: true
  workflow_dispatch:
    inputs:
      environment:
        description: Target environment (manual publish; synthesizes a dev version)
        type: choice
        options: [dev, prod]
        default: dev

permissions:
  contents: read
  id-token: write

concurrency:
  group: publish-${{ inputs.environment || 'prod' }}
  cancel-in-progress: false

jobs:
  publish:
    runs-on: ubuntu-latest
    environment: ${{ inputs.environment || 'prod' }}
    steps:
      - uses: actions/checkout@v6

      - uses: aws-actions/configure-aws-credentials@v6
        with:
          role-to-assume: ${{ vars.CFN_TEMPLATES_PUBLISHER_ROLE_ARN }}
          aws-region: us-west-1
          role-session-name: cfn-template-publish

      - id: ver
        name: Compute version
        run: |
          # workflow_call (release path) passes the tag verbatim (e.g. v1.2.3).
          # workflow_dispatch (manual) synthesizes a dev-flavored version so
          # concurrent runs never collide on the immutable cfn/<version>/ path.
          if [[ -n "${{ inputs.version }}" ]]; then
            echo "version=${{ inputs.version }}" >> "$GITHUB_OUTPUT"
          else
            echo "version=dev-$(git rev-parse --short HEAD)-$(date -u +%Y%m%d%H%M%S)" >> "$GITHUB_OUTPUT"
          fi

      - name: Sync templates to S3
        env:
          BUCKET: ${{ vars.CFN_TEMPLATES_BUCKET }}
          VERSION: ${{ steps.ver.outputs.version }}
        run: |
          set -xe

          # Versioned path: immutable after first publish so customers can pin.
          aws s3 cp cloudformation/template.yaml \
            "s3://${BUCKET}/cfn/${VERSION}/template.yaml" \
            --content-type text/yaml --cache-control 'public, max-age=300'
          aws s3 cp cloudformation/template-autocomplete.yaml \
            "s3://${BUCKET}/cfn/${VERSION}/template-autocomplete.yaml" \
            --content-type text/yaml --cache-control 'public, max-age=300'

          # Moving 'latest' alias: shorter cache TTL because it changes on
          # every release and the Launch Stack URL points at it.
          aws s3 cp cloudformation/template.yaml \
            "s3://${BUCKET}/cfn/latest/template.yaml" \
            --content-type text/yaml --cache-control 'public, max-age=60'
          aws s3 cp cloudformation/template-autocomplete.yaml \
            "s3://${BUCKET}/cfn/latest/template-autocomplete.yaml" \
            --content-type text/yaml --cache-control 'public, max-age=60'

      - name: Invalidate CloudFront
        run: |
          aws cloudfront create-invalidation \
            --distribution-id "${{ vars.CFN_TEMPLATES_DISTRIBUTION_ID }}" \
            --paths '/cfn/latest/*'
```

- [ ] **Step 2: Verify with actionlint and trigger asserts**

Run:
```bash
actionlint .github/workflows/publish.yml && \
grep -q "workflow_call:" .github/workflows/publish.yml && \
grep -q "workflow_dispatch:" .github/workflows/publish.yml && \
! grep -qE "^\s*tags:" .github/workflows/publish.yml && \
echo "ALL OK"
```
Expected: `actionlint` prints nothing (exit 0), then `ALL OK`. If actionlint reports an error, fix the YAML. If `ALL OK` is missing, a required trigger is absent or the `tags:` trigger wasn't removed.

> Note: don't assert the `on:` block with `yq` — the YAML key `on` is parsed as boolean `true` by many tools (the "Norway problem"). `grep` + `actionlint` are reliable here.

- [ ] **Step 3: Commit**

```bash
git add .github/workflows/publish.yml
git commit -m "ci: make publish.yml a reusable workflow_call workflow"
```

---

### Task 3: Add the release workflow (`release-please.yml`)

The release workflow: job 1 runs release-please; job 2 publishes, gated on `release_created`, by calling the Task 2 reusable workflow.

**Files:**
- Create: `.github/workflows/release-please.yml`

**Interfaces:**
- Consumes: `release-please-config.json` + `.release-please-manifest.json` (Task 1); `./.github/workflows/publish.yml` with inputs `environment`, `version` (Task 2).
- Produces: nothing downstream.

- [ ] **Step 1: Create `.github/workflows/release-please.yml` with this exact content**

```yaml
name: Release

on:
  push:
    branches: [main]

permissions: {}

jobs:
  release-please:
    runs-on: ubuntu-latest
    permissions:
      contents: write          # create the release commit, tag, and GitHub Release
      pull-requests: write      # open/update the release PR
    outputs:
      release_created: ${{ steps.release.outputs.release_created }}
      tag_name: ${{ steps.release.outputs.tag_name }}
      version: ${{ steps.release.outputs.version }}
    steps:
      - uses: googleapis/release-please-action@v4
        id: release
        with:
          config-file: release-please-config.json
          manifest-file: .release-please-manifest.json
          # Default GITHUB_TOKEN is fine: we do NOT rely on the tag-push event.
          # The publish job below is chained via needs/if instead.

  publish:
    needs: release-please
    if: needs.release-please.outputs.release_created == 'true'
    permissions:
      contents: read
      id-token: write          # OIDC for aws-actions/configure-aws-credentials
    uses: ./.github/workflows/publish.yml
    with:
      environment: prod
      version: ${{ needs.release-please.outputs.tag_name }}
    secrets: inherit
```

> For a **root component** (path `.`), release-please-action v4 emits *un-prefixed* outputs — `release_created`, `tag_name`, `version` — so the job `outputs` block above is correct (no `.--` prefix).

- [ ] **Step 2: Verify with actionlint**

`actionlint` reads the local `uses: ./.github/workflows/publish.yml` and checks that the inputs (`environment`, `version`) and `secrets: inherit` match Task 2's definition, and that `needs.release-please.outputs.release_created` references a declared output.

Run:
```bash
actionlint .github/workflows/release-please.yml && echo "actionlint OK"
```
Expected: `actionlint OK` with no preceding errors. A message like `input "version" is required` or `property "release_created" is not defined` means Task 2 or the outputs block is out of sync — fix before committing.

- [ ] **Step 3: Commit**

```bash
git add .github/workflows/release-please.yml
git commit -m "ci: add release-please release workflow with chained publish"
```

---

### Task 4: Add the PR-title lint gate (`pr-title-lint.yml`)

Validates every PR title against Conventional Commits — the exact text release-please consumes under squash-merge. Posts a sticky comment on failure.

**Files:**
- Create: `.github/workflows/pr-title-lint.yml`

**Interfaces:**
- Consumes: nothing.
- Produces: a required status check whose context is the **job name** `lint-pr-title` (made required in branch protection — see Manual Operator Steps).

- [ ] **Step 1: Create `.github/workflows/pr-title-lint.yml` with this exact content**

```yaml
name: Lint PR title

on:
  pull_request:
    types: [opened, edited, reopened, synchronize]

permissions:
  pull-requests: write       # read the PR title; write the sticky failure comment

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: amannn/action-semantic-pull-request@v6
        id: lint
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        with:
          types: |
            feat
            fix
            perf
            deps
            docs
            chore
            refactor
            test
            build
            ci
            style
            revert
          requireScope: false

      - if: always() && steps.lint.outputs.error_message != ''
        uses: marocchino/sticky-pull-request-comment@v2
        with:
          header: pr-title-lint
          message: |
            ## ⚠ This PR title is not a valid Conventional Commit

            ```
            ${{ steps.lint.outputs.error_message }}
            ```

            Use `type(optional-scope): summary`, e.g. `fix(terraform): correct partition ARN`.
            Allowed types: feat, fix, perf, deps, docs, chore, refactor, test, build, ci, style, revert.
            See CONTRIBUTING.md.

      - if: steps.lint.outputs.error_message == ''
        uses: marocchino/sticky-pull-request-comment@v2
        with:
          header: pr-title-lint
          delete: true
```

> The failure-comment step uses `always()` so it still runs after the lint step fails (a failing lint step is what turns the check red for branch protection). The cleanup step has no `always()`, so it only deletes the comment when the title is valid.

- [ ] **Step 2: Verify with actionlint**

Run:
```bash
actionlint .github/workflows/pr-title-lint.yml && echo "actionlint OK"
```
Expected: `actionlint OK` with no preceding errors.

- [ ] **Step 3: Commit**

```bash
git add .github/workflows/pr-title-lint.yml
git commit -m "ci: lint PR titles against Conventional Commits"
```

---

### Task 5: Document the convention (`CONTRIBUTING.md`)

Contributor-facing documentation of the commit convention and how releases work.

**Files:**
- Create: `CONTRIBUTING.md`

**Interfaces:**
- Consumes: nothing.
- Produces: nothing.

- [ ] **Step 1: Create `CONTRIBUTING.md` with this exact content**

````markdown
# Contributing

## Commit / PR-title convention

This repo uses [Conventional Commits](https://www.conventionalcommits.org/) to
drive automated releases via [release-please](https://github.com/googleapis/release-please).

**We squash-merge, so the _pull-request title_ becomes the release commit.** Write
the PR title as a Conventional Commit; the individual commit messages on your
branch don't matter. A CI check ("Lint PR title") blocks merge if the title isn't
valid.

Format:

```
type(optional-scope): summary
```

### Allowed types

| Type | Meaning | Changelog | Version bump |
|------|---------|-----------|--------------|
| `feat` | New capability | Features | minor |
| `fix` | Bug fix | Bug Fixes | patch |
| `perf` | Performance improvement | Performance Improvements | patch |
| `deps` | Dependency change | Dependencies | patch |
| `revert` | Revert a previous change | Reverts | patch |
| `docs` | Documentation only | hidden | none |
| `chore` | Maintenance | hidden | none |
| `refactor` | Code change, no behavior change | hidden | none |
| `test` | Tests only | hidden | none |
| `build` | Build/packaging | hidden | none |
| `ci` | CI/workflow change | hidden | none |
| `style` | Formatting only | hidden | none |

### Breaking changes

Append `!` after the type/scope **or** add a `BREAKING CHANGE:` footer to bump the
**major** version:

```
feat(policy)!: drop legacy EntHomeAccess prefix
```

### Scopes (optional, free-form)

Scopes are optional and not enforced against a fixed list. Recommended ones map to
the top-level directories: `cfn`, `terraform`, `cdk`, `pulumi`, `policy`, `ci`,
`docs`. Example: `fix(terraform): correct partition ARN`.

## How releases work

1. Merge your PRs to `main` as usual (with valid Conventional-Commit titles).
2. release-please maintains a **release PR** that bumps `version.txt`, updates
   `.release-please-manifest.json`, and regenerates `CHANGELOG.md` from the
   commits since the last release.
3. When a maintainer merges the release PR, release-please creates the tag
   `vX.Y.Z` and a GitHub Release, and the CloudFormation templates are published
   automatically to S3/CloudFront.

Manual publishing (e.g. a `dev` smoke test) is available via the **Publish CFN
templates** workflow's `workflow_dispatch` trigger.
````

- [ ] **Step 2: Verify the file exists and contains the types table**

Run:
```bash
test -f CONTRIBUTING.md && \
grep -q "Conventional Commits" CONTRIBUTING.md && \
grep -q "release-please" CONTRIBUTING.md && \
grep -q "squash-merge" CONTRIBUTING.md && \
echo "ALL OK"
```
Expected: `ALL OK`.

- [ ] **Step 3: Commit**

```bash
git add CONTRIBUTING.md
git commit -m "docs: document Conventional Commits and the release process"
```

---

## Manual Operator Steps (post-merge, GitHub UI — not automatable)

These require repo-admin access in the GitHub UI and cannot be done in code. Do them **after** this PR merges to `main`. They are required for the process to function.

1. **Allow release-please to open its release PR.** Easiest: **Settings → Actions → General → Workflow permissions →** enable **"Allow GitHub Actions to create and approve pull requests."** If that toggle is locked off by org policy (common in hardened orgs), the release workflow instead authenticates as a **GitHub App**: provide repo variable `RELEASE_PLEASE_APP_ID` and secret `RELEASE_PLEASE_APP_PRIVATE_KEY` for an App (Contents + Pull requests: write) installed on this repo. (This repo uses the GitHub App path.)
2. **Settings → General → Pull Requests → "Allow squash merging":** set the squash-merge commit message to **"Default to pull request title."** This makes the squashed commit subject equal the validated PR title that release-please parses.
3. **Settings → Branches → branch protection for `main`:** require a PR before merging, and mark the **`lint-pr-title`** status check as **required** (that is the job name in the "Lint PR title" workflow; it appears in the check search box once the workflow has run on a PR). If the repo uses **Rulesets** instead, do the same under **Settings → Rules → Rulesets**.
4. **Environments → `prod`:** if it has required reviewers, the chained publish job will pause for approval before publishing — a deliberate prod gate. Leave as-is unless you want fully unattended publishes.

## Post-merge Smoke Test

Validates the end-to-end flow once the workflows are on `main` and the operator steps are done.

1. **Lint gate:** open a PR titled `not a conventional commit` → confirm **"Lint PR title"** fails and blocks merge. Rename it to `fix(ci): smoke-test lint` → confirm it passes.
2. **Release PR:** merge a real `fix:` or `feat:` PR → confirm release-please opens a "release PR" proposing the expected bump (`fix` → `1.0.1`, `feat` → `1.1.0`) with a `CHANGELOG.md` entry.
3. **Tag + publish:** merge the release PR → confirm tag `vX.Y.Z` and a GitHub Release are created, the `publish` job runs (not skipped), and `s3://<bucket>/cfn/vX.Y.Z/template.yaml` + `cfn/latest/template.yaml` are updated and CloudFront `/cfn/latest/*` is invalidated.

## Notes for the implementer

- **Title this implementation PR with a non-releasing type**, e.g. `ci: add automated release process`. If you title it `feat:`/`fix:`, the first thing release-please does after merge is propose a release for the setup PR itself. A `ci:` title keeps the baseline clean so the *next* real change drives the first managed release.
- `terraform-check.yml` is intentionally untouched; its checks must still pass.
- No version stamping into `package.json`/`Pulumi.yaml` — out of scope per the spec (they're `private`, never published).
