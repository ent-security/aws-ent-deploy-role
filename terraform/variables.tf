variable "ent_aws_account_arn" {
  type        = string
  default     = "arn:aws:iam::051759900972:role/prod-uswest1-eks-pi-1-20251203221124633900000005"
  description = "Ent's AWS account ARN"
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
  default     = "Role that allows HomeDev SSO to assume EntHomePermissions role"
}

variable "tags" {
  description = "A map of tags to add to IAM role resources"
  type        = map(string)
  default     = {}
}
