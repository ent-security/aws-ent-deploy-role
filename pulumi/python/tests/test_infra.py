import importlib.util
import os
import sys
import unittest

import pulumi


# Inputs of every resource registered with the mocks, by type, so tests can assert what was
# actually wired up (e.g. every RolePolicyAttachment) rather than only what the module exposes.
registered = {}


class EntDeployRoleMocks(pulumi.runtime.Mocks):
    def new_resource(self, args: pulumi.runtime.MockResourceArgs):
        registered.setdefault(args.typ, []).append(dict(args.inputs))
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


def attached_to(role_name):
    """Policy ARNs of every RolePolicyAttachment registered against the named role."""
    return [
        a["policyArn"]
        for a in registered.get("aws:iam/rolePolicyAttachment:RolePolicyAttachment", [])
        if a["role"] == role_name
    ]


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
    def test_boundary_not_attached_to_deploy_role(self):
        # A boundary on the deploy role itself would cap its own iam:*/sts:AssumeRole access. Assert
        # the role carries none and, with the guard off, its registered attachments are exactly the
        # four functional policies.
        def check(args):
            permissions_boundary, *functional_arns = args
            self.assertIsNone(permissions_boundary)
            self.assertEqual(sorted(attached_to("HomeProdAssumeAdmin")), sorted(functional_arns))

        return pulumi.Output.all(
            infra.role.permissions_boundary,
            *[p.arn for p in infra.policies.values()],
            # Wait for every attachment to register before reading `registered`.
            *[a.policy_arn for a in infra.attachments.values()],
        ).apply(lambda args: check(args[: 1 + len(infra.policies)]))

    @pulumi.runtime.test
    def test_policy_arns_rewritten_to_partition(self):
        # The S3 statement lives in the Data & Storage functional policy. Assert its ARNs are
        # rewritten to the deploy partition rather than left as the commercial `aws` partition.
        def check(policy_str):
            self.assertIn("arn:aws-us-gov:s3:::", policy_str)
            self.assertNotIn("arn:aws:s3:::", policy_str)

        return infra.policies["Data"].policy.apply(check)

    def test_guards_off_by_default(self):
        self.assertEqual(infra.guards, {})
        self.assertIsNone(infra.boundary_guard_policy("aws", ""))

    def test_boundary_guard_renders_fragment(self):
        import json

        rendered = infra.boundary_guard_policy(
            "aws-us-gov", "arn:aws-us-gov:iam::123456789012:policy/CustomerWorkloadBoundary"
        )
        enforcement = json.loads(rendered)["Statement"][0]
        self.assertEqual(enforcement["Resource"], "arn:aws-us-gov:iam::*:role/e???????????????-*")
        self.assertEqual(
            enforcement["Condition"]["StringNotEquals"]["iam:PermissionsBoundary"],
            "arn:aws-us-gov:iam::123456789012:policy/CustomerWorkloadBoundary",
        )
        self.assertNotIn("<", rendered)

    def test_rejects_non_policy_boundary_arn(self):
        with self.assertRaises(ValueError):
            infra.boundary_guard_policy("aws", "arn:aws:iam::123456789012:role/NotAPolicy")


BOUNDARY_ARN = "arn:aws:iam::123456789012:policy/CustomerWorkloadBoundary"


class TestEntDeployRoleGuardOn(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        # Config is read when the program loads, so load a second copy with the guard on. A distinct
        # role name keeps its attachments apart from the guard-off copy's in `registered`.
        pulumi.runtime.set_config("ent-deploy-role:permissionsBoundaryArn", BOUNDARY_ARN)
        pulumi.runtime.set_config("ent-deploy-role:roleName", "GuardedRole")
        spec = importlib.util.spec_from_file_location("ent_deploy_role_infra_guarded", infra.__file__)
        cls.guarded = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(cls.guarded)

    @pulumi.runtime.test
    def test_guard_created_attached_and_listed(self):
        guarded = self.guarded
        self.assertEqual(list(guarded.guards), ["BoundaryGuard"])
        guard = guarded.guards["BoundaryGuard"]
        n = len(guarded.policies)

        def check(args):
            guard_arn, guard_policy, *rest = args
            functional_arns, policy_arns = rest[:n], rest[n : 2 * n + 1]
            self.assertIn(BOUNDARY_ARN, guard_policy)
            self.assertEqual(policy_arns, functional_arns + [guard_arn])
            self.assertEqual(sorted(attached_to("GuardedRole")), sorted(functional_arns + [guard_arn]))

        return pulumi.Output.all(
            guard.arn,
            guard.policy,
            *[p.arn for p in guarded.policies.values()],
            *guarded.policy_arns,
            # Wait for every attachment to register before reading `registered`.
            *[a.policy_arn for a in guarded.attachments.values()],
        ).apply(check)
