// VPC and networking module: creates VPC, subnets, IGW, NAT gateways, route tables and database ACLs

resource "aws_vpc" "this" {
  cidr_block = var.vpc_cidr

  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge({ Name = var.project_name }, var.tags)
}

resource "aws_vpc_ipv4_cidr_block_association" "additional" {
  count = length(var.vpc_additional_cidrs)

  vpc_id     = aws_vpc.this.id
  cidr_block = var.vpc_additional_cidrs[count.index]
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = merge({ Name = var.project_name }, var.tags)
}

resource "aws_subnet" "public" {
  count  = length(var.public_subnets)
  vpc_id = aws_vpc.this.id

  cidr_block        = var.public_subnets[count.index].cidr
  availability_zone = var.public_subnets[count.index].availability_zone

  tags = merge({ Name = var.public_subnets[count.index].name }, var.tags)

  depends_on = [aws_vpc_ipv4_cidr_block_association.additional]
}

resource "aws_route_table" "public_internet_access" {
  vpc_id = aws_vpc.this.id

  tags = merge({ Name = "${var.project_name}-public-access" }, var.tags)
}

resource "aws_route" "public" {
  route_table_id         = aws_route_table.public_internet_access.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
}

resource "aws_route_table_association" "public" {
  count = length(var.public_subnets)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public_internet_access.id
}

resource "aws_eip" "nat" {
  count  = length(var.public_subnets)
  domain = "vpc"

  tags = merge({ Name = format("%s-%s", var.project_name, var.public_subnets[count.index].availability_zone) }, var.tags)
}

resource "aws_nat_gateway" "this" {
  count         = length(var.public_subnets)
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = merge({ Name = format("%s-%s", var.project_name, var.public_subnets[count.index].availability_zone) }, var.tags)
}

resource "aws_subnet" "private" {
  count  = length(var.private_subnets)
  vpc_id = aws_vpc.this.id

  cidr_block        = var.private_subnets[count.index].cidr
  availability_zone = var.private_subnets[count.index].availability_zone

  tags = merge({ Name = var.private_subnets[count.index].name }, var.tags)

  depends_on = [aws_vpc_ipv4_cidr_block_association.additional]
}

resource "aws_route_table" "private" {
  count  = length(var.private_subnets)
  vpc_id = aws_vpc.this.id

  tags = merge({ Name = format("%s-%s", var.project_name, var.private_subnets[count.index].name) }, var.tags)
}

resource "aws_route" "private" {
  count                  = length(var.private_subnets)
  destination_cidr_block = "0.0.0.0/0"

  route_table_id = aws_route_table.private[count.index].id

  gateway_id = aws_nat_gateway.this[
    index(var.public_subnets[*].availability_zone, var.private_subnets[count.index].availability_zone)
  ].id
}

resource "aws_route_table_association" "private" {
  count = length(var.private_subnets)

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

resource "aws_subnet" "database" {
  count  = length(var.database_subnets)
  vpc_id = aws_vpc.this.id

  cidr_block        = var.database_subnets[count.index].cidr
  availability_zone = var.database_subnets[count.index].availability_zone

  tags = merge({ Name = var.database_subnets[count.index].name }, var.tags)

  depends_on = [aws_vpc_ipv4_cidr_block_association.additional]
}

resource "aws_network_acl" "database" {
  vpc_id = aws_vpc.this.id

  egress {
    rule_no    = 200
    protocol   = "-1"
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  tags = merge({ Name = format("%s-databases", var.project_name) }, var.tags)
}

resource "aws_network_acl_rule" "deny" {
  network_acl_id = aws_network_acl.database.id
  rule_number    = 300
  rule_action    = "deny"

  protocol = "-1"

  cidr_block = "0.0.0.0/0"
  from_port  = 0
  to_port    = 0
}

resource "aws_network_acl_association" "database" {
  count = length(var.database_subnets)

  subnet_id      = aws_subnet.database[count.index].id
  network_acl_id = aws_network_acl.database.id
}

resource "aws_network_acl_rule" "allow_3306" {
  count = length(var.private_subnets)

  network_acl_id = aws_network_acl.database.id
  rule_number    = 10 + count.index

  egress = false

  rule_action = "allow"

  protocol = "tcp"

  cidr_block = aws_subnet.private[count.index].cidr_block
  from_port  = 3306
  to_port    = 3306
}

resource "aws_network_acl_rule" "allow_6379" {
  count = length(var.private_subnets)

  network_acl_id = aws_network_acl.database.id
  rule_number    = 20 + count.index

  egress = false

  rule_action = "allow"

  protocol = "tcp"

  cidr_block = aws_subnet.private[count.index].cidr_block
  from_port  = 6379
  to_port    = 6379
}
