resource "aws_ecr_repository" "this" {
  name                 = var.name
  image_tag_mutability = var.tag_mutability
  force_delete         = var.force_delete

  dynamic "image_scanning_configuration" {
    for_each = var.scan_on_push ? ["1"] : []
    content {
      scan_on_push = true
    }
  }


  dynamic "image_tag_mutability_exclusion_filter" {
    for_each = coalesce(var.tag_exclusion, [])
    iterator = exclusion
    content {
      filter      = exclusion.value.filter
      filter_type = exclusion.value.filter_type
    }
  }

  dynamic "encryption_configuration" {
    for_each = var.encryption ? ["1"] : []

    content {
      encryption_type = "KMS"
      kms_key         = local.cmek
    }
  }

  tags = merge(var.tags, {
    Name = var.name
  })
}

resource "aws_ecr_lifecycle_policy" "this" {
  count      = length(local.life_cycle_policy) == 0 ? 0 : 1
  repository = aws_ecr_repository.this.name
  policy     = jsonencode({ rules = local.life_cycle_policy })
}

data "aws_iam_policy_document" "accounts" {
  statement {
    sid    = "AllowCrossAccountPull"
    effect = "Allow"

    principals {
      type = "AWS"

      identifiers = [for account in var.share_with_account : "arn:${data.aws_partition.current.partition}:iam::${account}:root"]
    }

    actions = ["ecr:BatchCheckLayerAvailability", "ecr:BatchGetImage", "ecr:GetDownloadUrlForLayer"]
  }
}


resource "aws_ecr_repository_policy" "this" {
  count      = length(var.share_with_account) >= 1 ? 1 : 0
  repository = aws_ecr_repository.this.name
  policy     = data.aws_iam_policy_document.accounts.json
}
