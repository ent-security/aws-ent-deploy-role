# Zero-diff guard for the aws-ent-deploy-role restructure.
#
# The shared deploy-permissions policy, rendered for the COMMERCIAL partition (default variables →
# partition "aws", no exclusions), must stay semantically identical to the authoritative
# policy.json that the CDK and Pulumi templates consume. This is the check that proves the
# refactor did not change the commercial deploy role's permissions, and that policy.json and the
# Terraform policy can't silently drift apart.
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

run "commercial_policy_matches_golden" {
  command = plan

  assert {
    # Canonicalize both sides (jsondecode → jsonencode sorts keys, compacts) so formatting
    # differences don't matter — only the logical policy content is compared.
    condition     = jsonencode(jsondecode(output.policy_json)) == jsonencode(jsondecode(file("${path.module}/../../../policy.json")))
    error_message = "Rendered commercial policy drifted from policy.json. The commercial deploy role would regress — update the deploy-permissions module and policy.json in lockstep."
  }
}
