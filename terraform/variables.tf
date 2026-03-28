variable "ent_aws_account_arn" {
  type        = string
  default     = "arn:aws:iam::000000000000:root"
  description = "Ent's AWS account ARN"

  validation {
    condition     = var.ent_aws_account_arn != "arn:aws:iam::000000000000:root"
    error_message = "ent_aws_account_arn must be set to the actual Ent AWS account ARN."
  }
}

variable "external_id" {
  type        = string
  default     = ""
  description = "Optional external ID for confused deputy protection. When set, the assuming role must provide this value."
}

variable "role_name" {
  description = "IAM role name"
  type        = string
  default     = "EntHomeDeployRole"
}

variable "role_path" {
  description = "Path of IAM role (we currently do not support a path other than '/')"
  type        = string
  default     = "/"
}

variable "role_description" {
  description = "IAM Role description"
  type        = string
  default     = "Role that allows Ent Home to deploy and manage infrastructure in this account"
}

variable "tags" {
  description = "A map of tags to add to IAM role resources"
  type        = map(string)
  default     = {}
}
