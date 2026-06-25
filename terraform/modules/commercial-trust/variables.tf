variable "ent_aws_account_arn" {
  type        = string
  description = "Ent's AWS account ARN named as the principal in the role trust policy"
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

variable "policy_arn" {
  description = "ARN of the permission policy to attach to the role"
  type        = string
}
