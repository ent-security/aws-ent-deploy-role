variable "region" {
  description = "GovCloud region to deploy into. Selects the partition (us-gov-* → aws-us-gov)."
  type        = string
  default     = "us-gov-west-1"
}

variable "ca_certificate_pem" {
  description = "PEM-encoded Home environment CA root certificate the trust anchor anchors to (from W1)."
  type        = string
}

variable "environment" {
  description = "Home environment this tenant trusts (dev or prod). Names the trust anchor and profile."
  type        = string
}

variable "session_duration" {
  description = "Maximum session duration (seconds) for credentials issued through the profile."
  type        = number
  default     = 3600
}

variable "trusted_cert_cn" {
  description = "Optional defense-in-depth: pin the deployer certificate Subject CN in the role trust policy. Null disables the pin."
  type        = string
  default     = null
}

variable "role_name" {
  description = "Name of the GovCloud deploy role assumed via Roles Anywhere."
  type        = string
  default     = "HomeProdAssumeAdmin"
}

variable "role_path" {
  description = "Path of the deploy role."
  type        = string
  default     = "/"
}

variable "role_description" {
  description = "IAM Role description."
  type        = string
  default     = "Role that Ent Home assumes via IAM Roles Anywhere to deploy and manage resources in this GovCloud tenant."
}

variable "tags" {
  description = "A map of tags to add to the created resources."
  type        = map(string)
  default     = {}
}
