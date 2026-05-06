# CDK and Pulumi Template Support Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add AWS CDK (TypeScript, Python) and Pulumi (TypeScript, Python, Go) templates that provision the same `EntHomeAccess` managed policy and `HomeProdAssumeAdmin` role as the existing Terraform and CloudFormation templates, and document first-class OpenTofu compatibility in the top-level README.

**Architecture:** Each new template is a standalone, runnable app in its own leaf directory under `cdk/<language>/` or `pulumi/<language>/`. Every template reads `policy.json` and `role.json` from the repo root at synthesis/deploy time, substituting the `<ENT_AWS_ACCOUNT_ARN>` placeholder with a configurable principal. Resource names, configuration knobs, and outputs match Terraform's interface.

**Tech Stack:**
- CDK: `aws-cdk-lib` (v2) for TypeScript + Python
- Pulumi: `@pulumi/aws` / `pulumi-aws` / `github.com/pulumi/pulumi-aws-sdk-go` v6
- Tests: `aws-cdk-lib/assertions` (CDK), `@pulumi/pulumi` mocks (Pulumi TS/Python), `pulumi.WithMocks` (Pulumi Go)
- Node 18+, Python 3.9+, Go 1.21+

---

## File Structure

Files created by this plan:

```
cdk/typescript/
├── package.json
├── tsconfig.json
├── cdk.json
├── jest.config.js
├── bin/app.ts
├── lib/ent-deploy-role-stack.ts
├── test/ent-deploy-role-stack.test.ts
├── .gitignore
└── README.md

cdk/python/
├── requirements.txt
├── requirements-dev.txt
├── cdk.json
├── app.py
├── ent_deploy_role/__init__.py
├── ent_deploy_role/ent_deploy_role_stack.py
├── tests/__init__.py
├── tests/test_ent_deploy_role_stack.py
├── .gitignore
└── README.md

pulumi/typescript/
├── Pulumi.yaml
├── package.json
├── tsconfig.json
├── index.ts
├── tests/index.spec.ts
├── .gitignore
└── README.md

pulumi/python/
├── Pulumi.yaml
├── requirements.txt
├── requirements-dev.txt
├── __main__.py
├── tests/__init__.py
├── tests/test_main.py
├── .gitignore
└── README.md

pulumi/go/
├── Pulumi.yaml
├── go.mod
├── main.go
├── main_test.go
├── .gitignore
└── README.md
```

Files modified:
- `README.md` (top-level) — OpenTofu note, CDK Usage section, Pulumi Usage section, opening line, directory structure, Setup flows

---

## Task 1: README top-level — first-class OpenTofu note

**Files:**
- Modify: `README.md` (the existing "Deploying with Terraform / OpenTofu" section, lines ~22–36)

- [ ] **Step 1: Add explicit OpenTofu compatibility paragraph**

Edit `README.md`. Find the section header `### Deploying with Terraform / OpenTofu` and replace the sentence on the following line with a paragraph that calls out first-class OpenTofu support:

Old:
```markdown
If you want to deploy the Terraform module directly (e.g. from a local clone), you can use either Terraform or OpenTofu:
```

New:
```markdown
The Terraform module in this repository works unmodified with [OpenTofu](https://opentofu.org/) — the open-source fork of Terraform. Anywhere the instructions below say `terraform`, you can substitute `tofu` and get the same result.

If you want to deploy the module directly (e.g. from a local clone), you can use either tool:
```

- [ ] **Step 2: Verify the rest of the section (existing code block) already shows both commands**

The existing code block already contains `# or: tofu init`, `# or: tofu plan`, `# or: tofu apply` — no change needed.

- [ ] **Step 3: Commit**

```bash
git add README.md
git commit -m "Document first-class OpenTofu compatibility in README"
```

---

## Task 2: CDK TypeScript app

**Files:**
- Create: `cdk/typescript/package.json`
- Create: `cdk/typescript/tsconfig.json`
- Create: `cdk/typescript/cdk.json`
- Create: `cdk/typescript/jest.config.js`
- Create: `cdk/typescript/.gitignore`
- Create: `cdk/typescript/bin/app.ts`
- Create: `cdk/typescript/lib/ent-deploy-role-stack.ts`
- Create: `cdk/typescript/test/ent-deploy-role-stack.test.ts`
- Create: `cdk/typescript/README.md`

- [ ] **Step 1: Create `cdk/typescript/package.json`**

```json
{
  "name": "cdk-ent-deploy-role",
  "version": "0.1.0",
  "private": true,
  "bin": {
    "app": "bin/app.js"
  },
  "scripts": {
    "build": "tsc",
    "watch": "tsc -w",
    "test": "jest",
    "cdk": "cdk"
  },
  "devDependencies": {
    "@types/jest": "^29.5.0",
    "@types/node": "^20.0.0",
    "aws-cdk": "^2.130.0",
    "jest": "^29.7.0",
    "ts-jest": "^29.1.0",
    "ts-node": "^10.9.0",
    "typescript": "^5.3.0"
  },
  "dependencies": {
    "aws-cdk-lib": "^2.130.0",
    "constructs": "^10.3.0"
  }
}
```

- [ ] **Step 2: Create `cdk/typescript/tsconfig.json`**

```json
{
  "compilerOptions": {
    "target": "ES2021",
    "module": "commonjs",
    "lib": ["es2021"],
    "declaration": true,
    "strict": true,
    "noImplicitAny": true,
    "strictNullChecks": true,
    "noImplicitThis": true,
    "alwaysStrict": true,
    "noUnusedLocals": false,
    "noUnusedParameters": false,
    "noImplicitReturns": true,
    "noFallthroughCasesInSwitch": false,
    "inlineSourceMap": true,
    "inlineSources": true,
    "experimentalDecorators": true,
    "strictPropertyInitialization": false,
    "resolveJsonModule": true,
    "esModuleInterop": true,
    "typeRoots": ["./node_modules/@types"]
  },
  "exclude": ["node_modules", "cdk.out"]
}
```

- [ ] **Step 3: Create `cdk/typescript/cdk.json`**

```json
{
  "app": "npx ts-node --prefer-ts-exts bin/app.ts",
  "watch": {
    "include": ["**"],
    "exclude": ["README.md", "cdk*.json", "**/*.d.ts", "**/*.js", "tsconfig.json", "package*.json", "yarn.lock", "node_modules", "test"]
  },
  "context": {
    "@aws-cdk/aws-iam:minimizePolicies": true,
    "@aws-cdk/core:checkSecretUsage": true
  }
}
```

- [ ] **Step 4: Create `cdk/typescript/jest.config.js`**

```javascript
module.exports = {
  testEnvironment: 'node',
  roots: ['<rootDir>/test'],
  testMatch: ['**/*.test.ts'],
  transform: {
    '^.+\\.tsx?$': 'ts-jest'
  }
};
```

- [ ] **Step 5: Create `cdk/typescript/.gitignore`**

```
*.js
!jest.config.js
*.d.ts
node_modules
cdk.out
.cdk.staging
*.tsbuildinfo
```

