# ============================================================
#  modules/vpc/main.tf
#  Creates: VPC, Subnets (public/app/db), IGW, NAT GW,
#           Route Tables, Security Groups
# ============================================================

locals {
  name_prefix = "${var.project_name}-${var.environment}"
  az_count    = length(var.azs)

  # Determine how many NAT Gateways to create:
  # single_nat_gateway = true  → 1 NAT GW in first public subnet (dev/cost-saving)
  # single_nat_gateway = false → 1 NAT GW per AZ (prod/HA)
  nat_gateway_count = var.single_nat_gateway ? 1 : local.az_count
}

# ─────────────────────────────────────────
#  VPC
# ─────────────────────────────────────────
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true   # Required for EKS & RDS endpoint resolution
  enable_dns_support   = true

  tags = merge(var.common_tags, {
    Name = "${local.name_prefix}-vpc"
    # EKS requires this tag on the VPC to discover it
    "kubernetes.io/cluster/${var.eks_cluster_name}" = "shared"
  })
}

# ─────────────────────────────────────────
#  Internet Gateway (public traffic entry)
# ─────────────────────────────────────────
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(var.common_tags, {
    Name = "${local.name_prefix}-igw"
  })
}

# ─────────────────────────────────────────
#  PUBLIC SUBNETS
#  → ALB, NAT Gateways live here
# ─────────────────────────────────────────
resource "aws_subnet" "public" {
  count = local.az_count

  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.azs[count.index]
  map_public_ip_on_launch = true   # Instances launched here get a public IP

  tags = merge(var.common_tags, {
    Name = "${local.name_prefix}-public-${var.azs[count.index]}"
    Tier = "public"

    # CRITICAL: AWS Load Balancer Controller uses this tag to find
    # public subnets when creating internet-facing ALBs
    "kubernetes.io/role/elb" = "1"

    # EKS cluster association
    "kubernetes.io/cluster/${var.eks_cluster_name}" = "shared"
  })
}

# ─────────────────────────────────────────
#  PRIVATE APP SUBNETS
#  → EKS worker nodes live here
# ─────────────────────────────────────────
resource "aws_subnet" "app" {
  count = local.az_count

  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.app_subnet_cidrs[count.index]
  availability_zone       = var.azs[count.index]
  map_public_ip_on_launch = false  # Private — no direct internet access

  tags = merge(var.common_tags, {
    Name = "${local.name_prefix}-app-private-${var.azs[count.index]}"
    Tier = "private-app"

    # CRITICAL: AWS LBC uses this tag to find subnets for
    # internal ALBs and NodePort routing
    "kubernetes.io/role/internal-elb" = "1"

    # EKS cluster association — nodes in this subnet join this cluster
    "kubernetes.io/cluster/${var.eks_cluster_name}" = "shared"
  })
}

# ─────────────────────────────────────────
#  PRIVATE DB SUBNETS
#  → RDS MySQL lives here (isolated tier)
# ─────────────────────────────────────────
resource "aws_subnet" "db" {
  count = local.az_count

  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.db_subnet_cidrs[count.index]
  availability_zone       = var.azs[count.index]
  map_public_ip_on_launch = false

  tags = merge(var.common_tags, {
    Name = "${local.name_prefix}-db-private-${var.azs[count.index]}"
    Tier = "private-db"
  })
}

# ─────────────────────────────────────────
#  ELASTIC IPs for NAT Gateways
# ─────────────────────────────────────────
resource "aws_eip" "nat" {
  count  = local.nat_gateway_count
  domain = "vpc"

  tags = merge(var.common_tags, {
    Name = "${local.name_prefix}-nat-eip-${count.index + 1}"
  })

  depends_on = [aws_internet_gateway.main]
}

# ─────────────────────────────────────────
#  NAT GATEWAYS
#  Placed in PUBLIC subnets
#  Allow private subnets → internet (outbound only)
#  e.g. nodes pulling from ECR, OS updates
# ─────────────────────────────────────────
resource "aws_nat_gateway" "main" {
  count = local.nat_gateway_count

  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = merge(var.common_tags, {
    Name = "${local.name_prefix}-nat-gw-${count.index + 1}"
  })

  depends_on = [aws_internet_gateway.main]
}

# ─────────────────────────────────────────
#  ROUTE TABLES
# ─────────────────────────────────────────

# Public route table → routes all traffic to IGW
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = merge(var.common_tags, {
    Name = "${local.name_prefix}-rt-public"
  })
}

# Associate public route table with each public subnet
resource "aws_route_table_association" "public" {
  count = local.az_count

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Private app route table(s) → routes all outbound to NAT Gateway
# If single_nat_gateway = true  → 1 route table, all app subnets use it
# If single_nat_gateway = false → 1 route table per AZ (each uses its own NAT GW)
resource "aws_route_table" "app_private" {
  count  = local.nat_gateway_count
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main[count.index].id
  }

  tags = merge(var.common_tags, {
    Name = "${local.name_prefix}-rt-app-private-${count.index + 1}"
  })
}

# Associate app subnets with private route tables
resource "aws_route_table_association" "app_private" {
  count = local.az_count

  subnet_id = aws_subnet.app[count.index].id
  # If single NAT GW → all app subnets use route table[0]
  # If multi NAT GW → each app subnet uses its AZ-matched route table
  route_table_id = aws_route_table.app_private[
    var.single_nat_gateway ? 0 : count.index
  ].id
}

# DB subnets — NO internet route (fully isolated)
# DB instances only receive inbound from app layer via SG rules
resource "aws_route_table" "db_private" {
  vpc_id = aws_vpc.main.id

  tags = merge(var.common_tags, {
    Name = "${local.name_prefix}-rt-db-private"
  })
}

resource "aws_route_table_association" "db_private" {
  count = local.az_count

  subnet_id      = aws_subnet.db[count.index].id
  route_table_id = aws_route_table.db_private.id
}

# ─────────────────────────────────────────
#  SECURITY GROUPS
# ─────────────────────────────────────────

# SG: ALB
# Allows HTTP/HTTPS from internet
resource "aws_security_group" "alb" {
  name        = "${local.name_prefix}-sg-alb"
  description = "Security group for internet-facing Application Load Balancer"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "Allow HTTP from internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow HTTPS from internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.common_tags, {
    Name = "${local.name_prefix}-sg-alb"
  })
}

# SG: EKS Worker Nodes
# Allows traffic only from ALB SG (no direct internet access)
resource "aws_security_group" "nodes" {
  name        = "${local.name_prefix}-sg-nodes"
  description = "Security group for EKS worker nodes"
  vpc_id      = aws_vpc.main.id

  # Allow inbound from ALB only (HTTP/HTTPS and NodePort range)
  ingress {
    description     = "Allow traffic from ALB"
    from_port       = 0
    to_port         = 65535
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  # Allow node-to-node communication (required by EKS for inter-pod networking)
  ingress {
    description = "Allow node-to-node communication"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
  }

  # Allow EKS control plane to reach nodes (webhooks, etc.)
  ingress {
    description = "Allow EKS control plane communication"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    description = "Allow all outbound (ECR pulls, AWS API calls)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.common_tags, {
    Name = "${local.name_prefix}-sg-nodes"
  })
}

# SG: RDS MySQL
# Allows MySQL port ONLY from EKS node SG
resource "aws_security_group" "rds" {
  name        = "${local.name_prefix}-sg-rds"
  description = "Security group for RDS MySQL - only accessible from EKS nodes"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "Allow MySQL from EKS nodes only"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.nodes.id]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.common_tags, {
    Name = "${local.name_prefix}-sg-rds"
  })
}
