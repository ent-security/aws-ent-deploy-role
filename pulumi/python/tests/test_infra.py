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


os.environ["PULUMI_CONFIG"] = (
    '{"ent-deploy-role:entAwsAccountArn": "arn:aws:iam::123456789012:root"}'
)

pulumi.runtime.set_mocks(
    EntDeployRoleMocks(),
    project="ent-deploy-role",
    stack="test",
    preview=False,
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
