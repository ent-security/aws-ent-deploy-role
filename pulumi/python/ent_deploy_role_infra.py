from pathlib import Path

import pulumi
import pulumi_aws as aws

config = pulumi.Config()

ent_aws_account_arn = config.get("entAwsAccountArn") or "arn:aws:iam::000000000000:root"
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
