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
    permissions_boundary_arn=app.node.try_get_context("permissions_boundary_arn"),
    owner_tag_key=app.node.try_get_context("owner_tag_key"),
    owner_tag_value=app.node.try_get_context("owner_tag_value"),
)

app.synth()
