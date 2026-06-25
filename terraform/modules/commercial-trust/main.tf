# Commercial-partition trust: the IAM role Ent Home reaches via sts:AssumeRole, with the Home
# account named as principal. This is today's HomeProdAssumeAdmin behavior, moved verbatim from
# the old terraform/main.tf root so the commercial path renders identically (see the moved{} blocks
# in terraform/commercial/). GovCloud uses modules/govcloud-rolesanywhere instead — assume-role
# cannot cross partitions.

data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"

    actions = ["sts:AssumeRole", "sts:TagSession"]

    principals {
      type        = "AWS"
      identifiers = [var.ent_aws_account_arn]
    }

    dynamic "condition" {
      for_each = var.role_sts_external_id != "" ? [1] : []
      content {
        test     = "StringEquals"
        variable = "sts:ExternalId"
        values   = [var.role_sts_external_id]
      }
    }
  }
}

resource "aws_iam_role" "this" {
  name        = var.role_name
  path        = var.role_path
  description = var.role_description

  assume_role_policy = data.aws_iam_policy_document.assume_role.json

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "this" {
  role       = aws_iam_role.this.name
  policy_arn = var.policy_arn
}
