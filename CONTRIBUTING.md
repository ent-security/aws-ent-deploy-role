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
