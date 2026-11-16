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

output "boundary_policy_arn" {
  value       = module.deploy_permissions.boundary_policy_arn
  description = "ARN of the EntHomeAccessBoundary policy, Ent's default permissions boundary. Not attached to the role; pass it as permissions_boundary_arn to enforce it. See the IAM privilege-escalation guard section in the README."
}
