import json

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


def test_creates_four_functional_managed_policies():
    template = _template()
    # Four functional managed policies (all attached to the role) plus the boundary policy.
    template.resource_count_is("AWS::IAM::ManagedPolicy", 5)
    for name in (
        "EntHomeAccessCompute",
        "EntHomeAccessData",
        "EntHomeAccessSecurity",
        "EntHomeAccessPlatform",
        "EntHomeAccessBoundary",
    ):
        template.has_resource_properties(
            "AWS::IAM::ManagedPolicy",
            {"ManagedPolicyName": name},
        )


def test_boundary_policy_not_attached_to_role():
    template = _template()
    # The boundary policy caps roles the deploy role creates -- it must not be
    # attached to the deploy role itself, or it would strip the deploy role's
    # own iam:*/sts:AssumeRole grants.
    (role,) = template.find_resources("AWS::IAM::Role").values()
    assert len(role["Properties"]["ManagedPolicyArns"]) == 4


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


def test_parameterizes_arns_by_partition():
    template = _template()
    template_json = json.dumps(template.to_json())
    # Permission-policy ARNs must resolve the partition via the AWS::Partition
    # pseudo-param rather than hardcoding the commercial `aws` partition.
    assert "AWS::Partition" in template_json
    assert "arn:aws:athena" not in template_json


def test_guards_attached_when_enabled():
    template = _template(
        permissions_boundary_arn="arn:aws:iam::123456789012:policy/CustomerWorkloadBoundary",
        owner_tag_key="Owner Role",
        owner_tag_value="ent",
    )
    # Four functional + Ent's default boundary + two guards; only the boundary stays unattached.
    template.resource_count_is("AWS::IAM::ManagedPolicy", 7)
    (role,) = template.find_resources("AWS::IAM::Role").values()
    assert len(role["Properties"]["ManagedPolicyArns"]) == 6

    guards = {
        p["Properties"]["ManagedPolicyName"]: json.dumps(p["Properties"]["PolicyDocument"])
        for p in template.find_resources("AWS::IAM::ManagedPolicy").values()
        if p["Properties"]["ManagedPolicyName"].endswith("Guard")
    }
    assert "arn:aws:iam::123456789012:policy/CustomerWorkloadBoundary" in guards["EntHomeAccessBoundaryGuard"]
    assert "aws:RequestTag/Owner Role" in guards["EntHomeAccessOwnerTagGuard"]
    assert "<" not in "".join(guards.values()), "a placeholder was left unsubstituted"


def test_owner_tag_key_requires_value():
    import pytest

    with pytest.raises(ValueError):
        _template(owner_tag_key="Owner Role")
