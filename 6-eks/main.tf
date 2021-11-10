resource "aws_security_group" "sg_for_ssh_access_to_eks_nodes" {
  name        = "ssh-access-to-eks-nodes"
  description = "Allow SSH access to eks nodes"
  vpc_id      = var.id_of_custom_vpc

  ingress {
    description = "SSH access from pub subnets in VPC"
    from_port   = 22
    to_port     = 22
    protocol    = "TCP"
    cidr_blocks = ["10.0.1.0/24", "10.0.2.0/24"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    "kubernetes.io/cluster/${var.cluster_name}" = "owned"
  }
}

resource "aws_security_group" "sg_for_rds_access_in_eks" {
  name        = "rds-access-in-eks"
  description = "Allow 3306 port access in eks"
  vpc_id      = var.id_of_custom_vpc

  ingress {
    description = "Port 3306 access"
    from_port   = 3306
    to_port     = 3306
    protocol    = "TCP"
    cidr_blocks = [
      "10.0.3.0/24",
      "10.0.4.0/24",
      "10.0.7.0/24",
      "10.0.8.0/24"
    ]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    "kubernetes.io/cluster/${var.cluster_name}" = "owned"
  }
}

resource "aws_eks_cluster" "custom_eks_cluster" {
  name     = var.cluster_name
  role_arn = aws_iam_role.iam_role_for_eks_cluster.arn

  vpc_config {
    subnet_ids = [
      var.id_of_eks_pub_subnet_az_a,
      var.id_of_eks_pub_subnet_az_b
    ]
  }

  # To enable ControlPlane logging in CloudWatch for EKS Cluster
  enabled_cluster_log_types = ["api", "audit"]

  # Ensure that IAM Role permissions are created before and deleted after EKS Cluster handling.
  # Otherwise, EKS will not be able to properly delete EKS managed EC2 infrastructure such as Security Groups.
  depends_on = [
    aws_iam_role_policy_attachment.attach_AmazonEKSClusterPolicy,
    aws_cloudwatch_log_group.custom_eks_cloudwatch_log_group
  ]
}

# ======================== IAM Role for EKS Cluster
resource "aws_iam_role" "iam_role_for_eks_cluster" {
  name = "iam_role_for_eks_cluster"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "eks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy_attachment" "attach_AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.iam_role_for_eks_cluster.name
}

# ============ for ControlPlane logging in CloudWatch
resource "aws_cloudwatch_log_group" "custom_eks_cloudwatch_log_group" {
  # The log group name format is /aws/eks/<cluster-name>/cluster
  # Reference: https://docs.aws.amazon.com/eks/latest/userguide/control-plane-logs.html
  name              = "/aws/eks/${var.cluster_name}/cluster"
  retention_in_days = 3
}

# ==============================================================================
# ====================== Node group for the service
resource "aws_eks_node_group" "custom_app_eks_node_group" {
  cluster_name    = var.cluster_name
  node_group_name = "itunes_data_loader_node_group"
  node_role_arn   = aws_iam_role.iam_role_for_eks_node_group.arn
  subnet_ids = [
    var.id_of_eks_pub_subnet_az_a,
    var.id_of_eks_pub_subnet_az_b
  ]
  instance_types = ["t3.small"]
  disk_size      = 10

  scaling_config {
    desired_size = 2
    max_size     = 4
    min_size     = 1
  }

  update_config {
    max_unavailable = 1
  }

  remote_access {
    ec2_ssh_key = var.ssh_key_name_for_eks_cluster
    source_security_group_ids = [
      aws_security_group.sg_for_ssh_access_to_eks_nodes.id,
      aws_security_group.sg_for_rds_access_in_eks.id
    ]
  }

  # Ensure that IAM Role permissions are created before and deleted after EKS Node Group handling.
  # Otherwise, EKS will not be able to properly delete EC2 Instances and Elastic Network Interfaces.
  depends_on = [
    aws_eks_cluster.custom_eks_cluster,
    aws_iam_role_policy_attachment.attach_AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.attach_AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.attach_AmazonEC2ContainerRegistryReadOnly,
    aws_security_group.sg_for_ssh_access_to_eks_nodes,
    aws_security_group.sg_for_rds_access_in_eks
  ]
}

# ===================== IAM Role for EKS Node group
resource "aws_iam_role" "iam_role_for_eks_node_group" {
  name = "iam_role_for_custom_eks_node_group"

  assume_role_policy = jsonencode({
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
    Version = "2012-10-17"
  })
}

resource "aws_iam_role_policy_attachment" "attach_AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.iam_role_for_eks_node_group.name
}