- [ ] **Step 6: Write the failing test — `cdk/typescript/test/ent-deploy-role-stack.test.ts`**

```typescript
import * as cdk from 'aws-cdk-lib';
import { Match, Template } from 'aws-cdk-lib/assertions';
import { EntDeployRoleStack } from '../lib/ent-deploy-role-stack';

describe('EntDeployRoleStack', () => {
  const makeTemplate = (props = {}) => {
    const app = new cdk.App();
    const stack = new EntDeployRoleStack(app, 'TestStack', {
      entAwsAccountArn: 'arn:aws:iam::123456789012:root',
      ...props,
    });
    return Template.fromStack(stack);
  };

  test('creates a managed policy named EntHomeAccess', () => {
    const template = makeTemplate();
    template.hasResourceProperties('AWS::IAM::ManagedPolicy', {
      ManagedPolicyName: 'EntHomeAccess',
    });
  });

  test('creates a role with the default name HomeProdAssumeAdmin', () => {
    const template = makeTemplate();
    template.hasResourceProperties('AWS::IAM::Role', {
      RoleName: 'HomeProdAssumeAdmin',
    });
  });

  test('substitutes the configured account ARN into the trust policy', () => {
    const template = makeTemplate();
    template.hasResourceProperties('AWS::IAM::Role', {
      AssumeRolePolicyDocument: Match.objectLike({
        Statement: Match.arrayWith([
          Match.objectLike({
            Principal: { AWS: 'arn:aws:iam::123456789012:root' },
          }),
        ]),
      }),
    });
  });

  test('honors role_name override', () => {
    const template = makeTemplate({ roleName: 'CustomRoleName' });
    template.hasResourceProperties('AWS::IAM::Role', {
      RoleName: 'CustomRoleName',
    });
  });
});
```

- [ ] **Step 7: Run the test to verify it fails**

```bash
cd cdk/typescript
npm install
npm test
```

Expected: FAIL with `Cannot find module '../lib/ent-deploy-role-stack'`.

- [ ] **Step 8: Create `cdk/typescript/lib/ent-deploy-role-stack.ts`**

```typescript
import * as fs from 'fs';
import * as path from 'path';
import * as cdk from 'aws-cdk-lib';
import * as iam from 'aws-cdk-lib/aws-iam';
import { Construct } from 'constructs';

export interface EntDeployRoleStackProps extends cdk.StackProps {
  readonly entAwsAccountArn?: string;
  readonly roleName?: string;
  readonly rolePath?: string;
  readonly roleDescription?: string;
  readonly entTags?: { [key: string]: string };
}

const DEFAULTS = {
  entAwsAccountArn: 'arn:aws:iam::051759900972:role/prod-uswest1-eks-pi-1-20251203221124633900000005',
  roleName: 'HomeProdAssumeAdmin',
  rolePath: '/',
  roleDescription: 'Role that allows Ent Home to assume AdministratorAccess role',
  policyName: 'EntHomeAccess',
  policyDescription:
    'Custom policy for permissions needed by Ent Home to deploy and manage resources in customer accounts. This policy is attached to the role that Ent Home assumes when deploying resources in customer accounts.',
};

export class EntDeployRoleStack extends cdk.Stack {
  public readonly roleArn: string;
  public readonly roleName: string;
  public readonly policyArn: string;

  constructor(scope: Construct, id: string, props: EntDeployRoleStackProps = {}) {
    super(scope, id, props);

    const entAwsAccountArn = props.entAwsAccountArn ?? DEFAULTS.entAwsAccountArn;
    const roleName = props.roleName ?? DEFAULTS.roleName;
    const rolePath = props.rolePath ?? DEFAULTS.rolePath;
    const roleDescription = props.roleDescription ?? DEFAULTS.roleDescription;

    // Resolve repo root: cdk/typescript/lib/ -> cdk/typescript/ -> cdk/ -> repo root
    const repoRoot = path.resolve(__dirname, '..', '..', '..');
    const policyJson = JSON.parse(fs.readFileSync(path.join(repoRoot, 'policy.json'), 'utf-8'));
    const trustJsonRaw = fs.readFileSync(path.join(repoRoot, 'role.json'), 'utf-8');
    const trustJson = JSON.parse(trustJsonRaw.replaceAll('<ENT_AWS_ACCOUNT_ARN>', entAwsAccountArn));

    const managedPolicy = new iam.CfnManagedPolicy(this, 'EntHomeAccessPolicy', {
      managedPolicyName: DEFAULTS.policyName,
      description: DEFAULTS.policyDescription,
      path: '/',
      policyDocument: policyJson,
    });

    const role = new iam.CfnRole(this, 'EntDeployRole', {
      roleName,
      path: rolePath,
      description: roleDescription,
      assumeRolePolicyDocument: trustJson,
      managedPolicyArns: [managedPolicy.ref],
      tags: props.entTags
        ? Object.entries(props.entTags).map(([key, value]) => ({ key, value }))
        : undefined,
    });

    this.roleArn = role.attrArn;
    this.roleName = role.ref;
    this.policyArn = managedPolicy.ref;

    new cdk.CfnOutput(this, 'RoleArn', { value: this.roleArn });
    new cdk.CfnOutput(this, 'RoleName', { value: this.roleName });
    new cdk.CfnOutput(this, 'PolicyArn', { value: this.policyArn });
  }
}
```

- [ ] **Step 9: Create `cdk/typescript/bin/app.ts`**

```typescript
#!/usr/bin/env node
import * as cdk from 'aws-cdk-lib';
import { EntDeployRoleStack } from '../lib/ent-deploy-role-stack';

const app = new cdk.App();

const tagsCtx = app.node.tryGetContext('tags');

new EntDeployRoleStack(app, 'EntDeployRoleStack', {
  entAwsAccountArn: app.node.tryGetContext('ent_aws_account_arn'),
  roleName: app.node.tryGetContext('role_name'),
  rolePath: app.node.tryGetContext('role_path'),
  roleDescription: app.node.tryGetContext('role_description'),
  entTags: tagsCtx && typeof tagsCtx === 'object' ? tagsCtx : undefined,
});
```

- [ ] **Step 10: Run tests to verify they pass**

```bash
cd cdk/typescript
npm test
```

Expected: all 4 tests PASS.

- [ ] **Step 11: Verify `cdk synth` runs without error**

```bash
cd cdk/typescript
npx cdk synth > /dev/null
```

Expected: no errors, CloudFormation template printed to stdout (redirected).

- [ ] **Step 12: Create `cdk/typescript/README.md`**

````markdown
# Ent Deploy Role — AWS CDK (TypeScript)

Deploys the Ent Home deployment role using AWS CDK v2 in TypeScript.

## Prerequisites

- Node.js 18+
- AWS CDK CLI: `npm install -g aws-cdk`
- AWS credentials configured (`aws configure` or env vars)

## Install

```bash
cd cdk/typescript
npm install
```

## Configure

Pass configuration via `-c key=value` flags on the CDK CLI, or set them in `cdk.context.json`.

