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
# rendered policy == its EntHomeAccess.<domain>.json file and that the Sid-sorted union of the four
# == EntHomeAccess.reference.json (no permission drift).
output "policy_json_by_group" {
  value       = { for k, p in aws_iam_policy.this : k => p.policy }
  description = "Map of functional domain -> rendered policy JSON. Used by the zero-diff test to assert set-equality against the per-domain files and the reference union."
}
