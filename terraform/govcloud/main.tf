# GovCloud-partition deploy role. A tenant runs this root in their own GovCloud account during
# onboarding (design Phase 1). It composes the shared permission policy (GovCloud-pruned) with the
# Roles Anywhere trust, and emits the three ARNs that get registered in the tenant's
# cloudProviderDetails back in Home.
#
# Applied directly (not consumed as a child module like commercial/), so it configures the AWS
# provider. The region selects the partition: us-gov-* → aws-us-gov, which the shared policy reads
# from data.aws_partition.current to render arn:aws-us-gov:* ARNs.

provider "aws" {
  region = var.region
}

module "deploy_permissions" {
  source = "../modules/deploy-permissions"

  tags = var.tags
  # Services absent from GovCloud (billing/Data Exports live in the linked commercial account).
  # The full unavailable-list is discovered during validation (design W4) — add Sids here as
  # GovCloud apply surfaces them. The WAFv2 global (CloudFront) ARN is dropped automatically by
  # the module's partition check; everything else (incl. Bedrock, Route 53) exists in GovCloud.
  excluded_statement_sids = [
    "CostAndUsageReportAccess",
    "BCMDataExportsAccess",
  ]
}

module "govcloud_rolesanywhere" {
  source = "../modules/govcloud-rolesanywhere"

  ca_certificate_pem = var.ca_certificate_pem
  environment        = var.environment
  session_duration   = var.session_duration
  trusted_cert_cn    = var.trusted_cert_cn
  role_name          = var.role_name
  role_path          = var.role_path
  role_description   = var.role_description
  tags               = var.tags

  policy_arns = module.deploy_permissions.policy_arns
}
