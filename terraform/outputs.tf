output "role_arn" {
  value       = aws_iam_role.ent.arn
  description = "The ARN of the role"
}

output "role_name" {
  value       = aws_iam_role.ent.name
  description = "The name of the role"
}

output "policy_arn" {
  value       = aws_iam_policy.ent_deploy_permissions.arn
  description = "The ARN of the policy"
}
