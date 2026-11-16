# Opt-in privilege-escalation guards (PLA-6063). Proves:
#   - off by default: no guard policy, so existing installs and the StackSet rollout see no change;
#   - each guard renders exactly its EntHomeAccess.<guard>.json fragment (the source the CDK and
#     Pulumi variants read), so the variants can't drift apart;
#   - guards are appended after the four functional policies, so turning one on never re-keys the
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
    condition     = output.boundary_guard_policy_json == null && output.owner_tag_guard_policy_json == null
    error_message = "No guard policy may exist unless permissions_boundary_arn / owner_tag_key is set."
  }

  assert {
    condition     = length(output.policy_arns) == 4
    error_message = "With both guards off the deploy role must get exactly the four functional policies."
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
    condition     = length(output.policy_arns) == 5 && output.owner_tag_guard_policy_json == null
    error_message = "permissions_boundary_arn alone must add exactly the BoundaryGuard policy."
  }
}

run "owner_tag_guard_matches_fragment" {
  command = plan

  variables {
    owner_tag_key   = "Owner Role"
    owner_tag_value = "arn:aws:iam::123456789012:role/HomeProdAssumeAdmin"
  }

  assert {
    condition = jsonencode(jsondecode(output.owner_tag_guard_policy_json)) == jsonencode(jsondecode(replace(replace(
      file("${path.module}/../../../EntHomeAccess.owner-tag-guard.json"),
      "<OWNER_TAG_KEY>", "Owner Role"),
      "<OWNER_TAG_VALUE>", "arn:aws:iam::123456789012:role/HomeProdAssumeAdmin"
    )))
    error_message = "Rendered OwnerTagGuard policy drifted from EntHomeAccess.owner-tag-guard.json. Update the module and the file in lockstep."
  }

  assert {
    condition     = length(output.policy_arns) == 5 && output.boundary_guard_policy_json == null
    error_message = "owner_tag_key alone must add exactly the OwnerTagGuard policy."
  }
}

run "both_guards_append_after_functional_policies" {
  command = plan

  variables {
    permissions_boundary_arn = "arn:aws:iam::123456789012:policy/CustomerWorkloadBoundary"
    owner_tag_key            = "Owner Role"
    owner_tag_value          = "ent"
  }

  assert {
    condition     = length(output.policy_arns) == 6
    error_message = "Both guards on must give the four functional policies plus two guards."
  }

  # The functional four keep their order and position; guards only ever append.
  assert {
    condition     = output.policy_names == ["EntHomeAccessCompute", "EntHomeAccessData", "EntHomeAccessSecurity", "EntHomeAccessPlatform"]
    error_message = "Turning guards on must not change the four functional policies or their order."
  }
}

run "owner_tag_key_requires_value" {
  command = plan

  variables {
    owner_tag_key = "Owner Role"
  }

  expect_failures = [var.owner_tag_value]
}

run "rejects_non_policy_boundary_arn" {
  command = plan

  variables {
    permissions_boundary_arn = "arn:aws:iam::123456789012:role/NotAPolicy"
  }

  expect_failures = [var.permissions_boundary_arn]
}
