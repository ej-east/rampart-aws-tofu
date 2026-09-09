data "aws_iam_policy_document" "kms" {
  #checkov:skip=CKV_AWS_356: IAM policy uses `*` for restrictable resources
  #checkov:skip=CKV_AWS_109: Allow full key administration by root user
  #checkov:skip=CKV_AWS_111: Default AWS key policy shape - root delegates to IAM, no condition block by design
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
}

resource "aws_kms_key" "this" {
  count                   = local.create_cmek
  description             = "KMS Key for ECR Module"
  enable_key_rotation     = true
  deletion_window_in_days = 30

  policy = data.aws_iam_policy_document.kms.json

  tags = merge(var.tags, {
    Name = var.name
  })
}

resource "aws_kms_alias" "this" {
  count         = local.create_cmek
  name          = "alias/ecr/${var.name}"
  target_key_id = aws_kms_key.this[0].key_id
}
