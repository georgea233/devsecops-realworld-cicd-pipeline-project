# ---------------------------
# IAM Roles and Policies
# ---------------------------

# IAM Role for Jenkins CI
resource "aws_iam_role" "jenkins_ci" {
  name = var.iam_role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com" # Adjust if necessary for different deployment
        }
      }
    ]
  })
}

# Attach AdministratorAccess policy to Jenkins CI role
resource "aws_iam_role_policy_attachment" "jenkins_admin_access" {
  role       = aws_iam_role.jenkins_ci.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess" # Consider a more restrictive policy if possible
}

# Attach necessary EKS permissions to Jenkins CI role
resource "aws_iam_role_policy_attachment" "eks_full_access" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.jenkins_ci.name
}

resource "aws_iam_role_policy_attachment" "eks_worker_node_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.jenkins_ci.name
}

resource "aws_iam_role_policy_attachment" "eks_cni_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.jenkins_ci.name
}

# Define a custom inline policy for EKS access
resource "aws_iam_policy" "jenkins_eks_policy" {
  name        = "${var.iam_role_name}-eks-policy"
  description = "Custom policy for Jenkins to access EKS resources"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "eks:DescribeCluster",
          "eks:ListClusters",
          "eks:ListNodegroups",
          "eks:DescribeNodegroup",
          "eks:CreateNodegroup",
          "eks:DeleteNodegroup",
          "eks:UpdateNodegroupConfig",
          "eks:UpdateClusterConfig",
          "eks:ListFargateProfiles",
          "eks:DescribeFargateProfile",
          "eks:CreateFargateProfile",
          "eks:DeleteFargateProfile"
        ],
        Resource = "*"
      }
    ]
  })
}

# Attach the custom EKS policy to the Jenkins CI role
resource "aws_iam_role_policy_attachment" "jenkins_eks_policy_attachment" {
  policy_arn = aws_iam_policy.jenkins_eks_policy.arn
  role       = aws_iam_role.jenkins_ci.name
}

# Create an instance profile for Jenkins
resource "aws_iam_instance_profile" "jenkins_instance_profile" {
  name = var.instance_profile_name
  role = aws_iam_role.jenkins_ci.name
}

# ---------------------------
# VPC and Networking
# ---------------------------

# Fetch the default VPC
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "public_subnets" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}


# # Fetch public subnets from the default VPC
# data "aws_subnet" "default_subnet" {
#   id = one(data.aws_subnets.default_subnets.ids)
# }

