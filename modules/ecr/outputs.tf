output "ecr_id" {
  description = "ECR ID"
  value       = aws_ecr_repository.this.id
}

output "ecr_arn" {
  description = "ECR ARN"
  value       = aws_ecr_repository.this.arn
}

output "ecr_url" {
  description = "ECR URL"
  value       = aws_ecr_repository.this.repository_url
}

output "kms_arn" {
  description = "KMS Key arn"
  value       = try(aws_kms_key.this[0].arn, null)
}

output "kms_id" {
  description = "KMS Key ID"
  value       = try(aws_kms_key.this[0].key_id, null)
}