| Key | Description | Default |
|---|---|---|
| `ent_aws_account_arn` | Ent's AWS account ARN | `arn:aws:iam::051759900972:role/prod-uswest1-eks-pi-1-20251203221124633900000005` |
| `role_name` | IAM role name | `HomeProdAssumeAdmin` |
| `role_path` | IAM role path | `/` |
| `role_description` | IAM role description | (matches Terraform default) |

## Deploy

```bash
npx cdk bootstrap   # one-time per account/region
npx cdk deploy \
  -c ent_aws_account_arn=arn:aws:iam::123456789012:root \
  -c role_name=HomeProdAssumeAdmin
```

After deploy, the `RoleArn` output is the ARN to paste into the Ent AWS connection panel.

## Destroy

```bash
npx cdk destroy
```

## Test

```bash
npm test
```
````

- [ ] **Step 13: Commit**

```bash
git add cdk/typescript
git commit -m "Add CDK TypeScript template for Ent deploy role"
```

---

## Task 3: CDK Python app

**Files:**
- Create: `cdk/python/requirements.txt`
- Create: `cdk/python/requirements-dev.txt`
- Create: `cdk/python/cdk.json`
- Create: `cdk/python/.gitignore`
- Create: `cdk/python/app.py`
- Create: `cdk/python/ent_deploy_role/__init__.py`
- Create: `cdk/python/ent_deploy_role/ent_deploy_role_stack.py`
- Create: `cdk/python/tests/__init__.py`
- Create: `cdk/python/tests/test_ent_deploy_role_stack.py`
- Create: `cdk/python/README.md`

- [ ] **Step 1: Create `cdk/python/requirements.txt`**

```
aws-cdk-lib>=2.130.0,<3.0.0
constructs>=10.3.0,<11.0.0
```

- [ ] **Step 2: Create `cdk/python/requirements-dev.txt`**

```
-r requirements.txt
pytest>=7.4.0
```

- [ ] **Step 3: Create `cdk/python/cdk.json`**

```json
{
  "app": "python3 app.py",
  "watch": {
    "include": ["**"],
    "exclude": ["README.md", "cdk*.json", "requirements*.txt", ".venv", "tests"]
  },
  "context": {
    "@aws-cdk/aws-iam:minimizePolicies": true,
    "@aws-cdk/core:checkSecretUsage": true
  }
}
```

- [ ] **Step 4: Create `cdk/python/.gitignore`**

```
.venv
__pycache__
*.egg-info
cdk.out
.cdk.staging
.pytest_cache
```

- [ ] **Step 5: Create `cdk/python/ent_deploy_role/__init__.py`**

Empty file (marks the directory as a package).

- [ ] **Step 6: Create `cdk/python/tests/__init__.py`**

Empty file.

- [ ] **Step 7: Write the failing test — `cdk/python/tests/test_ent_deploy_role_stack.py`**

```python
import aws_cdk as cdk
from aws_cdk import assertions

from ent_deploy_role.ent_deploy_role_stack import EntDeployRoleStack


def _template(**props):
    app = cdk.App()
    stack = EntDeployRoleStack(
        app,
        "TestStack",
        ent_aws_account_arn="arn:aws:iam::123456789012:root",
        **props,
    )
    return assertions.Template.from_stack(stack)


def test_creates_managed_policy_named_ent_home_access():
    template = _template()
    template.has_resource_properties(
        "AWS::IAM::ManagedPolicy",
        {"ManagedPolicyName": "EntHomeAccess"},
    )


def test_creates_role_with_default_name():
    template = _template()
    template.has_resource_properties(
        "AWS::IAM::Role",
        {"RoleName": "HomeProdAssumeAdmin"},
    )


def test_substitutes_account_arn_in_trust_policy():
    template = _template()
    template.has_resource_properties(
        "AWS::IAM::Role",
        {
            "AssumeRolePolicyDocument": assertions.Match.object_like({
                "Statement": assertions.Match.array_with([
                    assertions.Match.object_like({
                        "Principal": {"AWS": "arn:aws:iam::123456789012:root"},
                    }),
                ]),
            }),
        },
    )


def test_honors_role_name_override():
    template = _template(role_name="CustomRoleName")
    template.has_resource_properties(
        "AWS::IAM::Role",
        {"RoleName": "CustomRoleName"},
    )
```

- [ ] **Step 8: Run tests to verify they fail**

```bash
cd cdk/python
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements-dev.txt
pytest
```

Expected: FAIL with `ModuleNotFoundError: No module named 'ent_deploy_role.ent_deploy_role_stack'` (or similar — the package file exists but the stack module does not).

- [ ] **Step 9: Create `cdk/python/ent_deploy_role/ent_deploy_role_stack.py`**

```python
import json
import os
from pathlib import Path
from typing import Mapping, Optional

import aws_cdk as cdk
from aws_cdk import aws_iam as iam
from constructs import Construct

_DEFAULTS = {
    "ent_aws_account_arn": "arn:aws:iam::051759900972:role/prod-uswest1-eks-pi-1-20251203221124633900000005",
    "role_name": "HomeProdAssumeAdmin",
    "role_path": "/",
    "role_description": "Role that allows Ent Home to assume AdministratorAccess role",
    "policy_name": "EntHomeAccess",
    "policy_description": (
        "Custom policy for permissions needed by Ent Home to deploy and manage "
        "resources in customer accounts. This policy is attached to the role that "
        "Ent Home assumes when deploying resources in customer accounts."
    ),
}


class EntDeployRoleStack(cdk.Stack):
    def __init__(
        self,
        scope: Construct,
        construct_id: str,
        *,
        ent_aws_account_arn: Optional[str] = None,
        role_name: Optional[str] = None,
        role_path: Optional[str] = None,
        role_description: Optional[str] = None,
        ent_tags: Optional[Mapping[str, str]] = None,
        **kwargs,
    ) -> None:
        super().__init__(scope, construct_id, **kwargs)

        ent_aws_account_arn = ent_aws_account_arn or _DEFAULTS["ent_aws_account_arn"]
        role_name = role_name or _DEFAULTS["role_name"]
        role_path = role_path or _DEFAULTS["role_path"]
        role_description = role_description or _DEFAULTS["role_description"]

        # Resolve repo root: cdk/python/ent_deploy_role/ -> cdk/python/ -> cdk/ -> repo root
        repo_root = Path(__file__).resolve().parents[3]
        policy_json = json.loads((repo_root / "policy.json").read_text())
        trust_raw = (repo_root / "role.json").read_text()
        trust_json = json.loads(trust_raw.replace("<ENT_AWS_ACCOUNT_ARN>", ent_aws_account_arn))
        # Note: Python str.replace replaces all occurrences by default (no count arg)

        managed_policy = iam.CfnManagedPolicy(
            self,
            "EntHomeAccessPolicy",
            managed_policy_name=_DEFAULTS["policy_name"],
            description=_DEFAULTS["policy_description"],
            path="/",
            policy_document=policy_json,
        )

        tags = (
            [{"key": k, "value": v} for k, v in ent_tags.items()]
            if ent_tags
            else None
        )

        role = iam.CfnRole(
            self,
            "EntDeployRole",
            role_name=role_name,
            path=role_path,
            description=role_description,
            assume_role_policy_document=trust_json,
            managed_policy_arns=[managed_policy.ref],
            tags=tags,
        )

        self.role_arn = role.attr_arn
        self.role_name_out = role.ref
        self.policy_arn = managed_policy.ref

        cdk.CfnOutput(self, "RoleArn", value=self.role_arn)
        cdk.CfnOutput(self, "RoleName", value=self.role_name_out)
        cdk.CfnOutput(self, "PolicyArn", value=self.policy_arn)
```

