# GovCloud-partition trust via IAM Roles Anywhere. sts:AssumeRole cannot cross partitions, so a
# GovCloud tenant cannot name the commercial Home account as a trust principal. Instead the tenant
# registers the Home environment's CA root as a trust anchor; Home presents an X.509 client cert
# (issued by that CA, held in Home Secrets Manager) to rolesanywhere:CreateSession and receives
# GovCloud STS credentials for the deploy role.
#
# Three resources, all created in the tenant's GovCloud account:
#   - trust anchor : anchors to the Home environment's CA root PEM (external certificate bundle)
#   - deploy role  : trust policy allows the Roles Anywhere service, scoped to THIS trust anchor
#   - profile      : maps the trust anchor to the deploy role and bounds the session duration
#
# The rolesanywhere.amazonaws.com service principal is partition-neutral, so the trust block needs
# no partition handling — partition only matters in the permission policy (modules/deploy-permissions).

resource "aws_rolesanywhere_trust_anchor" "home" {
  name    = "home-${var.environment}-deployer"
  enabled = true

  source {
    source_type = "CERTIFICATE_BUNDLE"
    source_data {
      x509_certificate_data = var.ca_certificate_pem
    }
  }

  tags = var.tags
}

# Cross-partition substitute for "trust the Home account principal": trust the Roles Anywhere
# service, but only when the session originates from this specific trust anchor.
data "aws_iam_policy_document" "ra_trust" {
  statement {
    effect = "Allow"

    actions = [
      "sts:AssumeRole",
      "sts:TagSession",
      "sts:SetSourceIdentity",
    ]

    principals {
      type        = "Service"
      identifiers = ["rolesanywhere.amazonaws.com"]
    }

    # Primary scope: only sessions created against this trust anchor can assume the role.
    condition {
      test     = "ArnEquals"
      variable = "aws:SourceArn"
      values   = [aws_rolesanywhere_trust_anchor.home.arn]
    }

    # Optional defense-in-depth: pin the deployer certificate's Subject CN. Roles Anywhere maps the
    # cert Subject CN to aws:PrincipalTag/x509Subject/CN on the session
    # (https://docs.aws.amazon.com/rolesanywhere/latest/userguide/attribute-mapping-and-trust-policy.html).
    dynamic "condition" {
      for_each = var.trusted_cert_cn != null ? [var.trusted_cert_cn] : []
      content {
        test     = "StringEquals"
        variable = "aws:PrincipalTag/x509Subject/CN"
        values   = [condition.value]
      }
    }
  }
}

resource "aws_iam_role" "deploy" {
  name        = var.role_name
  path        = var.role_path
  description = var.role_description

  assume_role_policy = data.aws_iam_policy_document.ra_trust.json

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "deploy" {
  role       = aws_iam_role.deploy.name
  policy_arn = var.policy_arn
}

resource "aws_rolesanywhere_profile" "home" {
  name             = "home-${var.environment}-deployer"
  role_arns        = [aws_iam_role.deploy.arn]
  duration_seconds = var.session_duration
  enabled          = true

  tags = var.tags
}
