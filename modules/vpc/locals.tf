locals {
  cidr_prefix = tonumber(split("/", var.cidr)[1])
  azs         = slice(data.aws_availability_zones.available.names, 0, var.az_count)
  subnets = merge([
    for k, v in var.subnets : {
      for az_i, az in local.azs :
      "${k}-${az}" => {
        type    = v.type
        newbits = v.newbits
        tags    = v.tags
        netnum  = v.netnum + az_i
        az      = az
      }
    }
  ]...)

  subnet_cidrs = { for k, v in local.subnets : k => cidrsubnet(var.cidr, v.newbits, v.netnum) }
  subnet_keys  = sort(keys(local.subnet_cidrs))


  subnet_overlaps = flatten([
    for i, left_key in local.subnet_keys : [
      for j, right_key in local.subnet_keys :
      "${left_key} (${local.subnet_cidrs[left_key]}) overlaps ${right_key} (${local.subnet_cidrs[right_key]})"
      if i < j && (
        cidrcontains(local.subnet_cidrs[left_key], cidrhost(local.subnet_cidrs[right_key], 0)) ||
        cidrcontains(local.subnet_cidrs[right_key], cidrhost(local.subnet_cidrs[left_key], 0))
      )
    ]
  ])

  public_subnets   = { for k, v in local.subnets : k => v if v.type == "public" }
  private_subnets  = { for k, v in local.subnets : k => v if v.type == "private" }
  isolated_subnets = { for k, v in local.subnets : k => v if v.type == "isolated" }

  subnets_grouped_via_az = { for az in local.azs : az => {
    public   = [for k, v in local.subnets : k if v.az == az && v.type == "public"]
    private  = [for k, v in local.subnets : k if v.az == az && v.type == "private"]
    isolated = [for k, v in local.subnets : k if v.az == az && v.type == "isolated"]
  } }

  nat_subnet_via_az = { for az, g in local.azs_with_public : az => g.public[0] }

  azs_with_private  = { for az, subnets in local.subnets_grouped_via_az : az => subnets if length(subnets.private) > 0 }
  azs_with_public   = { for az, subnets in local.subnets_grouped_via_az : az => subnets if length(subnets.public) > 0 }
  azs_with_isolated = { for az, subnets in local.subnets_grouped_via_az : az => subnets if length(subnets.isolated) > 0 }

  endpoint_subnet_via_az = { for az, g in local.subnets_grouped_via_az : az => length(g.private) > 0 ? g.private[0] : g.isolated[0] if length(g.private) > 0 || length(g.isolated) > 0 }

  byok                      = var.kms_key_arn != null
  cloudwatch_log_group_name = "/${var.prefix}/vpc-flowlogs"
  root_arn                  = "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:root"
  cloudwatch_arn            = "arn:${data.aws_partition.current.partition}:logs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:log-group"
}