- [ ] **Step 10: Create `cdk/python/app.py`**

```python
#!/usr/bin/env python3
import aws_cdk as cdk

from ent_deploy_role.ent_deploy_role_stack import EntDeployRoleStack

app = cdk.App()

tags_ctx = app.node.try_get_context("tags")
if tags_ctx is not None and not isinstance(tags_ctx, dict):
    tags_ctx = None

EntDeployRoleStack(
    app,
    "EntDeployRoleStack",
    ent_aws_account_arn=app.node.try_get_context("ent_aws_account_arn"),
    role_name=app.node.try_get_context("role_name"),
    role_path=app.node.try_get_context("role_path"),
    role_description=app.node.try_get_context("role_description"),
    ent_tags=tags_ctx,
)

app.synth()
```

- [ ] **Step 11: Run tests to verify they pass**

```bash
cd cdk/python
source .venv/bin/activate
pytest
```

Expected: 4 tests PASS.

- [ ] **Step 12: Verify `cdk synth` runs without error**

```bash
cd cdk/python
source .venv/bin/activate
npx cdk synth > /dev/null
```

Expected: no errors.

- [ ] **Step 13: Create `cdk/python/README.md`**

````markdown
# Ent Deploy Role — AWS CDK (Python)

Deploys the Ent Home deployment role using AWS CDK v2 in Python.

## Prerequisites

- Python 3.9+
- AWS CDK CLI: `npm install -g aws-cdk`
- AWS credentials configured

## Install

```bash
cd cdk/python
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

## Configure

Pass configuration via `-c key=value` flags on the CDK CLI.

| Key | Description | Default |
|---|---|---|
| `ent_aws_account_arn` | Ent's AWS account ARN | `arn:aws:iam::051759900972:role/prod-uswest1-eks-pi-1-20251203221124633900000005` |
| `role_name` | IAM role name | `HomeProdAssumeAdmin` |
| `role_path` | IAM role path | `/` |
| `role_description` | IAM role description | (matches Terraform default) |

## Deploy

```bash
cdk bootstrap
cdk deploy \
  -c ent_aws_account_arn=arn:aws:iam::123456789012:root \
  -c role_name=HomeProdAssumeAdmin
```

After deploy, the `RoleArn` output is the ARN to paste into the Ent AWS connection panel.

## Destroy

```bash
cdk destroy
```

## Test

```bash
pip install -r requirements-dev.txt
pytest
```
````

- [ ] **Step 14: Commit**

```bash
git add cdk/python
git commit -m "Add CDK Python template for Ent deploy role"
```

---

## Task 4: Pulumi TypeScript app

**Files:**
- Create: `pulumi/typescript/Pulumi.yaml`
- Create: `pulumi/typescript/package.json`
- Create: `pulumi/typescript/tsconfig.json`
- Create: `pulumi/typescript/.gitignore`
- Create: `pulumi/typescript/index.ts`
- Create: `pulumi/typescript/tests/index.spec.ts`
- Create: `pulumi/typescript/README.md`

- [ ] **Step 1: Create `pulumi/typescript/Pulumi.yaml`**

```yaml
name: ent-deploy-role
description: Ent Home deployment role (Pulumi TypeScript)
runtime:
  name: nodejs
  options:
    packagemanager: npm
```

- [ ] **Step 2: Create `pulumi/typescript/package.json`**

```json
{
  "name": "pulumi-ent-deploy-role",
  "version": "0.1.0",
  "private": true,
  "main": "index.ts",
  "scripts": {
    "test": "mocha -r ts-node/register tests/**/*.spec.ts"
  },
  "devDependencies": {
    "@types/mocha": "^10.0.0",
    "@types/node": "^20.0.0",
    "mocha": "^10.2.0",
    "ts-node": "^10.9.0",
    "typescript": "^5.3.0"
  },
  "dependencies": {
    "@pulumi/aws": "^6.0.0",
    "@pulumi/pulumi": "^3.100.0"
  }
}
```

- [ ] **Step 3: Create `pulumi/typescript/tsconfig.json`**

```json
{
  "compilerOptions": {
    "strict": true,
    "outDir": "bin",
    "target": "es2021",
    "module": "commonjs",
    "moduleResolution": "node",
    "sourceMap": true,
    "experimentalDecorators": true,
    "pretty": true,
    "noFallthroughCasesInSwitch": true,
    "noImplicitReturns": true,
    "forceConsistentCasingInFileNames": true,
    "esModuleInterop": true,
    "resolveJsonModule": true
  },
  "files": ["index.ts", "tests/index.spec.ts"]
}
```

- [ ] **Step 4: Create `pulumi/typescript/.gitignore`**

```
node_modules
bin
*.tsbuildinfo
```

- [ ] **Step 5: Write the failing test — `pulumi/typescript/tests/index.spec.ts`**

```typescript
import * as assert from 'assert';
import * as pulumi from '@pulumi/pulumi';

pulumi.runtime.setMocks({
  newResource: (args: pulumi.runtime.MockResourceArgs) => ({
    id: `${args.name}_id`,
    state: { ...args.inputs, arn: `arn:aws:iam::123456789012:${args.type}/${args.name}` },
  }),
  call: (args: pulumi.runtime.MockCallArgs) => args.inputs,
});

describe('EntDeployRole (Pulumi TS)', () => {
  let infra: typeof import('../index');

  before(async () => {
    process.env.PULUMI_CONFIG = JSON.stringify({
      'ent-deploy-role:entAwsAccountArn': 'arn:aws:iam::123456789012:root',
    });
    infra = await import('../index');
  });

  it('creates a managed policy named EntHomeAccess', () =>
    new Promise<void>((resolve) => {
      pulumi.all([infra.policy.name]).apply(([name]) => {
        assert.strictEqual(name, 'EntHomeAccess');
        resolve();
      });
    }));

  it('creates a role named HomeProdAssumeAdmin by default', () =>
    new Promise<void>((resolve) => {
      pulumi.all([infra.role.name]).apply(([name]) => {
        assert.strictEqual(name, 'HomeProdAssumeAdmin');
        resolve();
      });
    }));

  it('substitutes the account ARN in the trust policy', () =>
    new Promise<void>((resolve) => {
      pulumi.all([infra.role.assumeRolePolicy]).apply(([policyStr]) => {
        assert.ok(
          policyStr && policyStr.includes('arn:aws:iam::123456789012:root'),
          `expected trust policy to contain configured ARN, got: ${policyStr}`,
        );
        resolve();
      });
    }));
});
```

- [ ] **Step 6: Run tests to verify they fail**

```bash
cd pulumi/typescript
npm install
npm test
```

Expected: FAIL with `Cannot find module '../index'`.

- [ ] **Step 7: Create `pulumi/typescript/index.ts`**

```typescript
import * as fs from 'fs';
import * as path from 'path';
import * as pulumi from '@pulumi/pulumi';
import * as aws from '@pulumi/aws';

