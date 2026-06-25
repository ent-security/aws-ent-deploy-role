# State continuity for the refactor into modules. Consumers whose state was created by the old
# single-file terraform/ root (resources at these top-level addresses) migrate in place — no
# destroy/recreate — when they re-point at terraform/commercial/. No-ops on a fresh apply.

moved {
  from = aws_iam_policy.ent_deploy_permissions
  to   = module.deploy_permissions.aws_iam_policy.this
}

moved {
  from = aws_iam_role.ent
  to   = module.commercial_trust.aws_iam_role.this
}

moved {
  from = aws_iam_role_policy_attachment.ent_deploy_permissions
  to   = module.commercial_trust.aws_iam_role_policy_attachment.this
}