# Security Group for Jenkins CI
resource "aws_security_group" "jenkins_ci_sg" {
  name        = var.security_group_name
  vpc_id      = data.aws_vpc.default.id
  description = "DevSecOps-Jenkins-CI-SG"

  dynamic "ingress" {
    for_each = var.ingress_rules
    content {
      from_port   = ingress.value.from_port
      to_port     = ingress.value.to_port
      protocol    = ingress.value.protocol
      cidr_blocks = ingress.value.cidr_blocks
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ---------------------------
# EC2 Instance for Jenkins CI
# ---------------------------

# Fetch Ubuntu 22.04 AMI ID
resource "aws_instance" "jenkins_ci" {
  ami                         = data.aws_ami.ubuntu_22_04.id
  instance_type               = var.instance_type
  key_name                    = var.key_name
  iam_instance_profile        = aws_iam_instance_profile.jenkins_instance_profile.name
  user_data                   = file("${path.module}/installations.sh")
  subnet_id                   = element(data.aws_subnets.public_subnets.ids, 0)
  associate_public_ip_address = true
  security_groups             = [aws_security_group.jenkins_ci_sg.id]

  root_block_device {
    volume_size = 50
  }

  tags = {
    Name = var.instance_name
  }
}

# ---------------------------
# IAM Role for EKS Cluster
# ---------------------------

# IAM Policy Document for EKS Cluster Role
data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "eks_cluster" {
  name               = "eks-cluster-cluster"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

# Attach AmazonEKSClusterPolicy to EKS Role
resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster.name
}

# ---------------------------
# EKS Cluster Provisioning
# ---------------------------

resource "aws_eks_cluster" "example" {
  name     = "EKS_Cluster"
  role_arn = aws_iam_role.eks_cluster.arn

  vpc_config {
    subnet_ids = [element(data.aws_subnets.public_subnets.ids, 0)]

    endpoint_private_access = false
    endpoint_public_access  = true

    security_group_ids = [aws_security_group.jenkins_ci_sg.id]
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_policy,
  ]
}

# ---------------------------
# IAM Role for EKS Node Group
# ---------------------------

resource "aws_iam_role" "eks_node_group" {
  name = "eks-node-group-cluster"

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

# Attach necessary policies to EKS Node Group Role
resource "aws_iam_role_policy_attachment" "eks_worker_node_policy_ng" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_node_group.name
}

resource "aws_iam_role_policy_attachment" "eks_cni_policy_ng" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_node_group.name
}

resource "aws_iam_role_policy_attachment" "ecs_registry_read_only" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks_node_group.name
}

# ---------------------------
# Create EKS Node Group
# ---------------------------

resource "aws_eks_node_group" "example" {
  cluster_name    = aws_eks_cluster.example.name
  node_group_name = "Node-Cluster"
  node_role_arn   = aws_iam_role.eks_node_group.arn
  subnet_ids      = [element(data.aws_subnets.public_subnets.ids, 0)]

  scaling_config {
    desired_size = 2
    max_size     = 2
    min_size     = 1
  }

  instance_types = ["t2.xlarge"]

  depends_on = [
    aws_iam_role_policy_attachment.eks_worker_node_policy_ng,
    aws_iam_role_policy_attachment.eks_cni_policy_ng,
    aws_iam_role_policy_attachment.ecs_registry_read_only,
  ]
}







# # IAM Role for Jenkins CI
# resource "aws_iam_role" "jenkins_ci" {
#   name = var.iam_role_name

#   assume_role_policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Action = "sts:AssumeRole"
#         Effect = "Allow"
#         Principal = {
#           Service = "ec2.amazonaws.com"  # Adjust if necessary for different deployment
#         }
#       }
#     ]
#   })
# }

# # Attach AdministratorAccess policy to Jenkins CI role
# resource "aws_iam_role_policy_attachment" "jenkins_ci" {
#   role       = aws_iam_role.jenkins_ci.name
#   policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"  # Consider a more restrictive policy if possible
# }

# # Attach necessary EKS permissions to Jenkins CI role
# resource "aws_iam_role_policy_attachment" "eks_full_access" {
#   policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
#   role       = aws_iam_role.jenkins_ci.name
# }

# resource "aws_iam_role_policy_attachment" "eks_worker_node_policy" {
#   policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
#   role       = aws_iam_role.jenkins_ci.name
# }

# resource "aws_iam_role_policy_attachment" "eks_cni_policy" {
#   policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
#   role       = aws_iam_role.jenkins_ci.name
# }

# # Define a custom inline policy for EKS access
# resource "aws_iam_policy" "jenkins_eks_policy" {
#   name        = "${var.iam_role_name}-eks-policy"
#   description = "Custom policy for Jenkins to access EKS resources"

#   policy = jsonencode({
#     Version = "2012-10-17",
#     Statement = [
#       {
#         Effect = "Allow",
#         Action = [
#           "eks:DescribeCluster",
#           "eks:ListClusters",
#           "eks:ListNodegroups",
#           "eks:DescribeNodegroup",
#           "eks:CreateNodegroup",
#           "eks:DeleteNodegroup",
#           "eks:UpdateNodegroupConfig",
#           "eks:UpdateClusterConfig",
#           "eks:ListFargateProfiles",
#           "eks:DescribeFargateProfile",
#           "eks:CreateFargateProfile",
#           "eks:DeleteFargateProfile"
#         ],
#         Resource = "*"
#       }
#     ]
#   })
# }

# # Attach the custom EKS policy to the Jenkins CI role
# resource "aws_iam_role_policy_attachment" "jenkins_eks_policy_attachment" {
#   policy_arn = aws_iam_policy.jenkins_eks_policy.arn
#   role       = aws_iam_role.jenkins_ci.name
# }

# # Create an instance profile for Jenkins
# resource "aws_iam_instance_profile" "jenkins_instance_profile" {
#   name = var.instance_profile_name
#   role = aws_iam_role.jenkins_ci.name
# }


# # Data source to fetch the default VPC
# data "aws_vpc" "default" {
#   default = true
# }

# # Data source to fetch all subnets in the default VPC
# data "aws_subnet_ids" "default_vpc_subnets" {
#   vpc_id = data.aws_vpc.default.id
# }

# # Data source to find public subnets with mapPublicIpOnLaunch set to true
# data "aws_subnet" "public_subnet" {
#   for_each = toset(data.aws_subnet_ids.default_vpc_subnets.ids)

#   id = each.value

#   filter {
#     name   = "mapPublicIpOnLaunch"
#     values = ["true"]
#   }
# }

# # Security Group for Jenkins CI
# resource "aws_security_group" "jenkins_ci_sg" {
#   name        = var.security_group_name
#   vpc_id      = data.aws_vpc.default.id
#   description = "DevSecOps-Jenkins-CI-SG"

#   dynamic "ingress" {
#     for_each = var.ingress_rules
#     content {
#       from_port   = ingress.value.from_port
#       to_port     = ingress.value.to_port
#       protocol    = ingress.value.protocol
#       cidr_blocks = ingress.value.cidr_blocks
#     }
#   }

#   egress {
#     from_port   = 0
#     to_port     = 0
#     protocol    = "-1"
#     cidr_blocks = ["0.0.0.0/0"]
#   }
# }

# resource "aws_network_interface" "jenkins_network_interface" {
#   subnet_id       = data.aws_subnet.public_subnet[*].id[0]
#   security_groups = [aws_security_group.jenkins_ci_sg.id]
# }

# # EC2 Instance for Jenkins CI
# resource "aws_instance" "jenkins_ci" {
#   ami                         = data.aws_ami.ubuntu_22_04.id
#   instance_type               = var.instance_type
#   key_name                    = var.key_name
#   iam_instance_profile        = aws_iam_instance_profile.jenkins_instance_profile.name
#   associate_public_ip_address = true
#   user_data                   = file("${path.module}/installations.sh")

#   network_interface {
#     network_interface_id = aws_network_interface.jenkins_network_interface.id
#     device_index         = 0
#   }

#   root_block_device {
#     volume_size = 50
#   }

#   tags = {
#     Name = var.instance_name
#   }
# }

# # IAM Policy Document for EKS Cluster Role
# data "aws_iam_policy_document" "assume_role" {
#   statement {
#     effect = "Allow"

#     principals {
#       type        = "Service"
#       identifiers = ["eks.amazonaws.com"]
#     }

#     actions = ["sts:AssumeRole"]
#   }
# }

# # IAM Role for EKS Cluster
# resource "aws_iam_role" "eks_cluster" {
#   name               = "eks-cluster-cluster"
#   assume_role_policy = data.aws_iam_policy_document.assume_role.json
# }

# # Attach AmazonEKSClusterPolicy to EKS Role
# resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
#   policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
#   role       = aws_iam_role.eks_cluster.name
# }

# # EKS Cluster Provisioning
# resource "aws_eks_cluster" "example" {
#   name     = "EKS_Cluster"
#   role_arn = aws_iam_role.eks_cluster.arn

#   vpc_config {
#     vpc_id     = data.aws_vpc.default.id
#     subnet_ids = data.aws_subnet.public_subnet[*].id

#     endpoint_private_access = true
#     # endpoint_public_access  = true

#     security_group_ids = [aws_security_group.jenkins_ci.id]

#   }

#   depends_on = [
#     aws_iam_role_policy_attachment.eks_cluster_policy,
#   ]
# }

# # IAM Role for EKS Node Group
# resource "aws_iam_role" "eks_node_group" {
#   name = "eks-node-group-cluster"

#   assume_role_policy = jsonencode({
#     Statement = [{
#       Action = "sts:AssumeRole"
#       Effect = "Allow"
#       Principal = {
#         Service = "ec2.amazonaws.com"
#       }
#     }]
#     Version = "2012-10-17"
#   })
# }

# # Attach necessary policies to EKS Node Group Role
# resource "aws_iam_role_policy_attachment" "eks_worker_node_policy_ng" {
#   policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
#   role       = aws_iam_role.eks_node_group.name
# }

# resource "aws_iam_role_policy_attachment" "eks_cni_policy_ng" {
#   policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
#   role       = aws_iam_role.eks_node_group.name
# }

# resource "aws_iam_role_policy_attachment" "ecs_registry_read_only" {
#   policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
#   role       = aws_iam_role.eks_node_group.name
# }

# # Create EKS Node Group
# resource "aws_eks_node_group" "example" {
#   cluster_name    = aws_eks_cluster.example.name
#   node_group_name = "Node-Cluster"
#   node_role_arn   = aws_iam_role.eks_node_group.arn
#   subnet_ids      = data.aws_subnets.default.ids

#   scaling_config {
#     desired_size = 2
#     max_size     = 2
#     min_size     = 1
#   }

#   instance_types = ["t2.xlarge"]

#   depends_on = [
#     aws_iam_role_policy_attachment.eks_worker_node_policy_ng,
#     aws_iam_role_policy_attachment.eks_cni_policy_ng,
#     aws_iam_role_policy_attachment.ecs_registry_read_only,
#   ]
# }


# ###343

# # # IAM role for Jenkins CI
# # resource "aws_iam_role" "jenkins_ci" {
# #   name = var.iam_role_name

# #   assume_role_policy = jsonencode({
# #     Version = "2012-10-17"
# #     Statement = [
# #       {
# #         Action = "sts:AssumeRole"
# #         Effect = "Allow"
# #         Principal = {
# #           Service = "ec2.amazonaws.com"
# #         }
# #       }
# #     ]
# #   })
# # }

# # # Attach AdministratorAccess policy to Jenkins CI role
# # resource "aws_iam_role_policy_attachment" "jenkins_ci" {
# #   role       = aws_iam_role.jenkins_ci.name
# #   policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
# # }

# # # Create an instance profile for Jenkins
# # resource "aws_iam_instance_profile" "jenkins_instance_profile" {
# #   name = var.instance_profile_name
# #   role = aws_iam_role.jenkins_ci.name
# # }

# # # VPC data
# # data "aws_vpc" "default" {
# #   default = true
# # }

# # # Subnets data
# # data "aws_subnets" "default" {
# #   filter {
# #     name   = "vpc-id"
# #     values = [data.aws_vpc.default.id]
# #   }
# # }

# # # Security Group for Jenkins CI
# # resource "aws_security_group" "jenkins_ci" {
# #   name        = var.security_group_name
# #   vpc_id      = data.aws_vpc.default.id
# #   description = "DevSecOps-Jenkins-CI-SG"

# #   dynamic "ingress" {
# #     for_each = var.ingress_rules
# #     content {
# #       from_port   = ingress.value.from_port
# #       to_port     = ingress.value.to_port
# #       protocol    = ingress.value.protocol
# #       cidr_blocks = ingress.value.cidr_blocks
# #     }
# #   }

# #   egress {
# #     from_port   = 0
# #     to_port     = 0
# #     protocol    = "-1"
# #     cidr_blocks = ["0.0.0.0/0"]
# #   }
# # }

# # # EC2 Instance for Jenkins CI
# # resource "aws_instance" "jenkins_ci" {
# #   ami                         = data.aws_ami.ubuntu_22_04.id
# #   instance_type               = var.instance_type
# #   subnet_id                   = data.aws_subnets.default.ids[0]
# #   key_name                    = var.key_name
# #   iam_instance_profile        = aws_iam_instance_profile.jenkins_instance_profile.name
# #   vpc_security_group_ids      = [aws_security_group.jenkins_ci.id]
# #   user_data                   = file("${path.module}/installations.sh")
# #   associate_public_ip_address = true

# #   root_block_device {
# #     volume_size = 50
# #   }

# #   tags = {
# #     Name = var.instance_name
# #   }
# # }

# # # IAM Policy Document for EKS Cluster Role
# # data "aws_iam_policy_document" "assume_role" {
# #   statement {
# #     effect = "Allow"

# #     principals {
# #       type        = "Service"
# #       identifiers = ["eks.amazonaws.com"]
# #     }

# #     actions = ["sts:AssumeRole"]
# #   }
# # }

# # # IAM Role for EKS Cluster
# # resource "aws_iam_role" "eks_cluster" {
# #   name               = "eks-cluster-cluster"
# #   assume_role_policy = data.aws_iam_policy_document.assume_role.json
# # }

# # # Attach AmazonEKSClusterPolicy to EKS Role
# # resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
# #   policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
# #   role       = aws_iam_role.eks_cluster.name
# # }

# # # EKS Cluster Provisioning
# # resource "aws_eks_cluster" "example" {
# #   name     = "EKS_Cluster"
# #   role_arn = aws_iam_role.eks_cluster.arn

# #   vpc_config {
# #     subnet_ids = data.aws_subnets.default.ids
# #   }

# #   depends_on = [
# #     aws_iam_role_policy_attachment.eks_cluster_policy,
# #   ]
# # }

# # # IAM Role for EKS Node Group
# # resource "aws_iam_role" "eks_node_group" {
# #   name = "eks-node-group-cluster"

# #   assume_role_policy = jsonencode({
# #     Statement = [{
# #       Action = "sts:AssumeRole"
# #       Effect = "Allow"
# #       Principal = {
# #         Service = "ec2.amazonaws.com"
# #       }
# #     }]
# #     Version = "2012-10-17"
# #   })
# # }

# # # Attach necessary policies to EKS Node Group Role
# # resource "aws_iam_role_policy_attachment" "eks_worker_node_policy" {
# #   policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
# #   role       = aws_iam_role.eks_node_group.name
# # }

# # resource "aws_iam_role_policy_attachment" "eks_cni_policy" {
# #   policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
# #   role       = aws_iam_role.eks_node_group.name
# # }

# # resource "aws_iam_role_policy_attachment" "ecs_registry_read_only" {
# #   policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
# #   role       = aws_iam_role.eks_node_group.name
# # }

# # # Create EKS Node Group
# # resource "aws_eks_node_group" "example" {
# #   cluster_name    = aws_eks_cluster.example.name
# #   node_group_name = "Node-Cluster"
# #   node_role_arn   = aws_iam_role.eks_node_group.arn
# #   subnet_ids      = data.aws_subnets.default.ids

# #   scaling_config {
# #     desired_size = 2
# #     max_size     = 2
# #     min_size     = 1
# #   }

# #   instance_types = ["t2.xlarge"]

# #   depends_on = [
# #     aws_iam_role_policy_attachment.eks_worker_node_policy,
# #     aws_iam_role_policy_attachment.eks_cni_policy,
# #     aws_iam_role_policy_attachment.ecs_registry_read_only,
# #   ]
# # }
