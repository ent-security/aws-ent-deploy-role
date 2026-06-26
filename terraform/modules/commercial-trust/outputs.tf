output "role_arn" {
  value       = aws_iam_role.this.arn
  description = "The ARN of the role"
}

output "role_name" {
  value       = aws_iam_role.this.name
  description = "The name of the role"
}

output "assume_role_policy_json" {
  value       = data.aws_iam_policy_document.assume_role.json
  description = "The rendered trust (assume-role) policy JSON. Exposed so tests can assert the statement shape — in particular that sts:TagSession is never gated by the sts:ExternalId condition."
}
