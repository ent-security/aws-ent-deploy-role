# Opt-in privilege-escalation guard. Proves:
#   - off by default: no guard policy, so existing installs and the StackSet rollout see no change;
#   - the guard renders exactly EntHomeAccess.boundary-guard.json (the source the CDK and
#     Pulumi variants read), so the variants can't drift apart;
#   - the guard is appended after the four functional policies, so turning it on never re-keys the
#     trust modules' index-keyed attachments;
#   - bad input is rejected at plan time.
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

run "guards_off_by_default" {
  command = plan

  assert {
    condition     = output.boundary_guard_policy_json == null
    error_message = "No guard policy may exist unless permissions_boundary_arn is set."
  }

  assert {
    condition     = length(output.policy_arns) == 4
    error_message = "With the guard off the deploy role must get exactly the four functional policies."
  }
}

run "boundary_guard_matches_fragment" {
  command = plan

  variables {
    permissions_boundary_arn = "arn:aws:iam::123456789012:policy/CustomerWorkloadBoundary"
  }

  assert {
    condition = jsonencode(jsondecode(output.boundary_guard_policy_json)) == jsonencode(jsondecode(replace(
      file("${path.module}/../../../EntHomeAccess.boundary-guard.json"),
      "<PERMISSIONS_BOUNDARY_ARN>", "arn:aws:iam::123456789012:policy/CustomerWorkloadBoundary"
    )))
    error_message = "Rendered BoundaryGuard policy drifted from EntHomeAccess.boundary-guard.json. Update the module and the file in lockstep."
  }

  assert {
    condition     = length(output.policy_arns) == 5
    error_message = "permissions_boundary_arn must add exactly the BoundaryGuard policy."
  }
}

run "guard_appends_after_functional_policies" {
  command = plan

  variables {
    permissions_boundary_arn = "arn:aws:iam::123456789012:policy/CustomerWorkloadBoundary"
  }

  # The functional four keep their order and position; the guard only ever appends.
  assert {
    condition     = output.policy_names == ["EntHomeAccessCompute", "EntHomeAccessData", "EntHomeAccessSecurity", "EntHomeAccessPlatform"]
    error_message = "Turning the guard on must not change the four functional policies or their order."
  }
}

run "rejects_non_policy_boundary_arn" {
  command = plan

  variables {
    permissions_boundary_arn = "arn:aws:iam::123456789012:role/NotAPolicy"
  }

  expect_failures = [var.permissions_boundary_arn]
}
