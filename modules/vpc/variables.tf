variable "prefix" {
  type        = string
  description = "Prefix for VPS and some components"
}

variable "cidr" {
  type        = string
  description = "The CIDR to apply to the VPC"

  validation {
    condition     = can(cidrhost(var.cidr, 0))
    error_message = "CIDR must be valid cidr"
  }

  validation {
    condition     = can(cidrcontains("0.0.0.0/0", var.cidr))
    error_message = "cidr must be a valid IPv4 CIDR"
  }
}

variable "az_count" {
  type        = number
  description = "The number of avaibility zones to use, default is 2"
  default     = 2

  validation {
    condition     = var.az_count >= 1
    error_message = "AZ Count must be set to 1 or greater"
  }

  validation {
    condition     = floor(var.az_count) == var.az_count
    error_message = "AZ Count must be a whole number"
  }

  validation {
    condition     = length(data.aws_availability_zones.available.names) >= var.az_count
    error_message = "AZ count cannot exceed the number of available az zones"
  }
}

variable "encrypt_flow_logs" {
  type        = bool
  description = "Encrypt CloudWatch flow logs with a customer-managed KMS key"
  default     = true
}

variable "deny_all_default_security_group" {
  type        = bool
  description = "Create a default security group rule of deny-all. See https://docs.aws.amazon.com/securityhub/latest/userguide/ec2-controls.html#ec2-2 for more details on why"
  default     = true
}

variable "private_mode" {
  type        = bool
  description = "Override creation of the igw and nat across subnets"
  default     = false
}

variable "enable_igw" {
  type        = bool
  description = "Enable IGW for ingress to resources"
  default     = true
}

variable "enable_nat" {
  type        = bool
  description = "Enable NAT for egress from resources"
  default     = true
}

variable "vpc_endpoints" {
  type = object({
    gateway_endpoints   = optional(list(string), ["s3", "dynamodb"])
    interface_endpoints = optional(list(string), ["ecr.api", "ecr.dkr", "sts", "kms", "logs", "ec2", "ssm", "eks"])
  })
  default     = {}
  description = "List of VPC endpoints to enable"
}

variable "flowlogs" {
  type = object({
    traffic_type   = optional(string, "ALL")        # ALL, ACCEPT, REJECT
    destination    = optional(string, "cloudwatch") # cloudwatch, s3 
    retention_days = optional(number, 365)
    s3_bucket_arn  = optional(string)
  })
  default     = {}
  description = "VPC FlowLog configuration"

  validation {
    condition     = contains(["cloudwatch", "s3"], var.flowlogs.destination)
    error_message = "destination must be one of the following: `s3`, `cloudwatch`"
  }

  validation {
    condition     = contains(["ALL", "ACCEPT", "REJECT"], var.flowlogs.traffic_type)
    error_message = "destination must be one of the following: `ALL`, `ACCEPT`, `REJECT`"
  }

  validation {
    condition     = var.flowlogs.destination != "s3" || (var.flowlogs.s3_bucket_arn != null && var.flowlogs.s3_bucket_arn != "")
    error_message = "`s3_bucket_arn` is required when destination is set to `s3`"
  }

  validation {
    condition     = contains([0, 1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653], var.flowlogs.retention_days)
    error_message = "CloudWatch retention must be a valid retention period"
  }

  validation {
    condition     = var.flowlogs.s3_bucket_arn == null || can(regex("^arn:(aws|aws-us-gov|aws-cn):s3:::[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$", var.flowlogs.s3_bucket_arn))
    error_message = "`s3_bucket_arn` must be a valid arn"
  }


}

variable "subnets" {
  type = map(object({
    type    = string # public, private, isolated 
    newbits = number
    netnum  = number
    tags    = optional(map(string), {}) # tags to apply to subnet
  }))
  description = "Subnets under VPC"

  validation {
    condition     = alltrue([for k, v in var.subnets : contains(["public", "private", "isolated"], v.type)])
    error_message = "`type` must be one of the following: `public`, `private`, `isolated`"
  }

  validation {
    condition     = alltrue([for k, v in var.subnets : v.newbits >= 1 && v.newbits <= 16])
    error_message = "`newbits` must be in the following range: 1-16"
  }

  validation {
    condition     = alltrue([for k, v in var.subnets : can(regex("^[a-z0-9-]+$", k))])
    error_message = "subnet keys must be lowercase with hyphens"
  }

  validation {
    condition     = length(var.subnets) >= 1
    error_message = "there must be at least one subnet"
  }

  validation {
    condition     = length(keys(var.subnets)) == length(toset(keys(var.subnets)))
    error_message = "subnet keys must be unique"
  }
}

variable "kms_key_arn" {
  type        = string
  description = "AWS KMS ARN for encrypting CloudWatch flow logs. Omit for the module to create its own when `encrypt_flow_logs` is enabled."
  nullable    = true
  default     = null

  validation {
    condition     = var.kms_key_arn == null || var.kms_key_arn != ""
    error_message = "KMS key ARN must be set to `null` or a non-empty string"
  }
  validation {
    condition     = var.kms_key_arn == null || can(regex("^arn:(aws|aws-us-gov|aws-cn):kms:[a-z0-9-]+:[0-9]{12}:key/(mrk-[a-f0-9]{32}|[a-f0-9-]{36})$", var.kms_key_arn))
    error_message = "`kms_key_arn` must be a valid key arn"
  }
}

variable "tags" {
  type        = map(string)
  description = "Tags to apply to resources created"
  nullable    = false
  default     = {}
}
