locals {
  root_arn    = "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:root"
  create_cmek = var.encryption && var.kms_key_arn == null ? 1 : 0
  cmek        = var.kms_key_arn == null ? try(aws_kms_key.this[0].arn, null) : var.kms_key_arn

  life_cycle_policy = [for r in coalesce(var.life_cycle_policy, []) : merge(
    {
      rulePriority = r.rulePriority
      selection = merge({
        tagStatus   = r.selection.tagStatus
        countType   = r.selection.countType
        countNumber = r.selection.countNumber
        },
        {
          for k, v in {
            tagPatternList = r.selection.tagPatternList
            tagPrefixList  = r.selection.tagPrefixList
            countUnit      = r.selection.countUnit

            storageClass = (
              r.selection.countType == "sinceImageTransitioned" ? r.selection.storageClass : null
            )
          } : k => v if v != null
        }
      )
      action = merge({
        type = r.action.type
        }, {
        for k, v in { targetStorageClass = r.action.targetStorageClass } : k => v if v != null
      })
    },

    r.description != "" ? { description = r.description } : {}
  )]
}
