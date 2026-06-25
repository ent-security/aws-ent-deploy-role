output "trust_anchor_arn" {
  value       = aws_rolesanywhere_trust_anchor.home.arn
  description = "ARN of the trust anchor → tenant cloudProviderDetails.rolesAnywhereTrustAnchorArn"
}

output "profile_arn" {
  value       = aws_rolesanywhere_profile.home.arn
  description = "ARN of the Roles Anywhere profile → tenant cloudProviderDetails.rolesAnywhereProfileArn"
}

output "role_arn" {
  value       = aws_iam_role.deploy.arn
  description = "ARN of the deploy role → tenant cloudProviderDetails.roleArn"
}
