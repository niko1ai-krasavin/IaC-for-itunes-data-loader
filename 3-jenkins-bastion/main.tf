resource "aws_security_group" "sg_for_bastion" {
  name        = "sg_for_bastion"
  description = "Allow SSH access to host"
  vpc_id      = var.id_of_custom_vpc

  ingress {
    description = "SSH access from anywhere"
    from_port   = 22
    to_port     = 22
    protocol    = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "sg_for_jenkins" {
  name        = "sg_for_jenkins"
  description = "Allow HTTP and NFS access to jenkins"
  vpc_id      = var.id_of_custom_vpc

  ingress {
    description = "SSH access from anywhere"
    from_port   = 8080
    to_port     = 8080
    protocol    = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "NFS access in VPC"
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

resource "aws_launch_configuration" "lc_for_jenkins" {
  name          = "lc-for-jenkins"
  image_id      = var.id_of_jenkins_server_image
  instance_type = "t3.medium"
  security_groups = [
    aws_security_group.sg_for_bastion.id,
    aws_security_group.sg_for_jenkins.id
  ]
  associate_public_ip_address = true
  key_name                    = var.name_of_ssh_key_for_host

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "ag_for_jenkins" {
  name                      = "as-group-for-jenkins"
  launch_configuration      = aws_launch_configuration.lc_for_jenkins.name
  vpc_zone_identifier       = [var.id_of_pub_subnet_az_a, var.id_of_pub_subnet_az_b]
  min_size                  = 1
  max_size                  = 1
  desired_capacity          = 1
  health_check_grace_period = 60

  tag {
    key                 = "Name"
    value               = "Jenkins-server"
    propagate_at_launch = true
  }
}
