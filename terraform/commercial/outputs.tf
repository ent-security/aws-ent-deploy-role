output "role_arn" {
  value       = module.commercial_trust.role_arn
  description = "The ARN of the role"
}

output "role_name" {
  value       = module.commercial_trust.role_name
  description = "The name of the role"
}

output "policy_arn" {
  value       = module.deploy_permissions.policy_arn
  description = "The ARN of the policy"
}
