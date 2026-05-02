variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment name (dev/staging/prod)"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "eks_cluster_name" {
  description = "EKS cluster name — used for required subnet discovery tags"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
}

variable "azs" {
  description = "List of Availability Zones"
  type        = list(string)
}

variable "public_subnet_cidrs" {
  description = "CIDRs for public subnets (one per AZ)"
  type        = list(string)
}

variable "app_subnet_cidrs" {
  description = "CIDRs for private app subnets — EKS nodes (one per AZ)"
  type        = list(string)
}

variable "db_subnet_cidrs" {
  description = "CIDRs for private DB subnets — RDS (one per AZ)"
  type        = list(string)
}

variable "single_nat_gateway" {
  description = "Use single NAT Gateway (dev) or one per AZ (prod)"
  type        = bool
  default     = true
}

variable "common_tags" {
  description = "Common tags applied to all resources"
  type        = map(string)
  default     = {}
}
