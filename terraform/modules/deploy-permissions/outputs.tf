# The real output: ARNs of all four functional managed policies. Trust modules attach every entry.
# Sorted by map key for a stable order (compute-network, data-storage, identity-security,
# observability-platform).
output "policy_arns" {
  value       = [for k in sort(keys(aws_iam_policy.this)) : aws_iam_policy.this[k].arn]
  description = "ARNs of the four functional permission policies (Compute, Data, Security, Platform). Attach all four to the deploy role."
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

# The permissions-boundary policy (see IAMBoundaryEnforcement in EntHomeAccessSecurity). Sits
# outside the for_each-driven aws_iam_policy.this above -- it's not one of the four functional
# policies and is never attached to the deploy role -- so it needs its own output.
output "boundary_policy_arn" {
  value       = aws_iam_policy.boundary.arn
  description = "ARN of the permissions-boundary policy (EntHomeAccessBoundary). Not attached to the deploy role -- it's the boundary the deploy role must apply (via iam:PermissionsBoundary) to any role it creates under role/e???????????????-*. Not part of policy_arns."
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
