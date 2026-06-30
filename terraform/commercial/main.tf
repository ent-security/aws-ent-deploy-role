# Commercial-partition deploy role (today's behavior). Ent Home reaches this role via
# sts:AssumeRole. Composes the four functional permission policies with the commercial assume-role
# trust.
#
# The permission SET is unchanged from the pre-split single EntHomeAccess policy (the union of the
# four functional policies equals it), but the single EntHomeAccess policy is REPLACED — not renamed
# — by the four EntHomeAccess{Compute,Data,Security,Platform} policies. An existing tenant's apply
# destroys the old EntHomeAccess policy and creates the four; the role (HomeProdAssumeAdmin) is
# unchanged and ends attached to all four. See the migration note in the PR / README. The role move
# in moved.tf is in-place; there is deliberately no moved block for the policy (a replace, not a
# rename).

module "deploy_permissions" {
  source = "../modules/deploy-permissions"

  # Commercial gets the full policy set: no partition exclusions, ARNs render arn:aws:*.
}

module "commercial_trust" {
  source = "../modules/commercial-trust"

  ent_aws_account_arn  = var.ent_aws_account_arn
  role_sts_external_id = var.role_sts_external_id
  role_name            = var.role_name
  role_path            = var.role_path
  role_description     = var.role_description
  tags                 = var.tags

  policy_arns = module.deploy_permissions.policy_arns
}
