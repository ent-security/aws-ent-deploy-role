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