resource "aws_iam_role_policy_attachment" "attach_AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.iam_role_for_eks_node_group.name
}

resource "aws_iam_role_policy_attachment" "attach_AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.iam_role_for_eks_node_group.name
}

/*
resource "aws_autoscaling_group" "ag_for_node_group_eks" {
  max_size             = 4
  min_size             = 1
  desired_capacity     = 2
  launch_configuration = aws_launch_configuration.lc_for_node_group_eks.name
  vpc_zone_identifier  = [var.id_of_pub_subnet_az_a, var.id_of_pub_subnet_az_b]
  lifecycle {
    create_before_destroy = true
  }

  depends_on = [aws_launch_configuration.lc_for_node_group_eks]

  tag {
    key                 = "kubernetes.io/cluster/${var.cluster_name}"
    value               = "owned"
    propagate_at_launch = true
  }

  tag {
    key                 = "k8s.io/cluster-autoscaler/${var.cluster_name}"
    value               = "owned"
    propagate_at_launch = true
  }

  tag {
    key                 = "k8s.io/cluster-autoscaler/enabled"
    value               = true
    propagate_at_launch = true
  }


  # "k8s.io/cluster-autoscaler/${var.cluster_name}" = "owned"
  # "k8s.io/cluster-autoscaler/enabled"             = "true"
  # "propagate_at_launch"                           = "true"
  tags = {
    "kubernetes.io/cluster/${var.cluster_name}" = "owned"
  }

}


resource "aws_launch_configuration" "lc_for_node_group_eks" {
  name_prefix   = "Launch Config for node group eks"
  image_id      = "ami-047e03b8591f2d48a"
  instance_type = "t3.small"
  key_name      = var.ssh_key_name_for_eks_cluster
  security_groups = [
    aws_security_group.sg_for_ssh_access_to_eks_nodes.id,
    aws_security_group.sg_for_p3306_access_to_eks_nodes.id
  ]
  # If we use node_group in Pub subnets
  associate_public_ip_address = true
  root_block_device {
    volume_type = "gp2"
    volume_size = 10
    encrypted   = false
  }
  depends_on = [aws_security_group.sg_for_ssh_access_to_eks_nodes, aws_security_group.sg_for_p3306_access_to_eks_nodes]
}

resource "aws_cloudwatch_metric_alarm" "cpuover60" {
  alarm_name                = "cpu_over_60"
  comparison_operator       = "GreaterThanThreshold"
  evaluation_periods        = "2"
  metric_name               = "CPUUtilization"
  namespace                 = "AWS/EC2"
  period                    = "60"
  statistic                 = "Average"
  threshold                 = "60"
  alarm_description         = "This metric monitors ec2 cpu util"
  insufficient_data_actions = []
  alarm_actions             = [aws_autoscaling_policy.scale_up_one.arn]
}

resource "aws_cloudwatch_metric_alarm" "cpuunder20" {
  alarm_name                = "cpu_under_20"
  comparison_operator       = "LessThanOrEqualToThreshold"
  evaluation_periods        = "2"
  metric_name               = "CPUUtilization"
  namespace                 = "AWS/EC2"
  period                    = "60"
  statistic                 = "Average"
  threshold                 = "20"
  alarm_description         = "This metric monitors ec2 cpu util"
  insufficient_data_actions = []
  alarm_actions             = [aws_autoscaling_policy.scale_down_one.arn]
}

resource "aws_autoscaling_policy" "scale_up_one" {
  name                   = "policy_add_one"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.ag_for_node_group_eks.name
}

resource "aws_autoscaling_policy" "scale_down_one" {
  name                   = "policy_delete_one"
  scaling_adjustment     = -1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.ag_for_node_group_eks.name
}

*/
