# CDK and Pulumi Template Support

**Date:** 2026-04-23
**Status:** Approved — ready for implementation plan

## Summary

Add AWS CDK and Pulumi templates to `aws-ent-deploy-role` alongside the existing Terraform and CloudFormation templates. Also add a first-class OpenTofu note to the top-level README to make it explicit that the Terraform module is compatible with OpenTofu.

New templates:

- CDK in TypeScript and Python
- Pulumi in TypeScript, Python, and Go

All five new templates load the authoritative `policy.json` and `role.json` at synthesis/deploy time rather than hand-inlining the policy.

## Motivation

The repo currently ships Terraform and CloudFormation. CDK and Pulumi are the two most-requested IaC tools beyond those, and adding them widens the set of customers who can deploy the Ent Home role using their existing tooling. OpenTofu users can already use the Terraform module unchanged — calling that out explicitly in the README removes a friction point.

## Goals

- Provide runnable CDK apps in TypeScript and Python
- Provide runnable Pulumi apps in TypeScript, Python, and Go
- Keep IAM policy statements in sync across all templates by having the new templates read `policy.json` at synthesis/deploy time
- Preserve parity with the existing Terraform configuration surface (same variables, same outputs, same resource names)
- Document OpenTofu as a supported runtime for the existing Terraform module

## Non-Goals

- Migrating Terraform and CloudFormation to read `policy.json` (flagged as a follow-up)
- Publishing packages to npm, PyPI, NuGet, or Go modules
- Shipping reusable CDK constructs or Pulumi ComponentResources
- Adding CI/synth-check workflows beyond what the languages need to build cleanly

## Directory Structure

```
aws-ent-deploy-role/
├── cdk/
│   ├── typescript/
│   └── python/
├── pulumi/
│   ├── typescript/
│   ├── python/
│   └── go/
├── cloudformation/
├── terraform/
├── policy.json
├── role.json
└── README.md
```

Grouping by tool then by language mirrors the existing `terraform/` and `cloudformation/` top-level directories. Each leaf directory is a standalone, runnable app.

## How Each Template Loads the Authoritative JSON

All five new templates read `policy.json` and `role.json` from the repo root (relative path `../../policy.json` and `../../role.json` from each leaf directory) at synthesis/deploy time. The trust policy's `<ENT_AWS_ACCOUNT_ARN>` placeholder is substituted with the configured principal (same substitution pattern the AWS CLI flow uses in the README).

Per-template mechanics:

- **CDK (TypeScript / Python):** read JSON files with stdlib (`fs.readFileSync` / `json.load`), substitute the principal, then pass to `iam.PolicyDocument.fromJson()` for the managed policy and the role's `assumeRolePolicyDocument`.
- **Pulumi (TypeScript / Python / Go):** read JSON files with stdlib, substitute the principal, then pass the JSON strings to `aws.iam.ManagedPolicy`'s `policy` argument and `aws.iam.Role`'s `assumeRolePolicy` argument (both accept raw JSON).

## Resources Created

Matching Terraform today:

- One `ManagedPolicy` named `EntHomeAccess`
- One `Role` named `HomeProdAssumeAdmin` (default, configurable)
- Policy attached to role

## Configuration Parity

Each template exposes the same knobs as Terraform's `variables.tf`, via the idiomatic mechanism for that tool (CDK context/props, Pulumi config):

| Knob | Default |
|---|---|
| `ent_aws_account_arn` | `arn:aws:iam::051759900972:role/prod-uswest1-eks-pi-1-20251203221124633900000005` |
| `role_name` | `HomeProdAssumeAdmin` |
| `role_path` | `/` |
| `role_description` | Matches Terraform default |
| `tags` | `{}` |

## Outputs Parity

Each template exposes:

- `role_arn`
- `role_name`
- `policy_arn`

## Per-Leaf-Directory Contents

**`cdk/typescript/`**
- `package.json`, `tsconfig.json`, `cdk.json`
- `bin/app.ts` — app entrypoint
- `lib/ent-deploy-role-stack.ts` — stack definition
- `README.md` — prerequisites, install, configure, deploy, destroy

**`cdk/python/`**
- `requirements.txt`, `cdk.json`, `app.py`
- `ent_deploy_role/ent_deploy_role_stack.py`
- `README.md`

**`pulumi/typescript/`**
- `Pulumi.yaml`, `package.json`, `tsconfig.json`
- `index.ts`
- `README.md`

**`pulumi/python/`**
- `Pulumi.yaml`, `requirements.txt`
- `__main__.py`
- `README.md`

**`pulumi/go/`**
- `Pulumi.yaml`, `go.mod`, `go.sum`
- `main.go`
- `README.md`

Each leaf `README.md` covers: prerequisites (runtime version, CLI tool), install, configure (how to set `ent_aws_account_arn`, `role_name`, etc.), deploy, destroy.

## Top-Level README Changes

1. **Opening line:** "Supports both Terraform and CloudFormation" → "Supports Terraform, CloudFormation, AWS CDK, and Pulumi."
2. **Explicit OpenTofu note** under the existing "Deploying with Terraform / OpenTofu" section stating that the Terraform module works unmodified with OpenTofu using `tofu init` / `tofu plan` / `tofu apply`.
3. **New "CDK Usage" section** with TypeScript and Python subsections containing minimal deploy snippets, linking to `cdk/typescript/README.md` and `cdk/python/README.md` for details.
4. **New "Pulumi Usage" section** with TypeScript, Python, and Go subsections following the same pattern.
5. **Directory-structure block** updated to include `cdk/` and `pulumi/`.
6. **Setup section** gains "CDK" and "Pulumi" flows alongside the existing Terraform and CloudFormation steps.

## Follow-Ups (Out of Scope)

- Migrate Terraform and CloudFormation to read `policy.json` at synthesis time, so `policy.json` is the single source of truth across all seven templates.
- Add a CI job that runs `cdk synth` / `pulumi preview` against each new template to catch drift between the JSON files and what the templates can build.
- Publish CDK constructs and Pulumi components as packages (npm, PyPI, Go modules) if customer demand materializes.
