module "ecr" {
  source         = "../../modules/ecr"
  name           = "example"
  tag_mutability = "IMMUTABLE_WITH_EXCLUSION"
  tag_exclusion = [{
    filter = "latest*"
  }]

  life_cycle_policy = [{
    rulePriority = 1
    description  = "Keep last 10 images"
    selection = {
      tagStatus     = "tagged"
      tagPrefixList = ["latest"]
      countType     = "imageCountMoreThan"
      countNumber   = 10
    }
    action = {
      type = "expire"
    }
  }]

  tags = {
    Environment = "prod"
  }

}


output "ecr_id" {
  value = module.ecr.ecr_id
}


output "ecr_arn" {
  value = module.ecr.ecr_arn
}
