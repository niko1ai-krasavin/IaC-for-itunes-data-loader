resource "aws_vpc" "custom_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name                                        = "custom-vpc"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }
}

# Create a subnets
resource "aws_subnet" "pub_subnet_in_az_a" {
  vpc_id                  = aws_vpc.custom_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "eu-central-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "pub-subnet-in-az-a"
  }
}

resource "aws_subnet" "pub_subnet_in_az_b" {
  vpc_id                  = aws_vpc.custom_vpc.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "eu-central-1b"
  map_public_ip_on_launch = true

  tags = {
    Name = "pub-subnet-in-az-b"
  }
}

resource "aws_subnet" "eks_pub_subnet_in_az_a" {
  vpc_id                  = aws_vpc.custom_vpc.id
  cidr_block              = "10.0.3.0/24"
  availability_zone       = "eu-central-1a"
  map_public_ip_on_launch = true

  tags = {
    Name                                        = "eks-pub-subnet-in-az-a"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                    = 1
  }
}

resource "aws_subnet" "eks_pub_subnet_in_az_b" {
  vpc_id                  = aws_vpc.custom_vpc.id
  cidr_block              = "10.0.4.0/24"
  availability_zone       = "eu-central-1b"
  map_public_ip_on_launch = true

  tags = {
    Name                                        = "eks-pub-subnet-in-az-b"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                    = 1
  }
}


/* =============================================================================
#  If we use PRIV subnets with NAT Gateway

# Priv subnets for using NAT Gateway
resource "aws_subnet" "eks_priv_subnet_in_az_a" {
  vpc_id            = aws_vpc.custom_vpc.id
  cidr_block        = "10.0.5.0/24"
  availability_zone = "eu-central-1a"

  tags = {
    Name                                        = "eks-priv-subnet-in-az-a"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"           = 1
  }
}

resource "aws_subnet" "eks_priv_subnet_in_az_b" {
  vpc_id            = aws_vpc.custom_vpc.id
  cidr_block        = "10.0.6.0/24"
  availability_zone = "eu-central-1b"

  tags = {
    Name                                        = "eks-priv-subnet-in-az-b"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"           = 1
  }
}
*/

resource "aws_subnet" "db_subnet_in_az_a" {
  vpc_id            = aws_vpc.custom_vpc.id
  cidr_block        = "10.0.7.0/24"
  availability_zone = "eu-central-1a"

  tags = {
    Name = "db-subnet-in-az-a"
  }
}

resource "aws_subnet" "db_subnet_in_az_b" {
  vpc_id            = aws_vpc.custom_vpc.id
  cidr_block        = "10.0.8.0/24"
  availability_zone = "eu-central-1b"

  tags = {
    Name = "db-subnet-in-az-b"
  }
}


# Create an internet gateway
resource "aws_internet_gateway" "igw_for_custom_vpc" {
  vpc_id = aws_vpc.custom_vpc.id

  tags = {
    Name = "igw-for-custom-vpc"
  }
}

/* =============================================================================
#  If we use PRIV subnets with NAT Gateway

# Create Elastic  IP for NAT Gateway
resource "aws_eip" "eip_for_nat" {
  vpc = true
}

# Create NAT Gateway for private subnets
resource "aws_nat_gateway" "gw_nat_for_priv_subnet_in_az_a" {
  allocation_id = aws_eip.eip_for_nat.id
  subnet_id     = aws_subnet.priv_subnet_in_az_a.id

  tags = {
    Name = "gw NAT for priv subnet in AZ a"
  }

  # To ensure proper ordering, it is recommended to add an explicit dependency
  # on the Internet Gateway for the VPC.
  depends_on = [aws_internet_gateway.igw_for_custom_vpc]
}

# Create NAT Gateway for private subnets
resource "aws_nat_gateway" "gw_nat_for_priv_subnet_in_az_b" {
  allocation_id = aws_eip.eip_for_nat.id
  subnet_id     = aws_subnet.priv_subnet_in_az_b.id

  tags = {
    Name = "gw NAT for priv subnet in AZ b"
  }

  # To ensure proper ordering, it is recommended to add an explicit dependency
  # on the Internet Gateway for the VPC.
  depends_on = [aws_internet_gateway.igw_for_custom_vpc]
}
*/

# Create route table for PUB subnets
resource "aws_route_table" "rt_for_pub_subnets_in_custom_vpc" {
  vpc_id = aws_vpc.custom_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw_for_custom_vpc.id
  }

  tags = {
    Name = "rt-for-pub-subnets-in-custom-vpc"
  }
}

# Create route table associations for PUB Subnets
resource "aws_route_table_association" "rt_ass_for_pub_subnet_in_az_a" {
  subnet_id      = aws_subnet.pub_subnet_in_az_a.id
  route_table_id = aws_route_table.rt_for_pub_subnets_in_custom_vpc.id
}

resource "aws_route_table_association" "rt_ass_for_pub_subnet_in_az_b" {
  subnet_id      = aws_subnet.pub_subnet_in_az_b.id
  route_table_id = aws_route_table.rt_for_pub_subnets_in_custom_vpc.id
}

resource "aws_route_table_association" "rt_ass_for_eks_pub_subnet_in_az_a" {
  subnet_id      = aws_subnet.eks_pub_subnet_in_az_a.id
  route_table_id = aws_route_table.rt_for_pub_subnets_in_custom_vpc.id
}

resource "aws_route_table_association" "rt_ass_for_eks_pub_subnet_in_az_b" {
  subnet_id      = aws_subnet.eks_pub_subnet_in_az_b.id
  route_table_id = aws_route_table.rt_for_pub_subnets_in_custom_vpc.id
}

/* =============================================================================
# If we use PRIV subnets with NAT Gateway

# Create route table for PRIV subnet wich is using NAT Gateway
resource "aws_route_table" "rt_for_priv_subnet_in_az_a" {
  vpc_id = aws_vpc.custom_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.gw_nat_for_priv_subnet_in_az_a.id
  }

  tags = {
    Name = "rt-for-priv-subnet-in-az-a"
  }
}

# Create route table for PRIV subnet wich is using NAT Gateway
resource "aws_route_table" "rt_for_priv_subnet_in_az_b" {
  vpc_id = aws_vpc.custom_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.gw_nat_for_priv_subnet_in_az_b.id
  }

  tags = {
    Name = "rt-for-priv-subnet-in-az-b"
  }
}

# Create route table associations for PRIV Subnets
resource "aws_route_table_association" "rt_ass_for_priv_subnet_in_az_a" {
  subnet_id      = aws_subnet.priv_subnet_in_az_a.id
  route_table_id = aws_route_table.rt_for_priv_subnet_in_az_a.id
}

resource "aws_route_table_association" "rt_ass_for_priv_subnet_in_az_b" {
  subnet_id      = aws_subnet.priv_subnet_in_az_b.id
  route_table_id = aws_route_table.rt_for_priv_subnet_in_az_b.id
}
*/
