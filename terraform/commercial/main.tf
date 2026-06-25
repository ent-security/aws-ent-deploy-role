# Commercial-partition deploy role (today's behavior). Ent Home reaches this role via
# sts:AssumeRole. Composes the shared permission policy with the commercial assume-role trust.
#
# This root renders identically to the pre-refactor terraform/ root — see the zero-diff test in
# tests/ and the moved{} blocks in moved.tf that migrate existing state into the new modules.

module "deploy_permissions" {
  source = "../modules/deploy-permissions"

  # Commercial gets the full policy: no partition exclusions, ARNs render arn:aws:*.
}

module "commercial_trust" {
  source = "../modules/commercial-trust"

  ent_aws_account_arn  = var.ent_aws_account_arn
  role_sts_external_id = var.role_sts_external_id
  role_name            = var.role_name
  role_path            = var.role_path
  role_description     = var.role_description
  tags                 = var.tags

  policy_arn = module.deploy_permissions.policy_arn
}
