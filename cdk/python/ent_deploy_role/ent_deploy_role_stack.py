import json
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
        # Python str.replace replaces all occurrences by default (no count arg)
        trust_json = json.loads(trust_raw.replace("<ENT_AWS_ACCOUNT_ARN>", ent_aws_account_arn))

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
