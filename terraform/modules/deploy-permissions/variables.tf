variable "policy_name" {
  description = "Name PREFIX for the IAM permission policies. The permission set is split across four functional managed policies; this prefix is suffixed per domain to produce <prefix>Compute, <prefix>Data, <prefix>Security, and <prefix>Platform. Overriding it renames all four in lockstep."
  type        = string
  default     = "EntHomeAccess"
}

variable "policy_path" {
  description = "Path of the IAM permission policy"
  type        = string
  default     = "/"
}

variable "policy_description" {
  description = "Description of the IAM permission policy"
  type        = string
  default     = "Custom policy for permissions needed by Ent Home to deploy and manage resources in customer accounts. This policy is attached to the role that Ent Home assumes when deploying resources in customer accounts."
}

variable "excluded_statement_sids" {
  description = "Statement Sids to drop from the shared policy for this partition. Used to remove statements for services that do not exist in the target partition (e.g. CostAndUsageReportAccess / BCMDataExportsAccess in GovCloud). Empty (the commercial default) renders the full policy."
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Tags applied to the managed policies, mirroring the tags on the deploy role (e.g. the FinOps Service / Environment keys). Threaded from the root so the policies carry the same tags the role does."
  type        = map(string)
  default     = {}
}

variable "permissions_boundary_arn" {
  description = "Opt-in. ARN of the permissions boundary every role the deploy role creates under role/e???????????????-* must carry. When set, adds the <policy_name>BoundaryGuard policy: CreateRole/PutRolePolicy/AttachRolePolicy are denied on roles without this boundary, and it cannot be removed, swapped or edited. Pass your own policy, or this module's boundary_policy_arn output. Empty (default) adds nothing. Turn it on only after Ent Home sends the same ARN for the tenant (its iamPermissionsBoundaryArn), or that tenant's deploys are denied."
  type        = string
  default     = ""

  validation {
    condition     = var.permissions_boundary_arn == "" || can(regex("^arn:aws[a-z-]*:iam::[0-9]{12}:policy/.+$", var.permissions_boundary_arn))
    error_message = "permissions_boundary_arn must be empty or an IAM policy ARN (arn:<partition>:iam::<12-digit account>:policy/<name>)."
  }
}
