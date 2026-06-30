# State continuity for the refactor into modules. The DEPLOY ROLE migrates in place — no
# destroy/recreate — when a consumer created by the old single-file terraform/ root re-points at
# terraform/commercial/. No-op on a fresh apply.
#
# There is deliberately NO moved block for the permission policy or its attachment. The functional
# split replaces the single EntHomeAccess policy with four EntHomeAccess{Compute,Data,Security,
# Platform} policies — a destroy-and-create, not a rename. A moved block can only express a rename
# (one address -> one address); pretending the replace is a rename would be wrong (the old single
# policy genuinely goes away, and the old single-attachment to it goes with it). The old policy +
# attachment are destroyed and the four new policies + attachments are created; the role, and thus
# the tenant's effective permission set, is unchanged across the apply.

moved {
  from = aws_iam_role.ent
  to   = module.commercial_trust.aws_iam_role.this
}
