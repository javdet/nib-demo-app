# A single VPC across two AZs with three subnet tiers:
#   public    - ALB and the one NAT gateway, each AZ
#   app       - ECS tasks, no public IP, outbound via the NAT gateway
#   database  - RDS, no route to the internet in either direction
#
# One NAT gateway (not one per AZ) is the approved cost trade-off: both app
# subnets share it, so a NAT-gateway AZ failure takes outbound internet access
# with it, but the ALB, ECS and RDS stay reachable on their own AZ's path.

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = local.name
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = local.name
  }
}

# --------------------------------------------------------------- public ----

resource "aws_subnet" "public" {
  count = local.az_count

  vpc_id                  = aws_vpc.main.id
  cidr_block              = local.public_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "${local.name}-public-${var.availability_zones[count.index]}"
    Tier = "public"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${local.name}-public"
  }
}

resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.main.id
}

resource "aws_route_table_association" "public" {
  count = local.az_count

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# ------------------------------------------------------------------ NAT ----
# One gateway, placed in the first public subnet; both app subnets route
# through it.

resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name = "${local.name}-nat"
  }

  depends_on = [aws_internet_gateway.main]
}

resource "aws_nat_gateway" "main" {
  count = var.nat_gateway_count

  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id

  tags = {
    Name = "${local.name}-nat"
  }

  depends_on = [aws_internet_gateway.main]
}

# -------------------------------------------------------------------- app --
# Private: ECS tasks run here with no public IP (see ecs.tf's
# assign_public_ip = false), reaching ECR/Secrets Manager/CloudWatch and the
# internet only through the shared NAT gateway.

resource "aws_subnet" "app" {
  count = local.az_count

  vpc_id                  = aws_vpc.main.id
  cidr_block              = local.app_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = false

  tags = {
    Name = "${local.name}-app-${var.availability_zones[count.index]}"
    Tier = "app"
  }
}

resource "aws_route_table" "app" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${local.name}-app"
  }
}

resource "aws_route" "app_nat" {
  route_table_id         = aws_route_table.app.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.main[0].id
}

resource "aws_route_table_association" "app" {
  count = local.az_count

  subnet_id      = aws_subnet.app[count.index].id
  route_table_id = aws_route_table.app.id
}

# -------------------------------------------------------------- database --
# Isolated: no route out in either direction. RDS is reached only from the
# app subnets over the VPC's local route, which every route table gets
# automatically.

resource "aws_subnet" "database" {
  count = local.az_count

  vpc_id                  = aws_vpc.main.id
  cidr_block              = local.database_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = false

  tags = {
    Name = "${local.name}-database-${var.availability_zones[count.index]}"
    Tier = "database"
  }
}

resource "aws_route_table" "database" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${local.name}-database"
  }
}

resource "aws_route_table_association" "database" {
  count = local.az_count

  subnet_id      = aws_subnet.database[count.index].id
  route_table_id = aws_route_table.database.id
}
