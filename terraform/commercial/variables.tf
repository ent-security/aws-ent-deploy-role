variable "ent_aws_account_arn" {
  type        = string
  default     = "arn:aws:iam::051759900972:role/prod-uswest1-eks-pi-1-20251203221124633900000005"
  description = "Ent's AWS account ARN"
}

variable "role_sts_external_id" {
  type        = string
  default     = ""
  description = "STS ExternalId condition value. When set, Ent Home must supply this value in its AssumeRole call. Empty string means no ExternalId constraint (not recommended for production)."
}

variable "role_name" {
  description = "IAM role name"
  type        = string
  default     = "HomeProdAssumeAdmin"
}

variable "role_path" {
  description = "Path of IAM role (we currently do not support a path other than '/')"
  type        = string
  default     = "/"
}

variable "role_description" {
  description = "IAM Role description"
  type        = string
  default     = "Role that allows Ent Home to assume AdministratorAccess role"
}

variable "tags" {
  description = "A map of tags to add to IAM role resources"
  type        = map(string)
  default     = {}
}

variable "permissions_boundary_arn" {
  description = "Opt-in privilege-escalation guard. ARN of the permissions boundary every role the deploy role creates under role/e???????????????-* must carry (your own policy, or the boundary_policy_arn output). Empty (default) leaves the guard off. Set it only after Ent has set the same ARN on your tenant, or deploys are denied. See README: IAM privilege-escalation guard."
  type        = string
  default     = ""
}

variable "owner_tag_key" {
  description = "Opt-in ownership-tag guard. Tag key (e.g. \"Owner Role\") every role the deploy role creates under role/e???????????????-* must carry with value owner_tag_value. Empty (default) leaves the guard off. Set it only after Ent has set the same tag on your tenant, or deploys are denied."
  type        = string
  default     = ""
}

variable "owner_tag_value" {
  description = "Value the owner_tag_key tag must have. Required when owner_tag_key is set."
  type        = string
  default     = ""
}