const config = new pulumi.Config();

const entAwsAccountArn =
  config.get('entAwsAccountArn') ?? 'arn:aws:iam::051759900972:role/prod-uswest1-eks-pi-1-20251203221124633900000005';
const roleName = config.get('roleName') ?? 'HomeProdAssumeAdmin';
const rolePath = config.get('rolePath') ?? '/';
const roleDescription =
  config.get('roleDescription') ??
  'Role that allows Ent Home to assume AdministratorAccess role';
const tags = config.getObject<Record<string, string>>('tags') ?? {};

// Resolve repo root: pulumi/typescript/ -> pulumi/ -> repo root
const repoRoot = path.resolve(__dirname, '..', '..');
const policyJson = fs.readFileSync(path.join(repoRoot, 'policy.json'), 'utf-8');
const trustJson = fs
  .readFileSync(path.join(repoRoot, 'role.json'), 'utf-8')
  .replaceAll('<ENT_AWS_ACCOUNT_ARN>', entAwsAccountArn);

export const policy = new aws.iam.Policy('EntHomeAccess', {
  name: 'EntHomeAccess',
  description:
    'Custom policy for permissions needed by Ent Home to deploy and manage resources in customer accounts. This policy is attached to the role that Ent Home assumes when deploying resources in customer accounts.',
  path: '/',
  policy: policyJson,
});

export const role = new aws.iam.Role('EntDeployRole', {
  name: roleName,
  path: rolePath,
  description: roleDescription,
  assumeRolePolicy: trustJson,
  tags,
});

new aws.iam.RolePolicyAttachment('EntDeployRoleAttachment', {
  role: role.name,
  policyArn: policy.arn,
});

export const roleArn = role.arn;
export const policyArn = policy.arn;
```

- [ ] **Step 8: Run tests to verify they pass**

```bash
cd pulumi/typescript
npm test
```

Expected: 3 tests PASS.

- [ ] **Step 9: Create `pulumi/typescript/README.md`**

````markdown
# Ent Deploy Role — Pulumi (TypeScript)

Deploys the Ent Home deployment role using Pulumi in TypeScript.

## Prerequisites

- Node.js 18+
- Pulumi CLI: see https://www.pulumi.com/docs/install/
- AWS credentials configured

## Install

```bash
cd pulumi/typescript
npm install
pulumi stack init dev
```

## Configure

```bash
pulumi config set ent-deploy-role:entAwsAccountArn arn:aws:iam::123456789012:root
pulumi config set ent-deploy-role:roleName HomeProdAssumeAdmin
```

| Key | Description | Default |
|---|---|---|
| `entAwsAccountArn` | Ent's AWS account ARN | `arn:aws:iam::051759900972:role/prod-uswest1-eks-pi-1-20251203221124633900000005` |
| `roleName` | IAM role name | `HomeProdAssumeAdmin` |
| `rolePath` | IAM role path | `/` |
| `roleDescription` | IAM role description | (matches Terraform default) |
| `tags` | Map of tags (use `--path`) | `{}` |

## Deploy

```bash
pulumi up
```

The `roleArn` output is the ARN to paste into the Ent AWS connection panel.

## Destroy

```bash
pulumi destroy
```

## Test

```bash
npm test
```
````

- [ ] **Step 10: Commit**

```bash
git add pulumi/typescript
git commit -m "Add Pulumi TypeScript template for Ent deploy role"
```

---

## Task 5: Pulumi Python app

**Files:**
- Create: `pulumi/python/Pulumi.yaml`
- Create: `pulumi/python/requirements.txt`
- Create: `pulumi/python/requirements-dev.txt`
- Create: `pulumi/python/.gitignore`
- Create: `pulumi/python/__main__.py`
- Create: `pulumi/python/ent_deploy_role_infra.py`
- Create: `pulumi/python/tests/__init__.py`
- Create: `pulumi/python/tests/test_infra.py`
- Create: `pulumi/python/README.md`

- [ ] **Step 1: Create `pulumi/python/Pulumi.yaml`**

```yaml
name: ent-deploy-role
description: Ent Home deployment role (Pulumi Python)
runtime:
  name: python
  options:
    virtualenv: venv
```

- [ ] **Step 2: Create `pulumi/python/requirements.txt`**

```
pulumi>=3.100.0,<4.0.0
pulumi-aws>=6.0.0,<7.0.0
```

- [ ] **Step 3: Create `pulumi/python/requirements-dev.txt`**

```
-r requirements.txt
pytest>=7.4.0
```

- [ ] **Step 4: Create `pulumi/python/.gitignore`**

```
venv
.venv
__pycache__
*.egg-info
.pytest_cache
```

- [ ] **Step 5: Create `pulumi/python/tests/__init__.py`**

Empty file.

- [ ] **Step 6: Write the failing test — `pulumi/python/tests/test_infra.py`**

```python
import os
import sys
import unittest

import pulumi


class EntDeployRoleMocks(pulumi.runtime.Mocks):
    def new_resource(self, args: pulumi.runtime.MockResourceArgs):
        outputs = dict(args.inputs)
        outputs["arn"] = f"arn:aws:iam::123456789012:{args.typ}/{args.name}"
        return [f"{args.name}_id", outputs]

    def call(self, args: pulumi.runtime.MockCallArgs):
        return {}


pulumi.runtime.set_mocks(EntDeployRoleMocks())

os.environ["PULUMI_CONFIG"] = (
    '{"ent-deploy-role:entAwsAccountArn": "arn:aws:iam::123456789012:root"}'
)

# Add parent directory to path so we can import ent_deploy_role_infra
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

import ent_deploy_role_infra as infra  # noqa: E402  (import after mocks + config)


class TestEntDeployRole(unittest.TestCase):
    @pulumi.runtime.test
    def test_policy_name(self):
        def check(name):
            self.assertEqual(name, "EntHomeAccess")

        return infra.policy.name.apply(check)

    @pulumi.runtime.test
    def test_role_default_name(self):
        def check(name):
            self.assertEqual(name, "HomeProdAssumeAdmin")

        return infra.role.name.apply(check)

    @pulumi.runtime.test
    def test_trust_policy_substitutes_arn(self):
        def check(policy_str):
            self.assertIn("arn:aws:iam::123456789012:root", policy_str)

        return infra.role.assume_role_policy.apply(check)
