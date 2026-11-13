data "aws_availability_zones" "available" {
  state = "available"
}
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = { Name = "${var.project}-vpc" }
}
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "${var.project}-igw" }
}
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = false
  tags                    = { Name = "${var.project}-public" }
}

resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = data.aws_availability_zones.available.names[0]
  tags              = { Name = "${var.project}-private" }
}
resource "aws_eip" "nat" {
  domain = "vpc"
}
resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public.id
  depends_on    = [aws_internet_gateway.igw]
}
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }
}
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}
resource "aws_route_table_association" "private" {
  subnet_id = aws_subnet.private.id

  route_table_id = aws_route_table.private.id
}
# Strip every rule from the default SG so nothing can use it by accident
resource "aws_default_security_group" "default" {
  vpc_id = aws_vpc.main.id
}
locals {
  public_rules = {
    "in-100"  = { egress = false, rule = 100, from = 80, to = 80, cidr = "0.0.0.0/0" }
    "in-110"  = { egress = false, rule = 110, from = 1024, to = 65535, cidr = "0.0.0.0/0" }
    "in-120"  = { egress = false, rule = 120, from = 9100, to = 9100, cidr = "10.0.2.0/24" }
    "in-130"  = { egress = false, rule = 130, from = 443, to = 443, cidr = "10.0.2.0/24" }
    "out-100" = { egress = true, rule = 100, from = 80, to = 80, cidr = "0.0.0.0/0" }
    "out-110" = { egress = true, rule = 110, from = 443, to = 443, cidr = "0.0.0.0/0" }
    "out-120" = { egress = true, rule = 120, from = 1024, to = 65535, cidr = "0.0.0.0/0" }
  }
  private_rules = {
    "in-100"  = { egress = false, rule = 100, from = 1024, to = 65535, cidr = "0.0.0.0/0" }
    "out-100" = { egress = true, rule = 100, from = 443, to = 443, cidr = "0.0.0.0/0" }
    "out-110" = { egress = true, rule = 110, from = 80, to = 80, cidr = "0.0.0.0/0" }
    "out-120" = { egress = true, rule = 120, from = 9100, to = 9100, cidr = "10.0.1.0/24" }
  }
}
resource "aws_network_acl" "public" {
  vpc_id     = aws_vpc.main.id
  subnet_ids = [aws_subnet.public.id]
  tags       = { Name = "${var.project}-public-nacl" }
}

resource "aws_network_acl_rule" "public" {
  for_each       = local.public_rules
  network_acl_id = aws_network_acl.public.id
  rule_number    = each.value.rule
  egress         = each.value.egress
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = each.value.cidr
  from_port      = each.value.from
  to_port        = each.value.to
}
resource "aws_network_acl" "private" {
  vpc_id     = aws_vpc.main.id
  subnet_ids = [aws_subnet.private.id]
  tags       = { Name = "${var.project}-private-nacl" }
}
resource "aws_network_acl_rule" "private" {
  for_each       = local.private_rules
  network_acl_id = aws_network_acl.private.id
  rule_number    = each.value.rule
  egress         = each.value.egress
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = each.value.cidr
  from_port      = each.value.from
  to_port        = each.value.to
}