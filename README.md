# rampart-aws-tofu

## overview

`rampart-aws-tofu` is a set of highly opinionated OpenTofu modules. they are designed to be secure and more importantly compliant by default.

## quick start

`rampart-aws-tofu` is also designed to be easy to get going. to see more examples feel free to look in the `examples/` folder.

a good example of how to get started is with a Virtual Private Cloud (VPC). it's pretty easy to do so with these modules. take a look at the following:

```hcl
provider "aws" {
  region = "us-east-1"
}

module "vpc" {
  source = "git::https://github.com/ej-east/rampart-aws-tofu.git//modules/vpc?ref=main"

  prefix   = "rampart"
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

  tags = {
    Env       = "production"
    ManagedBy = "opentofu"
  }
}

output "vpc_id" {
  value = module.vpc.vpc_id
}

output "private_subnet_ids" {
  value = module.vpc.private_subnet_ids
}
```

here we have defined a VPC with two public subnets and two private subnets. we collect, encrypt, and keep flowlogs for 90 days. we've also defined a few VPC endpoints so that way we don't have to go to the internet to interact with certain parts of AWS. finally we've defined tags to be applied to all resources created.

say that you need a database subnet. this is a subnet that should be accessible from a private one but shouldn't be able to access the internet. you can just set the type to isolated i.e. `type = "isolated"`

## technical overview

### currently implemented

#### ci

there is currently some `ci` implemented. it's not enough for production but will get there. currently we have the following:

| area     | description                                 |
| -------- | ------------------------------------------- |
| lint     | tflint check                                |
| lint     | tofu validate                               |
| lint     | tofu format                                 |
| test     | tofu test (not implemented fully)           |
| security | checkov scan                                |
| security | trufflehog                                  |
| docs     | terraform-docs (gate not fully implemented) |

#### modules

there are some modules currently implemented; more to come. here is the list:

- vpc
- ecr

you can find them under the `modules/` folder or see examples under `examples/`

### planned

lots of work is being done all the time. here is an idea of what modules i have in store and other work that needs to be done. these are not in order.

| area    | description                                   |
| ------- | --------------------------------------------- |
| testing | add tests for `tofu test`                     |
| testing | add tests for `examples`                      |
| tooling | add pre-commit checks                         |
| module  | add module kms                                |
| module  | add module s3                                 |
| module  | add module ec2                                |
| module  | add module eks                                |
| module  | convert some checks to blocking preconditions |
| docs    | add terraform docs per module                 |
| docs    | add SECURITY.md & CODEOWNERS                  |
| release | add releases                                  |
