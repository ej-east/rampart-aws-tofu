resource "aws_security_group" "vpc_endpoints" {
  count       = length(var.vpc_endpoints.interface_endpoints) >= 1 ? 1 : 0
  name        = "${var.prefix}-vpc-endpoints"
  description = "SG for VPC Endpoints"

  vpc_id = aws_vpc.this.id
  tags = merge(var.tags, {
    Name = "${var.prefix}-vpc-endpoints"
  })
}

resource "aws_vpc_security_group_ingress_rule" "vpc_endpoints_https" {
  count             = length(var.vpc_endpoints.interface_endpoints) >= 1 ? 1 : 0
  security_group_id = aws_security_group.vpc_endpoints[0].id
  description       = "Allow HTTPS from VPC"

  cidr_ipv4   = aws_vpc.this.cidr_block
  ip_protocol = "tcp"
  from_port   = 443
  to_port     = 443
}

resource "aws_vpc_endpoint" "gateway" {
  for_each = toset(var.vpc_endpoints.gateway_endpoints)

  vpc_id            = aws_vpc.this.id
  vpc_endpoint_type = "Gateway"
  service_name      = "com.amazonaws.${data.aws_region.current.region}.${each.value}"

  route_table_ids = concat([for route_table in aws_route_table.private : route_table.id], aws_route_table.isolated[*].id)

  tags = merge(var.tags, {
    Type = "Gateway"
    Name = "${var.prefix}-endpoint-${each.value}"
  })
}

resource "aws_vpc_endpoint" "interface" {
  for_each            = toset(var.vpc_endpoints.interface_endpoints)
  private_dns_enabled = true

  subnet_ids         = [for az, k in local.endpoint_subnet_via_az : aws_subnet.this[k].id]
  security_group_ids = [aws_security_group.vpc_endpoints[0].id]

  vpc_id            = aws_vpc.this.id
  vpc_endpoint_type = "Interface"
  service_name      = "com.amazonaws.${data.aws_region.current.region}.${each.value}"

  tags = merge(var.tags, {
    Type = "Interface"
    Name = "${var.prefix}-endpoint-${each.value}"
  })
}

