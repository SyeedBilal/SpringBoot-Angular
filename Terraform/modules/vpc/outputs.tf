output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "vpc_cidr" {
  description = "VPC CIDR block"
  value       = aws_vpc.main.cidr_block
}

output "public_subnet_ids" {
  description = "Public subnet IDs — pass to ALB and NAT Gateway"
  value       = aws_subnet.public[*].id
}

output "app_subnet_ids" {
  description = "Private app subnet IDs — pass to EKS node groups"
  value       = aws_subnet.app[*].id
}

output "db_subnet_ids" {
  description = "Private DB subnet IDs — pass to RDS subnet group"
  value       = aws_subnet.db[*].id
}

output "nat_gateway_ids" {
  description = "NAT Gateway IDs"
  value       = aws_nat_gateway.main[*].id
}

output "internet_gateway_id" {
  description = "Internet Gateway ID"
  value       = aws_internet_gateway.main.id
}

output "sg_alb_id" {
  description = "ALB Security Group ID"
  value       = aws_security_group.alb.id
}

output "sg_nodes_id" {
  description = "EKS Nodes Security Group ID"
  value       = aws_security_group.nodes.id
}

output "sg_rds_id" {
  description = "RDS Security Group ID"
  value       = aws_security_group.rds.id
}
