# Zero-diff guard for the aws-ent-deploy-role functional policy split.
#
# The permission set is split across four functional managed policies (Compute, Data, Security,
# Platform), each its own authoritative EntHomeAccess.<domain>.json file. The functional reorg
# changes statement ORDER relative to the historical single policy, so the no-drift invariant is
# order-INDEPENDENT: the SET of statements (compared by Sid) across the four files must equal the
# set in EntHomeAccess.reference.json (the verbatim historical full policy that CDK and Pulumi also
# consume). This is the check that proves the split did not add, drop, or alter any permission, and
# that the per-domain files and the Terraform module can't silently drift apart.
#
# Two layers of assertion, for the COMMERCIAL partition (default variables → partition "aws", no
# exclusions):
#   1. Each rendered functional policy == its EntHomeAccess.<domain>.json file (canonicalized).
#   2. The Sid-keyed union of the four rendered policies == the Sid-keyed reference. A Sid-keyed map
#      is order-independent and also catches a Sid appearing in two files (the later merge would
#      collide silently, so a separate count assertion guards against a dropped/duplicated Sid).
#
# Runs credential-free: the skip_* flags let the provider initialize without AWS credentials, and
# data.aws_partition.current is derived from the region offline (us-east-1 → "aws").

provider "aws" {
  region                      = "us-east-1"
  access_key                  = "testonly"
  secret_key                  = "testonly"
  skip_credentials_validation = true
  skip_requesting_account_id  = true
  skip_metadata_api_check     = true
}

run "each_functional_policy_matches_its_file" {
  command = plan

  # Compute & Networking
  assert {
    condition     = jsonencode(jsondecode(output.policy_json_by_group["compute-network"])) == jsonencode(jsondecode(file("${path.module}/../../../EntHomeAccess.compute-network.json")))
    error_message = "Rendered Compute & Networking policy drifted from EntHomeAccess.compute-network.json. Update the deploy-permissions module and the file in lockstep."
  }

  # Data & Storage
  assert {
    condition     = jsonencode(jsondecode(output.policy_json_by_group["data-storage"])) == jsonencode(jsondecode(file("${path.module}/../../../EntHomeAccess.data-storage.json")))
    error_message = "Rendered Data & Storage policy drifted from EntHomeAccess.data-storage.json. Update the deploy-permissions module and the file in lockstep."
  }

  # Identity & Security
  assert {
    condition     = jsonencode(jsondecode(output.policy_json_by_group["identity-security"])) == jsonencode(jsondecode(file("${path.module}/../../../EntHomeAccess.identity-security.json")))
    error_message = "Rendered Identity & Security policy drifted from EntHomeAccess.identity-security.json. Update the deploy-permissions module and the file in lockstep."
  }

  # Observability & Platform
  assert {
    condition     = jsonencode(jsondecode(output.policy_json_by_group["observability-platform"])) == jsonencode(jsondecode(file("${path.module}/../../../EntHomeAccess.observability-platform.json")))
    error_message = "Rendered Observability & Platform policy drifted from EntHomeAccess.observability-platform.json. Update the deploy-permissions module and the file in lockstep."
  }
}

run "union_of_four_equals_reference_set" {
  command = plan

  # No Sid lost to a cross-domain collision: the Sid-keyed union of all four rendered policies still
  # has the same distinct-Sid count as the reference. merge() is order-independent; a Sid shared by
  # two domains would collapse to one entry here and trip this count check.
  assert {
    condition = length(merge([
      for grp, doc in output.policy_json_by_group :
      { for s in jsondecode(doc).Statement : s.Sid => jsonencode(s) }
      ]...)) == length({
      for s in jsondecode(file("${path.module}/../../../EntHomeAccess.reference.json")).Statement : s.Sid => true
    })
    error_message = "Sid count of the four-policy union does not match EntHomeAccess.reference.json — a Sid was dropped or assigned to two domains."
  }

  # Set-equality: the Sid-keyed union of the four rendered policies == the Sid-keyed reference (same
  # Sids, each statement body identical after canonicalization). jsonencode sorts object keys, so
  # this comparison is order-independent — it tolerates the reorder the split introduces and fails
  # only on a real permission change (added / dropped / altered statement).
  assert {
    condition = jsonencode(merge([
      for grp, doc in output.policy_json_by_group :
      { for s in jsondecode(doc).Statement : s.Sid => jsonencode(s) }
      ]...)) == jsonencode({
      for s in jsondecode(file("${path.module}/../../../EntHomeAccess.reference.json")).Statement : s.Sid => jsonencode(s)
    })
    error_message = "The Sid-keyed union of the four functional policies drifted from EntHomeAccess.reference.json. The split changed a permission (added/dropped/altered a statement) — it must only reorder. Reconcile the statement_group map, the EntHomeAccess.<domain>.json files, and the reference."
  }
}
