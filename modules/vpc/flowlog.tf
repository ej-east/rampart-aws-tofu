resource "aws_cloudwatch_log_group" "this" {
  count             = var.flowlogs.destination == "cloudwatch" ? 1 : 0
  name              = local.cloudwatch_log_group_name
  retention_in_days = var.flowlogs.retention_days

  kms_key_id = var.encrypt_flow_logs ? (local.byok ? var.kms_key_arn : aws_kms_key.flowlogs[0].arn) : null

  tags = merge(var.tags, {
    Name = local.cloudwatch_log_group_name
  })
}

resource "aws_flow_log" "this" {
  iam_role_arn         = var.flowlogs.destination == "cloudwatch" ? aws_iam_role.flowlog[0].arn : null
  log_destination      = var.flowlogs.destination == "cloudwatch" ? aws_cloudwatch_log_group.this[0].arn : var.flowlogs.s3_bucket_arn
  log_destination_type = var.flowlogs.destination == "cloudwatch" ? "cloud-watch-logs" : var.flowlogs.destination
  traffic_type         = var.flowlogs.traffic_type
  vpc_id               = aws_vpc.this.id

  tags = merge(var.tags, {
    Name = "${var.prefix}-flowlogs"
  })
}

data "aws_iam_policy_document" "flowlogs_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["vpc-flow-logs.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "flowlog" {
  count              = var.flowlogs.destination == "cloudwatch" ? 1 : 0
  name_prefix        = "${var.prefix}-flowlog-role-"
  assume_role_policy = data.aws_iam_policy_document.flowlogs_assume_role.json
  tags = merge(var.tags, {
    Name = "${var.prefix}-flowlog-role"
  })
}

data "aws_iam_policy_document" "flowlog" {
  count = var.flowlogs.destination == "cloudwatch" ? 1 : 0
  statement {
    sid    = "WriteCloudWatchLogs"
    effect = "Allow"

    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:DescribeLogGroups",
      "logs:DescribeLogStreams",
      "logs:PutLogEvents"
    ]

    resources = ["${aws_cloudwatch_log_group.this[0].arn}:*"]
  }

  dynamic "statement" {
    for_each = var.encrypt_flow_logs ? [1] : []
    content {
      sid    = "UseLogEncryptionKey"
      effect = "Allow"

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
}

resource "aws_iam_role_policy" "flowlog" {
  count       = var.flowlogs.destination == "cloudwatch" ? 1 : 0
  name_prefix = "${var.prefix}-iam-role-policy-"
  role        = aws_iam_role.flowlog[0].id
  policy      = data.aws_iam_policy_document.flowlog[0].json
}
