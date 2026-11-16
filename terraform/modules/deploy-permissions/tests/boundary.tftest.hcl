# Ent's default permissions-boundary policy (EntHomeAccessBoundary): its shape, and that it can never
# constrain or be tampered with by the deploy role itself. Whether a boundary is ENFORCED is the
# opt-in BoundaryGuard policy -- see guards.tftest.hcl.
#
# Runs credential-free: same pattern as zerodiff.tftest.hcl.

provider "aws" {
  region                      = "us-east-1"
  access_key                  = "testonly"
  secret_key                  = "testonly"
  skip_credentials_validation = true
  skip_requesting_account_id  = true
  skip_metadata_api_check     = true
}

run "boundary_policy_shape_and_isolation" {
  command = plan

  assert {
    condition     = jsondecode(output.boundary_policy_json).Version == "2012-10-17"
    error_message = "Boundary policy must be a valid IAM policy document."
  }

  # A role bound by EntHomeAccessBoundary must never regain iam:* -- otherwise it could re-create
  # another role under the glob (with no boundary check applying to IT, since the escalated role's
  # own identity policy is attacker-controlled) and continue escalating.
  assert {
    condition = anytrue([
      for s in jsondecode(output.boundary_policy_json).Statement :
      s.Sid == "BoundaryDenyIAM" && s.Effect == "Deny" && contains(flatten([s.Action]), "iam:*")
    ])
    error_message = "The boundary policy must Deny iam:* so a role bound by it can't create/attach further roles and continue escalating."
  }

  assert {
    condition = anytrue([
      for s in jsondecode(output.boundary_policy_json).Statement :
      s.Sid == "BoundaryDenySTSAssumeRole" && s.Effect == "Deny" && contains(flatten([s.Action]), "sts:AssumeRole")
    ])
    error_message = "The boundary policy must Deny sts:AssumeRole so a role bound by it can't pivot into another role."
  }

  # The boundary policy's own name must fall outside the e???????????????-* glob, otherwise the
  # unbounded IAMAccess statement (scoped to that glob) could modify or delete the boundary itself.
  assert {
    condition     = !can(regex("^e.{15}-", output.boundary_policy_name))
    error_message = "The boundary policy name must not match the e???????????????-* glob (IAMAccess grants iam:* over that glob and must never be able to tamper with the boundary policy that constrains it)."
  }

  # The boundary is a standalone resource, never attached to the deploy role itself (it would strip
  # the deploy role's own iam:*/sts:AssumeRole grants on the glob). Compared by name, not ARN --
  # aws_iam_policy.arn is a computed attribute, unknown at plan time; name is a direct argument.
  assert {
    condition     = !contains(output.policy_names, output.boundary_policy_name)
    error_message = "The boundary policy must not be one of the four policies attached to the deploy role (policy_names)."
  }
}
