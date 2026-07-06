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
        # aws.get_partition() — return a non-commercial partition so the test
        # proves the policy ARNs are rewritten dynamically rather than left `aws`.
        return {"partition": "aws-us-gov"}


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
    def test_four_functional_policy_names(self):
        # The permission set is split across four functional managed policies, all attached to the role.
        self.assertEqual(len(infra.policies), 4)

        def check(names):
            self.assertEqual(
                sorted(names),
                ["EntHomeAccessCompute", "EntHomeAccessData", "EntHomeAccessPlatform", "EntHomeAccessSecurity"],
            )

        return pulumi.Output.all(*[p.name for p in infra.policies.values()]).apply(check)

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

    @pulumi.runtime.test
    def test_policy_arns_rewritten_to_partition(self):
        # The S3 statement lives in the Data & Storage functional policy. Assert its ARNs are
        # rewritten to the deploy partition rather than left as the commercial `aws` partition.
        def check(policy_str):
            self.assertIn("arn:aws-us-gov:s3:::", policy_str)
            self.assertNotIn("arn:aws:s3:::", policy_str)

        return infra.policies["Data"].policy.apply(check)
