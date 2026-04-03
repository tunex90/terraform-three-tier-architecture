# This is the main .tf file where the real infrastructure is created


# Create the VPC

resource "aws_vpc" "ThreeTier-VPC" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name = "ThreeTier-VPC"
  }
}

# Create the six required subnets

resource "aws_subnet" "Web-Public-A" {
  vpc_id     = aws_vpc.ThreeTier-VPC.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-east-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "Web-Public-A"
  }
}

resource "aws_subnet" "Web-Public-B" {
  vpc_id     = aws_vpc.ThreeTier-VPC.id
  cidr_block = "10.0.2.0/24"
  availability_zone = "us-east-1b"
  map_public_ip_on_launch = true

  tags = {
    Name = "Web-Public-B"
  }
}

resource "aws_subnet" "App-Private-A" {
  vpc_id     = aws_vpc.ThreeTier-VPC.id
  cidr_block = "10.0.11.0/24"
  availability_zone = "us-east-1a"
  map_public_ip_on_launch = false

  tags = {
    Name = "App-Private-A"
  }
}

resource "aws_subnet" "App-Private-B" {
  vpc_id     = aws_vpc.ThreeTier-VPC.id
  cidr_block = "10.0.12.0/24"
  availability_zone = "us-east-1b"
  map_public_ip_on_launch = false

  tags = {
    Name = "App-Private-B"
  }
}

resource "aws_subnet" "DB-Private-A" {
  vpc_id     = aws_vpc.ThreeTier-VPC.id
  cidr_block = "10.0.21.0/24"
  availability_zone = "us-east-1a"
  map_public_ip_on_launch = false

  tags = {
    Name = "DB-Private-A"
  }
}

resource "aws_subnet" "DB-Private-B" {
  vpc_id     = aws_vpc.ThreeTier-VPC.id
  cidr_block = "10.0.22.0/24"
  availability_zone = "us-east-1b"
  map_public_ip_on_launch = false

  tags = {
    Name = "DB-Private-B"
  }
}


# Create the internet gateway

resource "aws_internet_gateway" "ThreeTier-IGW" {
  vpc_id = aws_vpc.ThreeTier-VPC.id

  tags = {
    Name = "ThreeTier-IGW"
  }
}

# Create elastic IPs for NAT Gateway

resource "aws_eip" "ThreeTier-eip-A" {
  domain = "vpc"
}

resource "aws_eip" "ThreeTier-eip-B" {
  domain = "vpc"
}

# Create NAT Gateway

resource "aws_nat_gateway" "ThreeTier-NATGW" {
  allocation_id = aws_eip.ThreeTier-eip-A.id
  subnet_id     = aws_subnet.Web-Public-A.id

  tags = {
    Name = "ThreeTier-NATGW"
  }

  # To ensure proper ordering, it is recommended to add an explicit dependency
  # on the Internet Gateway for the VPC.
  depends_on = [aws_internet_gateway.ThreeTier-IGW]
}
# Create the route table for public subnets

resource "aws_route_table" "Public-RT" {
  vpc_id = aws_vpc.ThreeTier-VPC.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.ThreeTier-IGW.id
  }

  tags = {
    Name = "Public-RT"
  }
}

# Create the route table for private subnets

resource "aws_route_table" "Private-RT" {
  vpc_id = aws_vpc.ThreeTier-VPC.id

  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.ThreeTier-NATGW.id
  }

  tags = {
    Name = "Private-RT"
  }
}

# Create route table associations

resource "aws_route_table_association" "Public-RT-association-A" {
  subnet_id      = aws_subnet.Web-Public-A.id
  route_table_id = aws_route_table.Public-RT.id
}

resource "aws_route_table_association" "Public-RT-association-B" {
  subnet_id      = aws_subnet.Web-Public-B.id
  route_table_id = aws_route_table.Public-RT.id
}

resource "aws_route_table_association" "Private-RT-association-A" {
  subnet_id      = aws_subnet.App-Private-A.id
  route_table_id = aws_route_table.Private-RT.id
}

resource "aws_route_table_association" "Private-RT-association-B" {
  subnet_id      = aws_subnet.App-Private-B.id
  route_table_id = aws_route_table.Private-RT.id
}

resource "aws_route_table_association" "Private-RT-association-A2" {
  subnet_id      = aws_subnet.DB-Private-A.id
  route_table_id = aws_route_table.Private-RT.id
}

resource "aws_route_table_association" "Private-RT-association-B2" {
  subnet_id      = aws_subnet.DB-Private-B.id
  route_table_id = aws_route_table.Private-RT.id
}

