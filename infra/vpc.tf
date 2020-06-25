resource aws_vpc vpc {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true

  tags = {
    Name = var.project_name
  }
}

resource aws_subnet subnet_1 {
  vpc_id = aws_vpc.vpc.id

  cidr_block        = "10.0.0.0/24"
  availability_zone = "${var.region}a"

  tags = {
    Name = var.project_name
  }
}

resource aws_subnet subnet_2 {
  vpc_id = aws_vpc.vpc.id

  cidr_block        = "10.0.1.0/24"
  availability_zone = "${var.region}b"

  tags = {
    Name = var.project_name
  }
}

resource aws_internet_gateway internet_gateway {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = var.project_name
  }
}

resource aws_route_table route_table {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.internet_gateway.id
  }

  tags = {
    Name = var.project_name
  }
}

resource aws_route_table_association route_table_association_1 {
  subnet_id      = aws_subnet.subnet_1.id
  route_table_id = aws_route_table.route_table.id
}

resource aws_route_table_association route_table_association_2 {
  subnet_id      = aws_subnet.subnet_2.id
  route_table_id = aws_route_table.route_table.id
}
