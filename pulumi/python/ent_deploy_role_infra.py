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
permissions_boundary_arn = config.get("permissionsBoundaryArn") or ""
owner_tag_key = config.get("ownerTagKey") or ""
owner_tag_value = config.get("ownerTagValue") or ""
if owner_tag_key and not owner_tag_value:
    raise ValueError("ownerTagValue is required when ownerTagKey is set")

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

# Ent's default permissions boundary: pass its ARN as permissionsBoundaryArn to enforce it. NOT
# attached to the deploy role itself below -- it would strip the deploy role's own
# iam:*/sts:AssumeRole grants on the glob, breaking it. No partition rewrite needed: its
# Action/Resource entries carry no ARNs.
boundary_policy = aws.iam.Policy(
    "EntHomeAccessBoundary",
    name=f"{POLICY_NAME_PREFIX}Boundary",
    description="Permissions boundary for IAM roles created by the deploy role under role/e???????????????-*. Not attached to the deploy role itself.",
    path="/",
    policy=(repo_root / "EntHomeAccess.boundary.json").read_text(),
)



def guard_policies(partition, boundary_arn, tag_key, tag_value):
    """Opt-in privilege-escalation guards (PLA-6063): {name suffix: policy JSON} for each guard whose
    input is set, rendered from its EntHomeAccess.<guard>.json fragment. Every role ent-platform
    creates falls under the e???????????????-* glob, so turn one on only once Ent Home sends the same
    boundary ARN / tag for the tenant. See the README."""
    specs = (
        (boundary_arn, "EntHomeAccess.boundary-guard.json", "BoundaryGuard",
         {"<PERMISSIONS_BOUNDARY_ARN>": boundary_arn}),
        (tag_key, "EntHomeAccess.owner-tag-guard.json", "OwnerTagGuard",
         {"<OWNER_TAG_KEY>": tag_key, "<OWNER_TAG_VALUE>": tag_value}),
    )
    guards = {}
    for enabled, filename, suffix, values in specs:
        if not enabled:
            continue
        raw = (repo_root / filename).read_text().replace("arn:aws:", f"arn:{partition}:")
        for placeholder, value in values.items():
            raw = raw.replace(placeholder, value)
        guards[suffix] = raw
    return guards


guards = {
    suffix: aws.iam.Policy(
        f"EntHomeAccess{suffix}",
        name=f"{POLICY_NAME_PREFIX}{suffix}",
        description=POLICY_DESCRIPTION,
        path="/",
        policy=policy_json,
    )
    for suffix, policy_json in guard_policies(
        partition, permissions_boundary_arn, owner_tag_key, owner_tag_value
    ).items()
}

role = aws.iam.Role(
    "EntDeployRole",
    name=role_name,
    path=role_path,
    description=role_description,
    assume_role_policy=trust_json,
    tags=tags,
)

# One attachment per functional policy.
attachments = {}
for _filename, _suffix in POLICY_FILES:
    attachments[_suffix] = aws.iam.RolePolicyAttachment(
        f"EntDeployRoleAttachment{_suffix}",
        role=role.name,
        policy_arn=policies[_suffix].arn,
    )
for _suffix, _guard in guards.items():
    attachments[_suffix] = aws.iam.RolePolicyAttachment(
        f"EntDeployRoleAttachment{_suffix}",
        role=role.name,
        policy_arn=_guard.arn,
    )

pulumi.export("roleArn", role.arn)
pulumi.export("roleName", role.name)
pulumi.export("policyArns", [policies[suffix].arn for _, suffix in POLICY_FILES])
# Backward-compat single ARN: EntHomeAccessSecurity. Deprecated -- use policyArns.
pulumi.export("policyArn", policies[COMPAT_POLICY_SUFFIX].arn)
pulumi.export("boundaryPolicyArn", boundary_policy.arn)
