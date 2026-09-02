data "aws_iam_policy_document" "kms" {
  #checkov:skip=CKV_AWS_356: IAM policy uses `*` for restrictable resources
  #checkov:skip=CKV_AWS_109: Allow full key administration by root user
  #checkov:skip=CKV_AWS_111: We use a condition block to ensure it's correct
  statement {
    sid    = "EnableIAMPermissions"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = [local.root_arn]
    }

    actions   = ["kms:*"]
    resources = ["*"]
  }

  statement {
    sid    = "AllowCloudWatchLogs"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["logs.${data.aws_region.current.region}.amazonaws.com"]
    }
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:DescribeKey",
    ]

    resources = ["*"]

    condition {
      test     = "ArnEquals"
      variable = "kms:EncryptionContext:aws:logs:arn"

      values = ["${local.cloudwatch_arn}:${local.cloudwatch_log_group_name}"]
    }
  }
}

resource "aws_kms_key" "flowlogs" {
  count                   = var.encrypt_flow_logs && !local.byok && var.flowlogs.destination == "cloudwatch" ? 1 : 0
  description             = "KMS Key for VPC Module"
  enable_key_rotation     = true
  deletion_window_in_days = 30

  policy = data.aws_iam_policy_document.kms.json

  tags = merge(var.tags, {
    Name = "${var.prefix}-flowlogs"
  })
}