```

- [ ] **Step 7: Run tests to verify they fail**

```bash
cd pulumi/python
python3 -m venv venv
source venv/bin/activate
pip install -r requirements-dev.txt
pytest
```

Expected: FAIL with `ModuleNotFoundError: No module named 'ent_deploy_role_infra'`.

- [ ] **Step 8: Create `pulumi/python/ent_deploy_role_infra.py`**

```python
from pathlib import Path

import pulumi
import pulumi_aws as aws

config = pulumi.Config()

ent_aws_account_arn = config.get("entAwsAccountArn") or "arn:aws:iam::051759900972:role/prod-uswest1-eks-pi-1-20251203221124633900000005"
role_name = config.get("roleName") or "HomeProdAssumeAdmin"
role_path = config.get("rolePath") or "/"
role_description = (
    config.get("roleDescription")
    or "Role that allows Ent Home to assume AdministratorAccess role"
)
tags = config.get_object("tags") or {}

# Resolve repo root: pulumi/python/ent_deploy_role_infra.py -> pulumi/python/ -> pulumi/ -> repo root
repo_root = Path(__file__).resolve().parents[2]
policy_json = (repo_root / "policy.json").read_text()
trust_json = (repo_root / "role.json").read_text().replace(
    "<ENT_AWS_ACCOUNT_ARN>", ent_aws_account_arn
)

policy = aws.iam.Policy(
    "EntHomeAccess",
    name="EntHomeAccess",
    description=(
        "Custom policy for permissions needed by Ent Home to deploy and manage "
        "resources in customer accounts. This policy is attached to the role that "
        "Ent Home assumes when deploying resources in customer accounts."
    ),
    path="/",
    policy=policy_json,
)

role = aws.iam.Role(
    "EntDeployRole",
    name=role_name,
    path=role_path,
    description=role_description,
    assume_role_policy=trust_json,
    tags=tags,
)

aws.iam.RolePolicyAttachment(
    "EntDeployRoleAttachment",
    role=role.name,
    policy_arn=policy.arn,
)

pulumi.export("roleArn", role.arn)
pulumi.export("roleName", role.name)
pulumi.export("policyArn", policy.arn)
```

- [ ] **Step 8b: Create `pulumi/python/__main__.py`**

Pulumi's Python runtime runs the file named `__main__.py`. Keep it as a thin wrapper so the resource-creation code is importable by tests.

```python
import ent_deploy_role_infra  # noqa: F401  (import triggers resource creation)
```

- [ ] **Step 9: Run tests to verify they pass**

```bash
cd pulumi/python
source venv/bin/activate
pytest
```

Expected: 3 tests PASS.

- [ ] **Step 10: Create `pulumi/python/README.md`**

````markdown
# Ent Deploy Role — Pulumi (Python)

Deploys the Ent Home deployment role using Pulumi in Python.

## Prerequisites

- Python 3.9+
- Pulumi CLI: see https://www.pulumi.com/docs/install/
- AWS credentials configured

## Install

```bash
cd pulumi/python
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
pulumi stack init dev
```

## Configure

```bash
pulumi config set ent-deploy-role:entAwsAccountArn arn:aws:iam::123456789012:root
pulumi config set ent-deploy-role:roleName HomeProdAssumeAdmin
```

| Key | Description | Default |
|---|---|---|
| `entAwsAccountArn` | Ent's AWS account ARN | `arn:aws:iam::051759900972:role/prod-uswest1-eks-pi-1-20251203221124633900000005` |
| `roleName` | IAM role name | `HomeProdAssumeAdmin` |
| `rolePath` | IAM role path | `/` |
| `roleDescription` | IAM role description | (matches Terraform default) |
| `tags` | Map of tags (use `--path`) | `{}` |

## Deploy

```bash
pulumi up
```

The `roleArn` output is the ARN to paste into the Ent AWS connection panel.

## Destroy

```bash
pulumi destroy
```

## Test

```bash
pip install -r requirements-dev.txt
pytest
```
````

- [ ] **Step 11: Commit**

```bash
git add pulumi/python
git commit -m "Add Pulumi Python template for Ent deploy role"
```

---

## Task 6: Pulumi Go app

**Files:**
- Create: `pulumi/go/Pulumi.yaml`
- Create: `pulumi/go/go.mod`
- Create: `pulumi/go/.gitignore`
- Create: `pulumi/go/main.go`
- Create: `pulumi/go/main_test.go`
- Create: `pulumi/go/README.md`

- [ ] **Step 1: Create `pulumi/go/Pulumi.yaml`**

```yaml
name: ent-deploy-role
description: Ent Home deployment role (Pulumi Go)
runtime: go
```

- [ ] **Step 2: Create `pulumi/go/go.mod`**

```
module github.com/ent-security/aws-ent-deploy-role/pulumi/go

go 1.21

require (
	github.com/pulumi/pulumi-aws/sdk/v6 v6.0.0
	github.com/pulumi/pulumi/sdk/v3 v3.100.0
)
```

(Exact versions will be pinned by `go mod tidy` in step 3.)

- [ ] **Step 3: Create `pulumi/go/.gitignore`**

```
bin
*.test
vendor
```

- [ ] **Step 4: Write the failing test — `pulumi/go/main_test.go`**

```go
package main

import (
	"encoding/json"
	"strings"
	"sync"
	"testing"

	"github.com/pulumi/pulumi/sdk/v3/go/pulumi"
	"github.com/stretchr/testify/assert"
)

type mocks int

func (mocks) NewResource(args pulumi.MockResourceArgs) (string, map[string]interface{}, error) {
	outputs := args.Inputs.Mappable()
	outputs["arn"] = "arn:aws:iam::123456789012:" + args.TypeToken + "/" + args.Name
	return args.Name + "_id", outputs, nil
}

func (mocks) Call(args pulumi.MockCallArgs) (map[string]interface{}, error) {
	return args.Args.Mappable(), nil
}

func TestEntDeployRole(t *testing.T) {
	err := pulumi.RunErr(func(ctx *pulumi.Context) error {
		cfg := map[string]string{
			"ent-deploy-role:entAwsAccountArn": "arn:aws:iam::123456789012:root",
		}
		cfgJSON, _ := json.Marshal(cfg)
		ctx.Log.Debug("config: "+string(cfgJSON), nil)

		resources, err := deploy(ctx, "arn:aws:iam::123456789012:root", "HomeProdAssumeAdmin", "/", "desc", map[string]string{})
		if err != nil {
			return err
		}

		var wg sync.WaitGroup
		wg.Add(3)

		pulumi.All(resources.Policy.Name).ApplyT(func(v []interface{}) error {
			defer wg.Done()
			assert.Equal(t, "EntHomeAccess", v[0].(string))
			return nil
		})

		pulumi.All(resources.Role.Name).ApplyT(func(v []interface{}) error {
			defer wg.Done()
			assert.Equal(t, "HomeProdAssumeAdmin", v[0].(string))
			return nil
		})

		pulumi.All(resources.Role.AssumeRolePolicy).ApplyT(func(v []interface{}) error {
			defer wg.Done()
			assert.True(t, strings.Contains(v[0].(string), "arn:aws:iam::123456789012:root"))
			return nil
		})

		wg.Wait()
		return nil
	}, pulumi.WithMocks("project", "stack", mocks(0)))

	assert.NoError(t, err)
}
```

Also add `github.com/stretchr/testify v1.9.0` to `go.mod` require block (will be resolved by `go mod tidy`).

- [ ] **Step 5: Run the test to verify it fails**

```bash
cd pulumi/go
go mod tidy
go test ./...
```

Expected: FAIL with `undefined: deploy` or compile error (main.go does not yet expose `deploy`).

- [ ] **Step 6: Create `pulumi/go/main.go`**

```go
package main

