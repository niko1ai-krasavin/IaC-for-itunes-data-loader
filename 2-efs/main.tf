resource "aws_efs_file_system" "jenkins_home_efs" {
  encrypted = true
  tags = {
    Name = "jenkins-home-efs"
  }
}

resource "aws_efs_mount_target" "mt_for_pub_subnet_az_a" {
  file_system_id = aws_efs_file_system.jenkins_home_efs.id
  # Variable is used here
  subnet_id       = var.id_of_pub_subnet_az_a
  security_groups = [aws_security_group.sg_for_efs.id]
  depends_on      = [aws_efs_file_system.jenkins_home_efs, aws_security_group.sg_for_efs]
}

resource "aws_efs_mount_target" "mt_for_pub_subnet_az_b" {
  file_system_id = aws_efs_file_system.jenkins_home_efs.id
  # Variable is used here
  subnet_id       = var.id_of_pub_subnet_az_b
  security_groups = [aws_security_group.sg_for_efs.id]
  depends_on      = [aws_efs_file_system.jenkins_home_efs, aws_security_group.sg_for_efs]
}

resource "aws_security_group" "sg_for_efs" {
  name        = "sg_for_efs"
  description = "Allow NFS inbound traffic"
  # Variable is used here
  vpc_id = var.id_of_custom_vpc

  ingress {
    description = "NFS from hosts"
    from_port   = 2049
    to_port     = 2049
    protocol    = "TCP"
    cidr_blocks = ["10.0.1.0/24", "10.0.2.0/24"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
