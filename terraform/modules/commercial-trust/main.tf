# Commercial-partition trust: the IAM role Ent Home reaches via sts:AssumeRole, with the Home
# account named as principal. This is today's HomeProdAssumeAdmin behavior, moved verbatim from
# the old terraform/main.tf root so the commercial path renders identically (see the moved{} blocks
# in terraform/commercial/). GovCloud uses modules/govcloud-rolesanywhere instead — assume-role
# cannot cross partitions.

data "aws_iam_policy_document" "assume_role" {
  # No ExternalId configured: a single combined statement granting both actions with no condition.
  # This is the original behavior and renders byte-for-byte identically to the pre-split policy.
  dynamic "statement" {
    for_each = var.role_sts_external_id == "" ? [1] : []
    content {
      effect = "Allow"

      actions = ["sts:AssumeRole", "sts:TagSession"]

      principals {
        type        = "AWS"
        identifiers = [var.ent_aws_account_arn]
      }
    }
  }

  # ExternalId configured: sts:AssumeRole keeps the ExternalId condition (confused-deputy protection).
  dynamic "statement" {
    for_each = var.role_sts_external_id != "" ? [1] : []
    content {
      sid    = "EntDeployAssumeRole"
      effect = "Allow"

      actions = ["sts:AssumeRole"]

      principals {
        type        = "AWS"
        identifiers = [var.ent_aws_account_arn]
      }

      condition {
        test     = "StringEquals"
        variable = "sts:ExternalId"
        values   = [var.role_sts_external_id]
      }
    }
  }

  # ...but sts:TagSession is granted WITHOUT the ExternalId condition. STS only populates
  # sts:ExternalId in the request context when it authorizes sts:AssumeRole, not sts:TagSession; the
  # Home deploy identity uses EKS Pod Identity, whose transitive session tags force an sts:TagSession
  # authorization alongside every cross-account assume. Gating TagSession on sts:ExternalId would
  # evaluate a missing key -> implicit deny -> AccessDenied on sts:TagSession.
  dynamic "statement" {
    for_each = var.role_sts_external_id != "" ? [1] : []
    content {
      sid    = "EntDeployTagSession"
      effect = "Allow"

      actions = ["sts:TagSession"]

      principals {
        type        = "AWS"
        identifiers = [var.ent_aws_account_arn]
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