import (
	"os"
	"path/filepath"
	"strings"

	"github.com/pulumi/pulumi-aws/sdk/v6/go/aws/iam"
	"github.com/pulumi/pulumi/sdk/v3/go/pulumi"
	"github.com/pulumi/pulumi/sdk/v3/go/pulumi/config"
)

type deployed struct {
	Policy *iam.Policy
	Role   *iam.Role
}

const (
	defaultEntAwsAccountArn = "arn:aws:iam::051759900972:role/prod-uswest1-eks-pi-1-20251203221124633900000005"
	defaultRoleName         = "HomeProdAssumeAdmin"
	defaultRolePath         = "/"
	defaultRoleDescription  = "Role that allows Ent Home to assume AdministratorAccess role"
	policyName              = "EntHomeAccess"
	policyDescription       = "Custom policy for permissions needed by Ent Home to deploy and manage resources in customer accounts. This policy is attached to the role that Ent Home assumes when deploying resources in customer accounts."
)

func readRepoFile(name string) (string, error) {
	// Resolve repo root: pulumi/go/ -> pulumi/ -> repo root
	exe, err := os.Getwd()
	if err != nil {
		return "", err
	}
	repoRoot := filepath.Join(exe, "..", "..")
	data, err := os.ReadFile(filepath.Join(repoRoot, name))
	if err != nil {
		return "", err
	}
	return string(data), nil
}

func deploy(
	ctx *pulumi.Context,
	entAwsAccountArn string,
	roleName string,
	rolePath string,
	roleDescription string,
	tags map[string]string,
) (*deployed, error) {
	policyJSON, err := readRepoFile("policy.json")
	if err != nil {
		return nil, err
	}
	trustRaw, err := readRepoFile("role.json")
	if err != nil {
		return nil, err
	}
	trustJSON := strings.ReplaceAll(trustRaw, "<ENT_AWS_ACCOUNT_ARN>", entAwsAccountArn)

	policy, err := iam.NewPolicy(ctx, "EntHomeAccess", &iam.PolicyArgs{
		Name:        pulumi.String(policyName),
		Description: pulumi.String(policyDescription),
		Path:        pulumi.String("/"),
		Policy:      pulumi.String(policyJSON),
	})
	if err != nil {
		return nil, err
	}

	pulumiTags := pulumi.StringMap{}
	for k, v := range tags {
		pulumiTags[k] = pulumi.String(v)
	}

	role, err := iam.NewRole(ctx, "EntDeployRole", &iam.RoleArgs{
		Name:             pulumi.String(roleName),
		Path:             pulumi.String(rolePath),
		Description:      pulumi.String(roleDescription),
		AssumeRolePolicy: pulumi.String(trustJSON),
		Tags:             pulumiTags,
	})
	if err != nil {
		return nil, err
	}

	_, err = iam.NewRolePolicyAttachment(ctx, "EntDeployRoleAttachment", &iam.RolePolicyAttachmentArgs{
		Role:      role.Name,
		PolicyArn: policy.Arn,
	})
	if err != nil {
		return nil, err
	}

	return &deployed{Policy: policy, Role: role}, nil
}

func main() {
	pulumi.Run(func(ctx *pulumi.Context) error {
		cfg := config.New(ctx, "ent-deploy-role")

		entAwsAccountArn := cfg.Get("entAwsAccountArn")
		if entAwsAccountArn == "" {
			entAwsAccountArn = defaultEntAwsAccountArn
		}
		roleName := cfg.Get("roleName")
		if roleName == "" {
			roleName = defaultRoleName
		}
		rolePath := cfg.Get("rolePath")
		if rolePath == "" {
			rolePath = defaultRolePath
		}
		roleDescription := cfg.Get("roleDescription")
		if roleDescription == "" {
			roleDescription = defaultRoleDescription
		}
		tags := map[string]string{}
		_ = cfg.TryObject("tags", &tags)

		result, err := deploy(ctx, entAwsAccountArn, roleName, rolePath, roleDescription, tags)
		if err != nil {
			return err
		}

		ctx.Export("roleArn", result.Role.Arn)
		ctx.Export("roleName", result.Role.Name)
		ctx.Export("policyArn", result.Policy.Arn)
		return nil
	})
}
```

- [ ] **Step 7: Run the test to verify it passes**

```bash
cd pulumi/go
go mod tidy
go test ./...
```

Expected: PASS.

- [ ] **Step 8: Create `pulumi/go/README.md`**

````markdown
# Ent Deploy Role — Pulumi (Go)

Deploys the Ent Home deployment role using Pulumi in Go.

## Prerequisites

- Go 1.21+
- Pulumi CLI: see https://www.pulumi.com/docs/install/
- AWS credentials configured

## Install

```bash
cd pulumi/go
go mod tidy
pulumi stack init dev
```

## Configure

```bash
pulumi config set ent-deploy-role:entAwsAccountArn arn:aws:iam::123456789012:root
pulumi config set ent-deploy-role:roleName HomeProdAssumeAdmin
```

| Key | Description | Default |
|---|---|---|
| `entAwsAccountArn` | Ent's AWS account ARN | `arn:aws:iam::051759900972:role/prod-uswest1-eks-pi-1-20251203221124633900000005` |
| `roleName` | IAM role name | `HomeProdAssumeAdmin` |
| `rolePath` | IAM role path | `/` |
| `roleDescription` | IAM role description | (matches Terraform default) |
| `tags` | Map of tags (use `--path`) | `{}` |

## Deploy

```bash
pulumi up
```

The `roleArn` output is the ARN to paste into the Ent AWS connection panel.

## Destroy

```bash
pulumi destroy
```

## Test

```bash
go test ./...
```
````

- [ ] **Step 9: Commit**

```bash
git add pulumi/go
git commit -m "Add Pulumi Go template for Ent deploy role"
```

---

## Task 7: Top-level README — CDK Usage section

**Files:**
- Modify: `README.md` (add new "CDK Usage" section after the CloudFormation Usage section)

- [ ] **Step 1: Add a new "## CDK Usage" section immediately after the CloudFormation Outputs table and immediately before `## AWS CLI Usage`**

Insert the following block:

````markdown
## CDK Usage

This repository ships standalone CDK v2 apps in TypeScript and Python. Both read the authoritative `policy.json` and `role.json` at synthesis time.

### CDK TypeScript

