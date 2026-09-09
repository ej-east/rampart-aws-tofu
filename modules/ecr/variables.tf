variable "name" {
  type        = string
  description = "The name of the ECR and prefix to ECR components"
}

variable "tag_mutability" {
  type        = string
  description = "The image tag mutability value. Valid inputs are: MUTABLE, IMMUTABLE, IMMUTABLE_WITH_EXCLUSION, or MUTABLE_WITH_EXCLUSION"
  default     = "IMMUTABLE"

  validation {
    condition     = contains(["MUTABLE", "IMMUTABLE", "MUTABLE_WITH_EXCLUSION", "IMMUTABLE_WITH_EXCLUSION"], var.tag_mutability)
    error_message = "tag_mutability must be set to one of the following: MUTABLE, IMMUTABLE, IMMUTABLE_WITH_EXCLUSION, or MUTABLE_WITH_EXCLUSION"
  }
}

variable "tag_exclusion" {
  type = list(object({
    filter_type = optional(string, "WILDCARD")
    filter      = string
  }))
  nullable = true
  default  = null
  validation {
    condition     = length(coalesce(var.tag_exclusion, [])) == 0 || contains(["MUTABLE_WITH_EXCLUSION", "IMMUTABLE_WITH_EXCLUSION"], var.tag_mutability)
    error_message = "tag_mutability must be: IMMUTABLE_WITH_EXCLUSION or MUTABLE_WITH_EXCLUSION when attempting to specify a tag_exclusion"
  }
}

variable "life_cycle_policy" {
  type = list(object({
    rulePriority = number
    description  = optional(string, "")
    selection = object({
      tagStatus   = string # tagged | untagged | any 
      countType   = string # imageCountMoreThan | sinceImagePushed | sinceImagePulled | sinceImageTransitioned(expire)
      countNumber = number

      tagPatternList = optional(list(string)) # tagged only
      tagPrefixList  = optional(list(string)) # tagged only 

      countUnit    = optional(string)             # days is only supported + only required for anything w since
      storageClass = optional(string, "standard") # standard | archive required for sinceImageTransitioned 
    })

    action = object({
      type               = string           # expire or transition
      targetStorageClass = optional(string) # must be set if transition to archive
    })
  }))
  description = "Lifecycle policy is defined as HCL"
  nullable    = true
  default     = null
  validation {
    condition     = alltrue([for k, v in coalesce(var.life_cycle_policy, []) : contains(["tagged", "untagged", "any"], v.selection.tagStatus)])
    error_message = "tagStatus must be one of the following: tagged, untagged, or any"
  }

  validation {
    condition     = alltrue([for k, v in coalesce(var.life_cycle_policy, []) : contains(["imageCountMoreThan", "sinceImagePushed", "sinceImagePulled", "sinceImageTransitioned"], v.selection.countType)])
    error_message = "countType must be one of the folllowing: imageCountMoreThan, sinceImagePushed, sinceImagePulled, sinceImageTransitioned"
  }

  validation {
    condition     = alltrue([for k, v in coalesce(var.life_cycle_policy, []) : v.selection.tagStatus != "tagged" || (try(length(v.selection.tagPatternList), 0) > 0 != try(length(v.selection.tagPrefixList), 0) > 0)])
    error_message = "if tagStatus is set to tagged you must define tagPatternList or tagPrefixList"
  }

  validation {
    condition     = alltrue([for k, v in coalesce(var.life_cycle_policy, []) : !startswith(v.selection.countType, "since") || v.selection.countUnit != null])
    error_message = "if the `countType` starts with `since` then countUnit must be defined"
  }

  validation {
    condition     = alltrue([for k, v in coalesce(var.life_cycle_policy, []) : contains(["days"], v.selection.countUnit) || v.selection.countUnit == null])
    error_message = "countUnit must be set to \"\" or days"
  }

  validation {
    condition     = alltrue([for k, v in coalesce(var.life_cycle_policy, []) : v.selection.countType != "sinceImageTransitioned" || v.selection.storageClass == "archive"])
    error_message = "if the `countType` is `sinceImageTransitioned` then the selection of storageClass must be `archive`"
  }

  validation {
    condition     = alltrue([for k, v in coalesce(var.life_cycle_policy, []) : v.selection.countType == "sinceImageTransitioned" || v.selection.storageClass == "standard"])
    error_message = "if the `countType` is not `sinceImageTransitioned` then the selection of storageClass must be `standard`"
  }

  validation {
    condition     = alltrue([for k, v in coalesce(var.life_cycle_policy, []) : contains(["standard", "archive"], v.selection.storageClass)])
    error_message = "storageClass must be set to `standard` or `archive`"
  }

  validation {
    condition     = alltrue([for k, v in coalesce(var.life_cycle_policy, []) : contains(["expire", "transition"], v.action.type)])
    error_message = "action.type must be set to `expire` or `transition`"
  }

  validation {
    condition     = alltrue([for k, v in coalesce(var.life_cycle_policy, []) : v.action.type != "transition" || v.action.targetStorageClass == "archive"])
    error_message = "if action.type is `transition` action.targetStorageClass should be `archive`"
  }

  validation {
    condition     = alltrue([for k, v in coalesce(var.life_cycle_policy, []) : v.selection.countNumber > 0 && floor(v.selection.countNumber) == v.selection.countNumber])
    error_message = "selection.countNumber must be a positive integer"
  }
}

variable "encryption" {
  type        = bool
  description = "Toggle to encrypt ECR"
  default     = true
}

variable "kms_key_arn" {
  type        = string
  description = "AWS KMS ARN for encrypting ECR. Omit for the module to create its own when `encryption` is enabled."
  nullable    = true
  default     = null

  validation {
    condition     = var.kms_key_arn == null || var.encryption
    error_message = "When `kms_key_arn` is not set to null `encryption` must be true"
  }

  validation {
    condition     = var.kms_key_arn == null || var.kms_key_arn != ""
    error_message = "KMS key ARN must be set to `null` or a non-empty string"
  }
  validation {
    condition     = var.kms_key_arn == null || can(regex("^arn:(aws|aws-us-gov|aws-cn):kms:[a-z0-9-]+:[0-9]{12}:key/(mrk-[a-f0-9]{32}|[a-f0-9-]{36})$", var.kms_key_arn))
    error_message = "`kms_key_arn` must be a valid key arn"
  }
}

variable "scan_on_push" {
  type        = bool
  description = "Controls if scanning happens on push"
  default     = true
}

variable "force_delete" {
  type        = bool
  description = "Toggle for ECR force_delete"
  default     = false
}

variable "share_with_account" {
  type        = list(string)
  description = "A list of accounts to share this ECR repository with"
  default     = []
}

variable "tags" {
  type        = map(string)
  description = "A map of tags to apply to applicable resources"
  default     = {}
}
