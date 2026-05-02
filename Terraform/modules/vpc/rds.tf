# ============================================================
#  modules/vpc/rds.tf
#  Creates: RDS Subnet Group, RDS MySQL Instance
# ============================================================

resource "aws_db_subnet_group" "db" {
  name        = "${local.name_prefix}-db-subnet-group"
  description = "Subnet group for RDS MySQL"
  subnet_ids  = aws_subnet.db[*].id

  tags = merge(var.common_tags, {
    Name = "${local.name_prefix}-db-subnet-group"
  })
}

resource "aws_db_instance" "db" {
  identifier        = "${local.name_prefix}-db"
  engine            = "mysql"
  engine_version    = "8.0"
  instance_class    = "db.t3.micro" # Free tier eligible in ap-south-1
  allocated_storage = 20            # Free tier eligible
  storage_type      = "gp2"

  db_name  = "employee_db"
  username = "admin"
  password = "password123"

  db_subnet_group_name   = aws_db_subnet_group.db.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  # Zero Cost & Single AZ Settings
  multi_az            = false
  availability_zone   = var.azs[0] # Pin to the first AZ
  publicly_accessible = false
  skip_final_snapshot = true
  deletion_protection = false

  tags = merge(var.common_tags, {
    Name = "${local.name_prefix}-rds"
  })
}
