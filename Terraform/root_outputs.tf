output "vpc_id" {
  description = "VPC ID — used when creating EKS cluster and RDS"
  value       = module.vpc.vpc_id
}

output "vpc_cidr" {
  description = "VPC CIDR block"
  value       = module.vpc.vpc_cidr
}

output "public_subnet_ids" {
  description = "Public subnet IDs — used for ALB and NAT Gateway"
  value       = module.vpc.public_subnet_ids
}

output "app_subnet_ids" {
  description = "Private app subnet IDs — used for EKS node groups"
  value       = module.vpc.app_subnet_ids
}

output "db_subnet_ids" {
  description = "Private DB subnet IDs — used for RDS subnet group"
  value       = module.vpc.db_subnet_ids
}

output "nat_gateway_ids" {
  description = "NAT Gateway IDs"
  value       = module.vpc.nat_gateway_ids
}

output "internet_gateway_id" {
  description = "Internet Gateway ID"
  value       = module.vpc.internet_gateway_id
}

output "sg_alb_id" {
  description = "Security Group ID for the ALB"
  value       = module.vpc.sg_alb_id
}

output "sg_nodes_id" {
  description = "Security Group ID for EKS worker nodes"
  value       = module.vpc.sg_nodes_id
}

output "sg_rds_id" {
  description = "Security Group ID for RDS MySQL"
  value       = module.vpc.sg_rds_id
}
