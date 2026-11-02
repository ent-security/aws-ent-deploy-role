output "role_arn" {
  value       = module.commercial_trust.role_arn
  description = "The ARN of the role"
}

output "role_name" {
  value       = module.commercial_trust.role_name
  description = "The name of the role"
}

output "policy_arns" {
  value       = module.deploy_permissions.policy_arns
  description = "ARNs of the four functional permission policies attached to the role"
}

# DEPRECATED compat alias — see the module output of the same name. Points at one functional policy
# (EntHomeAccessSecurity). The full permission set spans four policies; use policy_arns.
output "policy_arn" {
  value       = module.deploy_permissions.policy_arn
  description = "DEPRECATED: ARN of one functional policy (EntHomeAccessSecurity). Use policy_arns for the full set. Retained for backward compatibility."
}

output "boundary_policy_arn" {
  value       = module.deploy_permissions.boundary_policy_arn
  description = "ARN of the EntHomeAccessBoundary permissions-boundary policy. Not attached to the role -- see the IAM privilege-escalation guard section in the README."
}