```bash
cd cdk/typescript
npm install
npx cdk bootstrap   # one-time per account/region
npx cdk deploy \
  -c ent_aws_account_arn=arn:aws:iam::123456789012:root \
  -c role_name=HomeProdAssumeAdmin
```

See [`cdk/typescript/README.md`](./cdk/typescript/README.md) for full usage.

### CDK Python

```bash
cd cdk/python
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
cdk bootstrap
cdk deploy \
  -c ent_aws_account_arn=arn:aws:iam::123456789012:root \
  -c role_name=HomeProdAssumeAdmin
```

See [`cdk/python/README.md`](./cdk/python/README.md) for full usage.

### CDK Configuration

| Key | Description | Default |
|---|---|---|
| `ent_aws_account_arn` | Ent's AWS account ARN | `arn:aws:iam::051759900972:role/prod-uswest1-eks-pi-1-20251203221124633900000005` |
| `role_name` | IAM role name | `HomeProdAssumeAdmin` |
| `role_path` | IAM role path | `/` |
| `role_description` | IAM role description | (matches Terraform default) |

### CDK Outputs

| Output | Description |
|---|---|
| `RoleArn` | The ARN of the role |
| `RoleName` | The name of the role |
| `PolicyArn` | The ARN of the policy |
````

- [ ] **Step 2: Commit**

```bash
git add README.md
git commit -m "Document CDK usage in top-level README"
```

---

## Task 8: Top-level README — Pulumi Usage section

**Files:**
- Modify: `README.md` (add new "Pulumi Usage" section after "CDK Usage")

- [ ] **Step 1: Add a new "## Pulumi Usage" section immediately after the CDK Outputs table and immediately before `## AWS CLI Usage`**

Insert the following block:

````markdown
## Pulumi Usage

This repository ships standalone Pulumi programs in TypeScript, Python, and Go. All three read the authoritative `policy.json` and `role.json` at deploy time.

### Pulumi TypeScript

```bash
cd pulumi/typescript
npm install
pulumi stack init dev
pulumi config set ent-deploy-role:entAwsAccountArn arn:aws:iam::123456789012:root
pulumi up
```

See [`pulumi/typescript/README.md`](./pulumi/typescript/README.md) for full usage.

### Pulumi Python

```bash
cd pulumi/python
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
pulumi stack init dev
pulumi config set ent-deploy-role:entAwsAccountArn arn:aws:iam::123456789012:root
pulumi up
```

See [`pulumi/python/README.md`](./pulumi/python/README.md) for full usage.

### Pulumi Go

```bash
cd pulumi/go
go mod tidy
pulumi stack init dev
pulumi config set ent-deploy-role:entAwsAccountArn arn:aws:iam::123456789012:root
pulumi up
```

See [`pulumi/go/README.md`](./pulumi/go/README.md) for full usage.

### Pulumi Configuration

| Key | Description | Default |
|---|---|---|
| `entAwsAccountArn` | Ent's AWS account ARN | `arn:aws:iam::051759900972:role/prod-uswest1-eks-pi-1-20251203221124633900000005` |
| `roleName` | IAM role name | `HomeProdAssumeAdmin` |
| `rolePath` | IAM role path | `/` |
| `roleDescription` | IAM role description | (matches Terraform default) |
| `tags` | Map of tags (set with `--path`) | `{}` |

### Pulumi Outputs

| Output | Description |
|---|---|
| `roleArn` | The ARN of the role |
| `roleName` | The name of the role |
| `policyArn` | The ARN of the policy |
````

- [ ] **Step 2: Commit**

```bash
git add README.md
git commit -m "Document Pulumi usage in top-level README"
```

---

## Task 9: Top-level README — opening line, directory structure, Setup flows

**Files:**
- Modify: `README.md` line 3 (opening line)
- Modify: `README.md` directory-structure block (~lines 167–179)
- Modify: `README.md` `## Setup` section (~line 142)

- [ ] **Step 1: Update the opening line**

Replace:
```markdown
Infrastructure as Code to create the Ent Security Deployment Role in AWS. Supports both Terraform and CloudFormation.
```

With:
```markdown
Infrastructure as Code to create the Ent Security Deployment Role in AWS. Supports Terraform (including OpenTofu), CloudFormation, AWS CDK (TypeScript and Python), and Pulumi (TypeScript, Python, and Go).
```

- [ ] **Step 2: Update the directory-structure block**

Replace:
```markdown
aws-ent-deploy-role/
├── cloudformation/
│   └── template.yaml
├── terraform/
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   └── versions.tf
├── role.json
├── policy.json
└── README.md
```

With:
```markdown
aws-ent-deploy-role/
├── cdk/
│   ├── typescript/
│   └── python/
├── cloudformation/
│   └── template.yaml
├── pulumi/
│   ├── typescript/
│   ├── python/
│   └── go/
├── terraform/
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   └── versions.tf
├── role.json
├── policy.json
└── README.md
```

- [ ] **Step 3: Add CDK and Pulumi flows to the `## Setup` section**

Immediately after the existing `### CloudFormation` steps list (5 steps ending with "Click the `Save & Test Connection` button"), insert:

```markdown
### CDK

1. Open the AWS connection settings page in Ent
2. Pick a CDK variant (TypeScript or Python) and follow its README to install prerequisites
3. Run `cdk deploy -c ent_aws_account_arn=<your-arn> -c role_name=<name>`
4. Copy the `RoleArn` stack output
5. Paste the Role ARN into the Role ARN field in the AWS Connections drawer in Ent
6. Click the `Save & Test Connection` button

### Pulumi

1. Open the AWS connection settings page in Ent
2. Pick a Pulumi variant (TypeScript, Python, or Go) and follow its README to install prerequisites
3. Run `pulumi config set ent-deploy-role:entAwsAccountArn <your-arn>` then `pulumi up`
4. Copy the `roleArn` stack output
5. Paste the Role ARN into the Role ARN field in the AWS Connections drawer in Ent
6. Click the `Save & Test Connection` button
```

- [ ] **Step 4: Commit**

```bash
git add README.md
git commit -m "Update README opening, directory tree, and Setup for CDK/Pulumi"
```

---

## Verification (final pass)

- [ ] **Run every test suite from the repo root:**

```bash
(cd cdk/typescript && npm test) && \
(cd cdk/python && source .venv/bin/activate && pytest) && \
(cd pulumi/typescript && npm test) && \
(cd pulumi/python && source venv/bin/activate && pytest) && \
(cd pulumi/go && go test ./...)
```

Expected: all PASS.

- [ ] **Synthesize/preview each template to confirm it can produce output:**

```bash
(cd cdk/typescript && npx cdk synth > /dev/null)
(cd cdk/python && source .venv/bin/activate && cdk synth > /dev/null)
# pulumi preview requires a stack and AWS creds — manual step
```

- [ ] **Skim the final top-level README for flow and broken links.**

- [ ] **Open a PR against `main`.** The PR description should summarize: new CDK + Pulumi templates (2 CDK + 3 Pulumi), README updates including first-class OpenTofu note, and that the `policy.json` / `role.json` source-of-truth contract is preserved.
