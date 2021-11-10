resource "aws_security_group" "sg_for_rds" {
  name        = "sg_for_rds"
  description = "Allow access to RDS"
  # Variable is used here
  vpc_id = var.id_of_custom_vpc

  ingress {
    description = "Access to RDS from VPC"
    from_port   = 3306
    to_port     = 3306
    protocol    = "TCP"
    cidr_blocks = [
      "10.0.3.0/24",
      "10.0.4.0/24"
      # "10.0.5.0/24"
      # "10.0.6.0/24"
    ]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_db_subnet_group" "custom_db_subnet_group" {
  name = "db_subnet_group_for_rds"
  # Variables are used here
  subnet_ids = [var.id_of_db_subnet_az_a, var.id_of_db_subnet_az_b]
}

resource "aws_db_instance" "mysql_instance" {
  identifier                      = "mysql-itunes-data-loader"
  engine                          = "mysql"
  engine_version                  = "8.0.25"
  instance_class                  = "db.t2.micro"
  db_subnet_group_name            = aws_db_subnet_group.custom_db_subnet_group.name
  enabled_cloudwatch_logs_exports = ["general", "error"]
  # Variables are used here
  name     = var.dbname_for_db_rds
  username = var.username_for_db_rds
  password = var.password_for_db_rds
  # -----------------------
  allocated_storage       = 20
  max_allocated_storage   = 0
  backup_retention_period = 7
  backup_window           = "04:00-04:30"
  maintenance_window      = "Sun:23:00-Sun:23:30"
  storage_type            = "gp2"
  vpc_security_group_ids  = [aws_security_group.sg_for_rds.id]
  skip_final_snapshot     = true
  # If you want to have Multi-AZ deployment (not Free tier)
  multi_az   = false
  depends_on = [aws_security_group.sg_for_rds, aws_db_subnet_group.custom_db_subnet_group]
}
