# The real output: ARNs of every managed policy the deploy role needs. Trust modules attach every
# entry. The four functional policies come first, sorted by map key (compute-network, data-storage,
# identity-security, observability-platform), then the opt-in guards (boundary, owner tag) when on.
# Guards go last so switching one on never shifts the index-keyed attachments of the four.
output "policy_arns" {
  value = concat(
    [for k in sort(keys(aws_iam_policy.this)) : aws_iam_policy.this[k].arn],
    aws_iam_policy.boundary_guard[*].arn,
    aws_iam_policy.owner_tag_guard[*].arn,
  )
  description = "ARNs of the four functional permission policies (Compute, Data, Security, Platform), followed by the BoundaryGuard / OwnerTagGuard policies when permissions_boundary_arn / owner_tag_key are set. Attach every entry to the deploy role."
}

# Backward-compat single ARN. The pre-split module exposed one policy_arn; consumers and the
# CDK/Pulumi single-ARN exports still reference it. Points at the Identity & Security policy
# (EntHomeAccessSecurity) as a stable representative. DEPRECATED: a single ARN no longer covers the
# whole permission set — use policy_arns. Retained so existing references keep resolving.
output "policy_arn" {
  value       = aws_iam_policy.this["identity-security"].arn
  description = "DEPRECATED compat alias: ARN of one functional policy (EntHomeAccessSecurity). The full permission set now spans four policies — use policy_arns. Kept so pre-split single-ARN consumers keep resolving."
}

output "policy_names" {
  value       = [for k in sort(keys(aws_iam_policy.this)) : aws_iam_policy.this[k].name]
  description = "Names of the four functional permission policies."
}

# Rendered policy JSON keyed by functional domain. Exposed so the zero-diff test can assert each
# rendered policy == its EntHomeAccess.<domain>.json file.
output "policy_json_by_group" {
  value       = { for k, p in aws_iam_policy.this : k => p.policy }
  description = "Map of functional domain -> rendered policy JSON. Used by the zero-diff test to assert each rendered policy matches its per-domain file."
}

# Ent's default permissions-boundary policy. Never attached to the deploy role; pass its ARN as
# permissions_boundary_arn to enforce it.
output "boundary_policy_arn" {
  value       = aws_iam_policy.boundary.arn
  description = "ARN of Ent's default permissions-boundary policy (EntHomeAccessBoundary). Not attached to the deploy role and not part of policy_arns. Pass it as permissions_boundary_arn to require it on every role the deploy role creates under role/e???????????????-*."
}

output "boundary_policy_name" {
  value       = aws_iam_policy.boundary.name
  description = "Name of the permissions-boundary policy (EntHomeAccessBoundary)."
}

# Rendered boundary policy JSON. Used by the zero-diff test to assert it matches
# EntHomeAccess.boundary.json.
output "boundary_policy_json" {
  value       = aws_iam_policy.boundary.policy
  description = "Rendered JSON of the permissions-boundary policy. Used by the zero-diff test to assert it matches EntHomeAccess.boundary.json."
}

# Rendered guard policy JSON (null when that guard is off). Used by tests/guards.tftest.hcl to assert
# each matches its EntHomeAccess.<guard>.json fragment.
output "boundary_guard_policy_json" {
  value       = one(aws_iam_policy.boundary_guard[*].policy)
  description = "Rendered JSON of the BoundaryGuard policy, or null when permissions_boundary_arn is empty."
}

output "owner_tag_guard_policy_json" {
  value       = one(aws_iam_policy.owner_tag_guard[*].policy)
  description = "Rendered JSON of the OwnerTagGuard policy, or null when owner_tag_key is empty."
}
