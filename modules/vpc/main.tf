resource "aws_vpc" "this" {
  cidr_block = var.cidr

  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(var.tags, {
    Name = "${var.prefix}-vpc"
  })

  lifecycle {
    precondition {
      condition     = length(local.subnet_overlaps) == 0
      error_message = "subnet CIDR ranges overlap: ${join(", ", local.subnet_overlaps)}"
    }
  }
}

resource "aws_internet_gateway" "this" {
  count  = var.enable_igw && !var.private_mode ? 1 : 0
  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, {
    Name = "${var.prefix}-igw"
  })
}


resource "aws_default_security_group" "default" {
  count  = var.deny_all_default_security_group ? 1 : 0
  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, {
    Name = "${var.prefix}-default-sg"
  })
}

resource "aws_eip" "nat" {
  for_each = var.enable_nat && !var.private_mode ? local.azs_with_public : {}

  domain = "vpc"
  tags = merge(var.tags, {
    Name = "${var.prefix}-eip-${each.key}"
  })
}

resource "aws_subnet" "this" {
  for_each = local.subnets
  vpc_id   = aws_vpc.this.id

  cidr_block        = local.subnet_cidrs[each.key]
  availability_zone = each.value.az

  tags = merge(var.tags, each.value.tags, {
    Name = "${var.prefix}-subnet-${each.key}"
  })

  lifecycle {
    precondition {
      condition     = (each.value.newbits >= 0 && each.value.newbits == floor(each.value.newbits) && local.cidr_prefix + each.value.newbits <= 32)
      error_message = "subnet ${each.key}: newbits would create an invalid prefix"
    }

    precondition {
      condition     = (each.value.netnum >= 0 && each.value.netnum == floor(each.value.netnum) && each.value.netnum < pow(2, each.value.newbits))
      error_message = "subnet ${each.key}: netnum must be between 0 and ${pow(2, each.value.newbits) - 1}"
    }
  }
}

resource "aws_nat_gateway" "this" {
  for_each = var.enable_nat && !var.private_mode ? local.nat_subnet_via_az : {}

  allocation_id = aws_eip.nat[each.key].id
  subnet_id     = aws_subnet.this[each.value].id

  tags = merge(var.tags, {
    Name = "${var.prefix}-nat-${each.key}"
  })
}

resource "aws_route_table" "public" {
  count  = length(local.public_subnets) >= 1 ? 1 : 0
  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, {
    Name = "${var.prefix}-rt-public"
  })
}

resource "aws_route_table" "private" {
  for_each = local.azs_with_private
  vpc_id   = aws_vpc.this.id

  tags = merge(var.tags, {
    Name = "${var.prefix}-rt-private-${each.key}"
  })
}

resource "aws_route_table" "isolated" {
  count  = length(local.isolated_subnets) >= 1 ? 1 : 0
  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, {
    Name = "${var.prefix}-rt-isolated"
  })
}

resource "aws_route" "public_internet" {
  count                  = var.enable_igw && !var.private_mode ? 1 : 0
  route_table_id         = aws_route_table.public[0].id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this[0].id
}

resource "aws_route" "private_nat" {
  for_each               = var.enable_nat && !var.private_mode ? local.azs_with_private : {}
  route_table_id         = aws_route_table.private[each.key].id
  destination_cidr_block = "0.0.0.0/0"

  nat_gateway_id = aws_nat_gateway.this[each.key].id

  lifecycle {
    precondition {
      condition     = contains(keys(local.azs_with_public), each.key)
      error_message = "NAT is enabled for private subnets but no public subnet exists for ${each.key} az"
    }
  }
}

resource "aws_route_table_association" "public" {
  for_each       = var.enable_igw && !var.private_mode ? local.public_subnets : {}
  subnet_id      = aws_subnet.this[each.key].id
  route_table_id = aws_route_table.public[0].id
}

resource "aws_route_table_association" "isolated" {
  for_each       = local.isolated_subnets
  subnet_id      = aws_subnet.this[each.key].id
  route_table_id = aws_route_table.isolated[0].id
}

resource "aws_route_table_association" "private" {
  for_each       = local.private_subnets
  subnet_id      = aws_subnet.this[each.key].id
  route_table_id = aws_route_table.private[each.value.az].id
}

check "igw" {
  assert {
    condition     = (var.private_mode || !var.enable_igw || contains([for subnet in values(var.subnets) : subnet.type], "public"))
    error_message = "If `enable_igw` is true and `private_mode` is false then a public subnet is required for an igw."
  }
}

check "nat" {
  assert {
    condition     = (var.private_mode || !var.enable_nat || contains([for subnet in values(var.subnets) : subnet.type], "public"))
    error_message = "If `enable_nat` is true and `private_mode` is false then a public subnet is required for NAT."
  }
}

check "vpc_endpoints_gateway" {
  assert {
    condition     = (length(var.vpc_endpoints.gateway_endpoints) == 0 || (contains([for subnet in values(var.subnets) : subnet.type], "private") || contains([for subnet in values(var.subnets) : subnet.type], "isolated")))
    error_message = "If `vpc_endpoints.gateway_endpoints` is not `[]` then either a private subnet or an isolated subnet is required."
  }
}


check "vpc_endpoints_interface" {
  assert {
    condition     = (length(var.vpc_endpoints.interface_endpoints) == 0 || (contains([for subnet in values(var.subnets) : subnet.type], "private") || contains([for subnet in values(var.subnets) : subnet.type], "isolated")))
    error_message = "If `vpc_endpoints.interface_endpoints` is not `[]` then either a private subnet or an isolated subnet is required."
  }
}

check "ensure_igw_for_nat_support" {
  assert {
    condition     = (var.enable_igw || !var.enable_nat)
    error_message = "If `enable_nat` is true then you must set `var.enable_igw` to true as well"
  }
}
