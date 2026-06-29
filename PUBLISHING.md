# Publishing pipeline

Internal notes for maintainers of `aws-ent-deploy-role`. Customers reading the README don't need any of this.

## What gets published, where

`cloudformation/template.yaml` and `cloudformation/template-autocomplete.yaml` are uploaded to S3 + CloudFront in two AWS accounts:

| Env | URL | Bucket | CloudFront | Publisher role |
|---|---|---|---|---|
| dev | `https://bootstrap.dev.home.ent.security` | `dev-uswest1-cfn-templates` (account `955852928291`) | `E205EV5XBJU8Z1` | `arn:aws:iam::955852928291:role/dev-uswest1-cfn-templates-publisher` |
| prod | `https://bootstrap.prod.home.ent.ai` | `prod-uswest1-cfn-templates` (account `051759900972`) | `E3OPVJUA5XLOY5` | `arn:aws:iam::051759900972:role/prod-uswest1-cfn-templates-publisher` |

Both buckets are provisioned by `ent-security/ent-platform` Tofu in `deploy/tofu/home/cfn-templates.tf` (W2.1 of the Launch Stack onboarding plan).

Objects land at two paths per release:

- `cfn/<version>/template{,-autocomplete}.yaml` — immutable, 5-min S3 cache-control. Customers who want a pinned URL reference this.
- `cfn/latest/template{,-autocomplete}.yaml` — moving alias, 60-sec S3 cache-control. The Launch Stack URL embedded in onboarding emails points here.

CloudFront invalidates `/cfn/latest/*` on every publish so the alias propagates within seconds rather than after the edge TTL.

## How publishes are triggered

Single workflow: `.github/workflows/publish.yml`. Routes by trigger:

- **`push: tags: ['v*']`** → runs in the `prod` GitHub Environment. Version = the tag verbatim (e.g. `v1.0.0`).
- **`workflow_dispatch`** → runs in the chosen environment (default `dev`). Version = `dev-<short-sha>-<utc-timestamp>`.

The three config values per env (bucket, distribution id, publisher role ARN) live as environment-scoped variables — set under Settings → Environments → `<env>` → Variables. They are NOT at the repo level; repo-level vars from the initial bring-up were deleted once env-level was wired in.

## OIDC trust details (the gotcha)

This pipeline has one piece of repo-level config that lives outside the source tree and is easy to miss. The publisher roles' trust policies match the OIDC `sub` claim against `repo:ent-security/aws-ent-deploy-role:ref:refs/...` patterns. GitHub's default behavior, when a job specifies `environment:`, is to emit `sub=repo:owner/repo:environment:<env>` instead — which would fail the trust check.

To keep the trust patterns ref-based, this repo has the OIDC sub claim customized:

```bash
gh api -X PUT /repos/ent-security/aws-ent-deploy-role/actions/oidc/customization/sub \
  --input <(echo '{"use_default":false,"include_claim_keys":["repo","ref"]}')
```

Current value (`gh api /repos/ent-security/aws-ent-deploy-role/actions/oidc/customization/sub`):

```json
{
  "use_default": false,
  "include_claim_keys": ["repo", "ref"]
}
```

**This is repo-wide.** Any future workflow in this repo that wants env-based OIDC auth needs to either: (a) reset the customization back to default and update the publisher trust policies to match, or (b) explicitly include the `environment` claim by adding it to `include_claim_keys` and updating trust policies in lockstep.

The dev publisher role's trust additionally accepts `refs/heads/*` (added in `ent-platform` PR #2739) so `workflow_dispatch` from any branch can publish to the dev bucket. Prod stays restricted to `refs/tags/v*`.

## Cutting a release

```bash
git tag -a v1.2.3 -m "describe what changed"
git push origin v1.2.3
```

That fires the workflow, which assumes the prod publisher role, syncs both templates to `cfn/v1.2.3/` and `cfn/latest/`, and invalidates CloudFront. Run history lives at `https://github.com/ent-security/aws-ent-deploy-role/actions/workflows/publish.yml`.

## Testing in dev before a release

From the Actions tab → Publish CFN templates → Run workflow → keep environment as `dev` → Run. Same workflow, different env vars resolved. Confirm at `https://bootstrap.dev.home.ent.security/cfn/latest/template-autocomplete.yaml` before tagging for prod.
