output "policy_arn" {
  value       = aws_iam_policy.this.arn
  description = "The ARN of the permission policy"
}

output "policy_name" {
  value       = aws_iam_policy.this.name
  description = "The name of the permission policy"
}

output "policy_json" {
  value       = aws_iam_policy.this.policy
  description = "The rendered policy JSON. Exposed so the commercial root can assert zero-diff against the authoritative policy.json."
}
