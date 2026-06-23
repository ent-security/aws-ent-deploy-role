output "trust_anchor_arn" {
  value       = module.govcloud_rolesanywhere.trust_anchor_arn
  description = "ARN of the trust anchor → register as cloudProviderDetails.rolesAnywhereTrustAnchorArn"
}

output "profile_arn" {
  value       = module.govcloud_rolesanywhere.profile_arn
  description = "ARN of the Roles Anywhere profile → register as cloudProviderDetails.rolesAnywhereProfileArn"
}

output "role_arn" {
  value       = module.govcloud_rolesanywhere.role_arn
  description = "ARN of the deploy role → register as cloudProviderDetails.roleArn"
}
