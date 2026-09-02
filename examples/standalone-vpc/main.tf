module "vpc" {
  source = "../../modules/vpc"

  prefix   = "example"
  az_count = 2
  cidr     = "10.0.0.0/16"

  flowlogs = {
    traffic_type   = "ALL"
    destination    = "cloudwatch"
    retention_days = 90
  }

  subnets = {
    public = {
      type    = "public"
      newbits = 8
      netnum  = 0
    }
    private = {
      type    = "private"
      newbits = 4
      netnum  = 1
    }
  }

  vpc_endpoints = {
    gateway_endpoints   = ["s3"]
    interface_endpoints = ["ecr.api", "ecr.dkr", "sts", "kms", "logs", "ec2", "ssm", "eks"]
  }

  tags = {}
}

output "vpc_id" {
  value = module.vpc.vpc_id
}

output "private_subnet_ids" {
  value = module.vpc.private_subnet_ids
}
