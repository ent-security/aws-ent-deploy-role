variable "ca_certificate_pem" {
  description = "PEM-encoded Home environment CA root certificate that the trust anchor anchors to. Produced by W1 (the Home Dev/Prod AWS Private CA). This is the public root cert only — the deployer private key never leaves Home Secrets Manager."
  type        = string
}

variable "environment" {
  description = "Home environment this tenant trusts (dev or prod). Used to name the trust anchor and profile (home-<environment>-deployer)."
  type        = string

  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "environment must be \"dev\" or \"prod\"."
  }
}

variable "session_duration" {
  description = "Maximum session duration (seconds) for credentials issued through the profile."
  type        = number
  default     = 3600

  validation {
    condition     = var.session_duration >= 900 && var.session_duration <= 43200
    error_message = "session_duration must be between 900 and 43200 seconds."
  }
}

variable "trusted_cert_cn" {
  description = "Optional defense-in-depth: when set, the role trust policy additionally requires the presented deployer certificate's Subject CN to equal this value. Null disables the pin (trust-anchor scoping still applies)."
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
  description = "Description of the deploy role."
  type        = string
  default     = "Role that Ent Home assumes via IAM Roles Anywhere to deploy and manage resources in this GovCloud tenant."
}

variable "tags" {
  description = "A map of tags to add to the created resources."
  type        = map(string)
  default     = {}
}

variable "policy_arn" {
  description = "ARN of the permission policy to attach to the deploy role (the GovCloud-pruned deploy-permissions policy)."
  type        = string
}
