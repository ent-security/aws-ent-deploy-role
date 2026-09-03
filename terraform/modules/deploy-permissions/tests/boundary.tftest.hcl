# Regression test for the IAM privilege-escalation gap: IAMAccess grants iam:* (including
# CreateRole/PutRolePolicy/AttachRolePolicy) on role/policy/instance-profile resources matching
# role/e???????????????-*, and STSAssumeRoleAccess grants sts:AssumeRole on the same role glob. IAM
# authorizes CreateRole/PutRolePolicy/AttachRolePolicy against the ROLE resource, not the policy
# document being attached, so without a boundary requirement the deploy role could create a role
# under the glob, attach an unbounded policy to it, then self-assume it for full privilege
# escalation using only permissions it already has.
#
# This test proves the fix: iam:CreateRole under the glob is denied unless the caller supplies the
# EntHomeAccessBoundary permissions boundary, and that boundary can never be changed or removed
# once set (explicit Deny beats the iam:* Allow, regardless of statement order).
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

run "create_role_denied_without_matching_boundary" {
  command = plan

  assert {
    condition = anytrue([
      for s in jsondecode(output.policy_json_by_group["identity-security"]).Statement :
      (
        s.Sid == "IAMBoundaryEnforcement" &&
        s.Effect == "Deny" &&
        contains(flatten([s.Action]), "iam:CreateRole") &&
        try(s.Condition.StringNotLike["iam:PermissionsBoundary"], null) == "arn:aws:iam::*:policy/EntHomeAccessBoundary"
      )
    ])
    error_message = "IAMBoundaryEnforcement must Deny iam:CreateRole under the role glob unless iam:PermissionsBoundary (StringNotLike, for the account-id wildcard) equals the EntHomeAccessBoundary ARN."
  }

  # The Deny's Resource must cover the same role glob STSAssumeRoleAccess grants sts:AssumeRole on
  # -- otherwise a role created outside the glob-but-still-assumable-by-this-role window would slip
  # through unenforced.
  assert {
    condition = anytrue([
      for s in jsondecode(output.policy_json_by_group["identity-security"]).Statement :
      s.Sid == "IAMBoundaryEnforcement" && contains(flatten([s.Resource]), "arn:aws:iam::*:role/e???????????????-*")
    ])
    error_message = "IAMBoundaryEnforcement must scope to the same role/e???????????????-* glob as STSAssumeRoleAccess."
  }
}

run "boundary_cannot_be_stripped_once_set" {
  command = plan

  assert {
    condition = anytrue([
      for s in jsondecode(output.policy_json_by_group["identity-security"]).Statement :
      (
        s.Sid == "IAMBoundaryProtection" &&
        s.Effect == "Deny" &&
        contains(flatten([s.Action]), "iam:PutRolePermissionsBoundary") &&
        contains(flatten([s.Action]), "iam:DeleteRolePermissionsBoundary") &&
        contains(flatten([s.Resource]), "arn:aws:iam::*:role/e???????????????-*") &&
        !can(s.Condition)
      )
    ])
    error_message = "IAMBoundaryProtection must unconditionally Deny iam:PutRolePermissionsBoundary and iam:DeleteRolePermissionsBoundary on the role glob -- any condition would give an escape hatch to strip the boundary."
  }
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