# Create security groups

# Create Web server security group

resource "aws_security_group" "Web-SG" {
  name        = "Web-SG"
  description = "Allow traffic for the web tier instances"
  vpc_id      = aws_vpc.ThreeTier-VPC.id

  tags = {
    Name = "Web-SG"
  }
}

# Create the security group rules

resource "aws_vpc_security_group_ingress_rule" "allow_ssh" {
  security_group_id = aws_security_group.Web-SG.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 22
  ip_protocol       = "tcp"
  to_port           = 22
}

resource "aws_vpc_security_group_ingress_rule" "allow_http" {
  security_group_id = aws_security_group.Web-SG.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  ip_protocol       = "tcp"
  to_port           = 80
}

resource "aws_vpc_security_group_ingress_rule" "allow_icmp" {
  security_group_id = aws_security_group.Web-SG.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "icmp"
}

resource "aws_vpc_security_group_egress_rule" "allow_all_traffic_ipv4" {
  security_group_id = aws_security_group.Web-SG.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}


# Create App security group

resource "aws_security_group" "App-SG" {
  name        = "App-SG"
  description = "Allow selected traffic into the application instances"
  vpc_id      = aws_vpc.ThreeTier-VPC.id

  tags = {
    Name = "App-SG"
  }
}

# Create the security group rules

resource "aws_vpc_security_group_ingress_rule" "allow_ssh2" {
  security_group_id            = aws_security_group.App-SG.id
  referenced_security_group_id = aws_security_group.Web-SG.id
  from_port                    = 22
  ip_protocol                  = "tcp"
  to_port                      = 22
}

resource "aws_vpc_security_group_ingress_rule" "allow-app-port" {
  security_group_id            = aws_security_group.App-SG.id
  referenced_security_group_id = aws_security_group.Web-SG.id
  from_port                    = 8080
  ip_protocol                  = "tcp"
  to_port                      = 8080
}

resource "aws_vpc_security_group_ingress_rule" "allow_icmp2" {
  security_group_id            = aws_security_group.App-SG.id
  referenced_security_group_id = aws_security_group.Web-SG.id
  ip_protocol                  = "icmp"
}

resource "aws_vpc_security_group_egress_rule" "allow_all_traffic_ipv4-2" {
  security_group_id = aws_security_group.App-SG.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}


# Create the DB security group

resource "aws_security_group" "DB-SG" {
  name        = "DB-SG"
  description = "Allow selected traffic for the DATABASE instances"
  vpc_id      = aws_vpc.ThreeTier-VPC.id

  tags = {
    Name = "DB-SG"
  }
}

# Create the security group rules

resource "aws_vpc_security_group_ingress_rule" "allow_ssh3" {
  security_group_id            = aws_security_group.DB-SG.id
  referenced_security_group_id = aws_security_group.App-SG.id
  from_port                    = 22
  ip_protocol                  = "tcp"
  to_port                      = 22
}

resource "aws_vpc_security_group_ingress_rule" "allow-DB-port" {
  security_group_id            = aws_security_group.DB-SG.id
  referenced_security_group_id = aws_security_group.App-SG.id
  from_port                    = 3306
  ip_protocol                  = "tcp"
  to_port                      = 3306
}

resource "aws_vpc_security_group_ingress_rule" "allow_icmp3" {
  security_group_id            = aws_security_group.DB-SG.id
  referenced_security_group_id = aws_security_group.App-SG.id
  ip_protocol                  = "icmp"
}

resource "aws_vpc_security_group_egress_rule" "allow_all_traffic_ipv4-3" {
  security_group_id = aws_security_group.DB-SG.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}


# Create the AWS instances required to test connectivity


data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

resource "aws_instance" "Bastion-server" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.Web-Public-A.id
  vpc_security_group_ids = [aws_security_group.Web-SG.id]
  key_name               = var.key_name

  tags = {
    Name = "Bastion-server"
  }
}

resource "aws_instance" "Web-VM" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.Web-Public-B.id
  vpc_security_group_ids = [aws_security_group.Web-SG.id]
  key_name               = var.key_name

  tags = {
    Name = "Web-VM"
  }
}

resource "aws_instance" "App-VM" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.App-Private-A.id
  vpc_security_group_ids = [aws_security_group.App-SG.id]
  key_name               = var.key_name

  tags = {
    Name = "App-VM"
  }
}

resource "aws_instance" "DB-VM" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.DB-Private-A.id
  vpc_security_group_ids = [aws_security_group.DB-SG.id]
  key_name               = var.key_name

  tags = {
    Name = "DB-VM"
  }
}
