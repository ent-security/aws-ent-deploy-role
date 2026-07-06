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

POLICY_NAME_PREFIX = "EntHomeAccess"
POLICY_DESCRIPTION = (
    "Custom policy for permissions needed by Ent Home to deploy and manage "
    "resources in customer accounts. This policy is attached to the role that "
    "Ent Home assumes when deploying resources in customer accounts."
)

# The permission set is split across four functional managed policies so each stays under AWS's
# 6144-character managed-policy limit. Each entry is (authoritative file, name suffix); the policy
# is named f"{prefix}{suffix}" (EntHomeAccess{Compute,Data,Security,Platform}). The union of the
# four is the complete permission set. Keep this in lockstep with the Terraform
# statement_group map and the files.
POLICY_FILES = [
    ("EntHomeAccess.compute-network.json", "Compute"),
    ("EntHomeAccess.data-storage.json", "Data"),
    ("EntHomeAccess.identity-security.json", "Security"),
    ("EntHomeAccess.observability-platform.json", "Platform"),
]
# Suffix of the functional policy whose ARN backs the deprecated single-ARN `policyArn` export.
COMPAT_POLICY_SUFFIX = "Security"

# Resolve repo root: pulumi/python/ent_deploy_role_infra.py -> pulumi/python/ -> pulumi/ -> repo root
repo_root = Path(__file__).resolve().parents[2]
# The functional policy files hold the canonical (commercial) `arn:aws:` ARNs. Rewrite the
# partition to the one we're deploying into so the policies work in commercial and GovCloud
# (aws-us-gov) alike. Each file becomes its own managed policy, mirroring the Terraform module.
partition = aws.get_partition().partition
trust_json = (repo_root / "role.json").read_text().replace(
    "<ENT_AWS_ACCOUNT_ARN>", ent_aws_account_arn
)

policies = {}
for _filename, _suffix in POLICY_FILES:
    _policy_json = (repo_root / _filename).read_text().replace("arn:aws:", f"arn:{partition}:")
    policies[_suffix] = aws.iam.Policy(
        f"EntHomeAccess{_suffix}",
        name=f"{POLICY_NAME_PREFIX}{_suffix}",
        description=POLICY_DESCRIPTION,
        path="/",
        policy=_policy_json,
    )

role = aws.iam.Role(
    "EntDeployRole",
    name=role_name,
    path=role_path,
    description=role_description,
    assume_role_policy=trust_json,
    tags=tags,
)

# One attachment per functional policy.
for _filename, _suffix in POLICY_FILES:
    aws.iam.RolePolicyAttachment(
        f"EntDeployRoleAttachment{_suffix}",
        role=role.name,
        policy_arn=policies[_suffix].arn,
    )

pulumi.export("roleArn", role.arn)
pulumi.export("roleName", role.name)
pulumi.export("policyArns", [policies[suffix].arn for _, suffix in POLICY_FILES])
# Backward-compat single ARN: EntHomeAccessSecurity. Deprecated -- use policyArns.
pulumi.export("policyArn", policies[COMPAT_POLICY_SUFFIX].arn)
