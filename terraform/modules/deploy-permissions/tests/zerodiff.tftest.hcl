# Zero-diff guard for the aws-ent-deploy-role functional policy split.
#
# The permission set is split across four functional managed policies (Compute, Data, Security,
# Platform), each its own authoritative EntHomeAccess.<domain>.json file (consumed verbatim by the
# Terraform module and by the CDK and Pulumi variants). This test proves the module and those files
# can't silently drift apart, for the COMMERCIAL partition (default variables → partition "aws", no
# exclusions):
#
#   Each rendered functional policy == its EntHomeAccess.<domain>.json file (canonicalized).
#
# The split itself introduced no permission change: the Sid-keyed union of the four was validated
# set-equal to the pre-split single policy before merge, via a throwaway EntHomeAccess.reference.json
# anchor built from the previous policy.json, since removed (the four files are now the sole source
# of truth).
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

  # Permissions boundary (not a functional domain policy, but authoritative-file-backed the same way)
  assert {
    condition     = jsonencode(jsondecode(output.boundary_policy_json)) == jsonencode(jsondecode(file("${path.module}/../../../EntHomeAccess.boundary.json")))
    error_message = "Rendered permissions-boundary policy drifted from EntHomeAccess.boundary.json. Update the deploy-permissions module and the file in lockstep."
  }
}
