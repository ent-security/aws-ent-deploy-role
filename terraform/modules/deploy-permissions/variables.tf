variable "policy_name" {
  description = "Name of the IAM permission policy"
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
