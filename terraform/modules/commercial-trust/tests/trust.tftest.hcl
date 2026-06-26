# Trust-policy shape guard for the commercial assume-role trust.
#
# Regression test for the sts:TagSession / sts:ExternalId bug: the Home deploy identity authenticates
# via EKS Pod Identity, which attaches transitive session tags. STS forwards those tags onto the
# cross-account sts:AssumeRole, so the assume triggers an sts:TagSession authorization against this
# trust policy in addition to sts:AssumeRole. But sts:ExternalId is only populated in the request
# context when STS authorizes sts:AssumeRole — it is absent when STS authorizes sts:TagSession. So a
# StringEquals sts:ExternalId condition on a statement that also grants sts:TagSession evaluates
# against a missing key for the TagSession check -> implicit deny -> AccessDenied on sts:TagSession.
#
# The fix: when an ExternalId is configured, sts:AssumeRole keeps the ExternalId condition (confused-
# deputy protection) but sts:TagSession is split into its own statement WITHOUT the condition. When no
# ExternalId is configured, the trust stays a single combined statement (unchanged).
#
# Runs credential-free: the skip_* flags let the provider initialize without AWS credentials. The
# assume-role policy document is rendered locally at plan time, so no AWS access is needed.

provider "aws" {
  region                      = "us-east-1"
  access_key                  = "testonly"
  secret_key                  = "testonly"
  skip_credentials_validation = true
  skip_requesting_account_id  = true
  skip_metadata_api_check     = true
}

# With an ExternalId set, sts:TagSession must be split out from the ExternalId-gated statement.
run "external_id_splits_tagsession_out_from_condition" {
  command = plan

  variables {
    ent_aws_account_arn  = "arn:aws:iam::051759900972:role/prod-uswest1-eks-pi-1-20251203221124633900000005"
    role_sts_external_id = "test-external-id-123"
    policy_arn           = "arn:aws:iam::aws:policy/DummyForTest"
  }

  # The core assertion: with an ExternalId set, sts:TagSession appears in a statement that carries
  # NO condition. (flatten([s.Action]) normalizes the AWS provider's string-vs-list Action rendering.)
  assert {
    condition = anytrue([
      for s in jsondecode(output.assume_role_policy_json).Statement :
      contains(flatten([s.Action]), "sts:TagSession") && !can(s.Condition)
    ])
    error_message = "With an ExternalId set, sts:TagSession must appear in a statement WITHOUT any condition (STS does not populate sts:ExternalId when authorizing sts:TagSession)."
  }

  # Stronger form: NO statement that grants sts:TagSession may carry an sts:ExternalId condition.
  assert {
    condition = alltrue([
      for s in jsondecode(output.assume_role_policy_json).Statement :
      !(contains(flatten([s.Action]), "sts:TagSession") && try(s.Condition.StringEquals["sts:ExternalId"], null) != null)
    ])
    error_message = "sts:TagSession must never be gated behind sts:ExternalId."
  }

  # Confused-deputy protection preserved: sts:AssumeRole keeps the ExternalId StringEquals condition.
  assert {
    condition = anytrue([
      for s in jsondecode(output.assume_role_policy_json).Statement :
      contains(flatten([s.Action]), "sts:AssumeRole") && try(s.Condition.StringEquals["sts:ExternalId"], null) == "test-external-id-123"
    ])
    error_message = "sts:AssumeRole must keep the sts:ExternalId StringEquals condition (confused-deputy protection)."
  }
}

# With no ExternalId, the trust policy is a single combined statement with both actions and no
# condition (today's behavior — must remain unchanged).
run "no_external_id_keeps_single_combined_statement" {
  command = plan

  variables {
    ent_aws_account_arn  = "arn:aws:iam::051759900972:role/prod-uswest1-eks-pi-1-20251203221124633900000005"
    role_sts_external_id = ""
    policy_arn           = "arn:aws:iam::aws:policy/DummyForTest"
  }

  assert {
    condition     = length(jsondecode(output.assume_role_policy_json).Statement) == 1
    error_message = "With no ExternalId, the trust policy must remain a single statement."
  }

  assert {
    condition = alltrue([
      for s in jsondecode(output.assume_role_policy_json).Statement : !can(s.Condition)
    ])
    error_message = "With no ExternalId, the trust statement must carry no condition."
  }

  assert {
    condition = alltrue([
      for action in ["sts:AssumeRole", "sts:TagSession"] :
      contains(flatten([jsondecode(output.assume_role_policy_json).Statement[0].Action]), action)
    ])
    error_message = "With no ExternalId, the single statement must grant both sts:AssumeRole and sts:TagSession."
  }
}
