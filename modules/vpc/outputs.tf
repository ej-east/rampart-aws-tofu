output "vpc_id" {
  value       = aws_vpc.this.id
  description = "VPC ID this module created"
}

output "availability_zones_used" {
  value       = local.azs
  description = "Availability zones that currently have subnets"
}

output "private_subnet_ids" {
  value       = [for k, v in local.private_subnets : aws_subnet.this[k].id]
  description = "List of private subnets"
}

output "public_subnet_ids" {
  value       = [for k, v in local.public_subnets : aws_subnet.this[k].id]
  description = "List of public subnets"
}

output "isolated_subnet_ids" {
  value       = [for k, v in local.isolated_subnets : aws_subnet.this[k].id]
  description = "List of isolated subnets"
}

output "subnets" {
  value       = aws_subnet.this
  description = "Map of all created subnets"
}

output "private_route_table_ids" {
  value       = [for route in aws_route_table.private : route.id]
  description = "List of all private route tables ids"
}

output "private_route_table_ids_by_az" {
  value       = { for k, route in aws_route_table.private : k => route.id }
  description = "Map of all azs within subnets to private route tables ids"
}

output "public_route_table_id" {
  value       = try(aws_route_table.public[0].id, null)
  description = "Public route table id"
}

output "isolated_route_table_id" {
  value       = try(aws_route_table.isolated[0].id, null)
  description = "Isolated route table id"
}


output "nat_gateway_ids" {
  value       = [for nat in aws_nat_gateway.this : nat.id]
  description = "List of NAT gateway ids"
}

output "nat_gateway_ids_by_az" {
  value       = { for k, nat in aws_nat_gateway.this : k => nat.id }
  description = "Map of all azs to nat ids"
}

output "endpoint_security_group_id" {
  value       = try(aws_security_group.vpc_endpoints[0].id, null)
  description = "AWS Endpoint Security Group ID"
}

output "endpoint_ids" {
  value       = concat([for gateway in aws_vpc_endpoint.gateway : gateway.id], [for interface in aws_vpc_endpoint.interface : interface.id])
  description = "List of AWS VPC Endpoint IDs"
}
