# Automated Release Process (release-please + Conventional Commits)

**Date:** 2026-06-29
**Status:** Approved — ready for implementation plan

## Summary

Introduce an automated, Conventional-Commits-driven release process for
`aws-ent-deploy-role` using [release-please](https://github.com/googleapis/release-please)
in manifest mode, plus a PR-title lint gate that enforces Conventional Commits
on exactly the text release-please consumes.

The repository is **one logical product** (the Ent deploy role) expressed in five
IaC stacks (CloudFormation, Terraform/OpenTofu, CDK [TS+Python], Pulumi
[Go/Python/TS]). It is versioned with a **single repo-wide semver**. The
published artifact is the CloudFormation template synced to S3 + CloudFront; that
publish is chained off the release so cutting a release publishes automatically.

## Motivation

- Versioning today is inconsistent: a single non-semver tag `v1.0.0.0`, stale
  `0.1.0` in the (private, never-published) `package.json`s, and no version at all
  in the `Pulumi.yaml`s. There is no CHANGELOG and no release automation.
- Commit/PR-title style is mixed (`PLA-2692: …`, `Make …`, `Add …`), so there is
  no machine-readable signal for what changed or how to bump the version.
- The existing `publish.yml` triggers on `push: tags: ['v*']`, but a tag pushed by
  release-please's default `GITHUB_TOKEN` would **not** trigger that workflow
  (GitHub suppresses workflow-triggering-workflow recursion), so naive adoption
  would silently never publish.

## Goals

- One repo-wide semver, one CHANGELOG, one release PR covering all stacks.
- Releases driven entirely by Conventional Commits on merged PR titles.
- Enforce Conventional Commits via a required PR-title check (the squash-merge
  workflow means the PR title *is* the release commit).
- Cutting a release auto-publishes the CloudFormation template through the
  existing S3/CloudFront flow, with **no new secrets**.
- Preserve the manual `dev`/`prod` publish path (`workflow_dispatch`).

## Non-Goals

- No per-package / per-language independent versioning (single version only).
- No version stamping into `package.json` / `Pulumi.yaml` (they are `private` and
  never published to a registry; their version fields are inert).
- No local commitlint / Husky hooks (squash-merge discards individual commit
  messages; only the PR title matters).
- No change to *what* is published, the S3 layout, or the Terraform/policy test
  suites (`terraform-check.yml` is untouched).

## Decisions (from brainstorming)

1. **Scope:** single repo-wide version — one tag `vX.Y.Z`, one CHANGELOG, one
   release PR.
2. **Baseline:** continue from `1.0.0` anchored at current `main` HEAD
   (`0efe596`). CHANGELOG starts fresh; the next Conventional-Commit PR drives the
   bump. The old `v1.0.0.0` tag and its `cfn/v1.0.0.0/` S3 path stay as history.
3. **Enforcement:** PR-title lint as a required check; pair with GitHub's "default
   to PR title" squash setting. No local hooks.
4. **Release → publish wiring:** refactor `publish.yml` into a reusable
   (`workflow_call`) workflow; `release-please.yml` invokes it in a job gated on
   `release_created == 'true'`. Avoids the `GITHUB_TOKEN`-can't-trigger-workflows
   trap; no new secrets.

## Release flow

```
PR merged to main (squash; PR title = Conventional Commit)
        │
        ▼
release-please.yml (on: push to main)
   └─ opens/updates a "release PR": bumps version.txt + manifest,
      regenerates CHANGELOG.md from the conventional commits
        │
   maintainer merges the release PR
        │
        ▼
release-please creates tag vX.Y.Z + GitHub Release   (release_created = true)
        │
        ▼
publish job  ── uses: ./.github/workflows/publish.yml (workflow_call) ──►
   S3 cfn/vX.Y.Z/  +  cfn/latest/  +  CloudFront invalidation
```

`fix:` → patch, `feat:` → minor, `feat!:` / `BREAKING CHANGE:` → major.

## Components / files

### New: `release-please-config.json` (repo root)

`release-type: simple` (no language package — maintains `version.txt` + CHANGELOG),
single root package, plain `vX.Y.Z` tags, explicit changelog sections, and the
baseline anchor.

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

- `include-component-in-tag: false` → tags are `v1.1.0`, not
  `aws-ent-deploy-role-v1.1.0`. Matches the existing `v*` convention, the
  `publish.yml` trigger, and the `cfn/<version>/` S3 path.
- `last-release-sha` is the correct boundary knob here (schema: *"for any release,
  only consider as far back as this commit SHA"*). Because the manifest seeds
  `1.0.0` as already-released, this is **not** an initial release, so
  `bootstrap-sha` (initial-release-only) does not apply. Anchoring at `0efe596`
  stops release-please from scanning all pre-existing history into the first
  CHANGELOG.

### New: `.release-please-manifest.json` (repo root)

```json
{
  ".": "1.0.0"
}
```

### New: `version.txt` (repo root)

The `simple` release type tracks the version in `version.txt`. Seed it to match
the manifest; release-please rewrites it on each release.

```
1.0.0
```

### New: `.github/workflows/release-please.yml`

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
      version: ${{ needs.release-please.outputs.tag_name }}   # e.g. v1.2.0
    secrets: inherit
```

Note: for a **root component** (path `.`), release-please-action v4 emits
*un-prefixed* outputs — `release_created`, `tag_name`, `version` — so the job
outputs above are correct (no `.--` prefix needed).

### Changed: `.github/workflows/publish.yml`

Add a `workflow_call` trigger (inputs `environment`, `version`) alongside the
existing `workflow_dispatch`. **Remove the `on: push: tags: ['v*']` trigger** — it
cannot fire from release-please's bot token anyway, and removing it prevents an
accidental double-publish if anyone pushes a tag by hand. The "Compute version"
step uses the passed `version` verbatim when present, else falls back to the
`dev-<sha>-<timestamp>` synthesis for manual dispatch. Everything below the
version step (S3 sync, CloudFront invalidation) is unchanged.

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

      # ... existing "Sync templates to S3" and "Invalidate CloudFront" steps, unchanged ...
```

### New: `.github/workflows/pr-title-lint.yml`

```yaml
name: Lint PR title

on:
  pull_request:
    types: [opened, edited, reopened, synchronize]

permissions:
  pull-requests: read

jobs:
  validate:
    runs-on: ubuntu-latest
    permissions:
      pull-requests: write       # for the sticky failure comment
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
          requireScope: false     # scopes are optional and free-form

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
            See CONTRIBUTING.md for the allowed types.
      - if: steps.lint.outputs.error_message == ''
        uses: marocchino/sticky-pull-request-comment@v2
        with:
          header: pr-title-lint
          delete: true
```

`amannn/action-semantic-pull-request` is pinned at **v6** (current major). It sets
a check status that branch protection can require.

### New: `CONTRIBUTING.md`

Documents:

- Conventional Commits format: `type(optional-scope): summary`.
- **Squash-merge → the PR title is the release commit.** Write PR titles as
  Conventional Commits; individual commit messages on the branch don't matter.
- Allowed types table (mirrors `changelog-sections`): `feat`, `fix`, `perf`,
  `deps` are visible in the changelog; `feat!`/`BREAKING CHANGE:` → major;
  `docs`/`chore`/`refactor`/`test`/`build`/`ci`/`style`/`revert` are allowed but
  hidden from the changelog.
- Recommended (optional, free-form) scopes: `cfn`, `terraform`, `cdk`, `pulumi`,
  `policy`, `ci`, `docs`.
- How releases work: merge feature PRs → release-please maintains a release PR →
  merge the release PR → tag + GitHub Release + CFN publish happen automatically.

## Conventional Commit types

| Type | Changelog section | Version bump |
|------|-------------------|--------------|
| `feat` | Features | minor |
| `fix` | Bug Fixes | patch |
| `perf` | Performance Improvements | patch |
| `deps` | Dependencies | patch |
| `revert` | Reverts | patch |
| `docs`, `chore`, `refactor`, `test`, `build`, `ci`, `style` | hidden | none |
| `feat!` / `fix!` / `BREAKING CHANGE:` footer | ⚠ Breaking (under its type) | major |

Scopes are validated only for *format*, not against a fixed list
(`requireScope: false`).

## Manual repository settings (cannot be set in code — implementation checklist)

1. **Settings → Actions → General → Workflow permissions:** enable **"Allow
   GitHub Actions to create and approve pull requests."** *Required* — otherwise
   release-please cannot open its release PR.
2. **Settings → General → Pull Requests:** set the squash-merge commit message to
   **"Default to pull request title."** Ensures the squashed commit subject equals
   the validated PR title that release-please parses.
3. **Branch protection on `main`:** require the **"Lint PR title"** status check
   (and require a PR before merging).
4. **`prod` environment:** if it has required reviewers, the chained publish job
   pauses for approval before publishing — a deliberate prod gate. Acceptable;
   document it so it isn't mistaken for a hang.

## Behavior changes to call out

- `publish.yml` no longer runs on `git push --tags`. Manual publishing is via
  `workflow_dispatch` (dev synthesizes a `dev-<sha>-<ts>` version; prod requires
  the `version` input only on the `workflow_call` path).
- The first managed release will be `v1.0.1` / `v1.1.0` / `v2.0.0` depending on the
  first Conventional-Commit PR merged after this process lands. The setup PR
  itself should be titled with a non-releasing type (e.g. `ci: add automated
  release process`) so it does not, on its own, force an immediate release.

## Verification

- **Static:** both JSON config files validate against their schema; all workflow
  YAML parses (run `actionlint` if available).
- **Smoke test (documented, post-merge):**
  1. Open a trivial `fix:` PR → confirm "Lint PR title" passes; open a PR with a
     bad title → confirm it fails and blocks merge.
  2. Merge a `fix:`/`feat:` PR → confirm release-please opens a release PR
     proposing the expected bump and a CHANGELOG entry.
  3. Merge the release PR → confirm tag `vX.Y.Z` + GitHub Release are created and
     the `publish` job runs, writing `cfn/vX.Y.Z/` and refreshing `cfn/latest/`.
- No changes to `terraform-check.yml`; its checks must still pass.

## Risks / mitigations

- **Tag-trigger trap** (bot token won't fire `publish.yml`): mitigated by chaining
  publish via `needs`/`if` in `release-please.yml` rather than the tag-push event.
- **Non-semver legacy tag `v1.0.0.0`:** release-please ignores it (not valid
  semver); `last-release-sha` provides the scan boundary instead, so the first
  CHANGELOG is clean.
- **Reusable-workflow OIDC:** the `publish` caller job grants `id-token: write`
  and `publish.yml` declares the same; the effective token is the intersection, so
  OIDC continues to work. `secrets: inherit` is harmless (OIDC needs no secret).
