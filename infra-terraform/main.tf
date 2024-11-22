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
          Service = [
            "ec2.amazonaws.com",
            "eks.amazonaws.com"
          ]
        }
      }
    ]
  })
}

##er4
# Attach AdministratorAccess policy to Jenkins CI role
resource "aws_iam_role_policy_attachment" "jenkins_admin_access" {
  role       = aws_iam_role.jenkins_ci.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
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
    subnet_ids              = slice(data.aws_subnets.public_subnets.ids, 0, 2)
    endpoint_private_access = false
    endpoint_public_access  = true
    security_group_ids      = [aws_security_group.jenkins_ci_sg.id]
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

  instance_types = ["t2.large"]

  depends_on = [
    aws_iam_role_policy_attachment.eks_worker_node_policy_ng,
    aws_iam_role_policy_attachment.eks_cni_policy_ng,
    aws_iam_role_policy_attachment.ecs_registry_read_only,
  ]
}

##dww
# Configure aws-auth ConfigMap for EKS to allow Jenkins role access

# # Fetch the EKS cluster details
# data "aws_eks_cluster" "example" {
#   name = aws_eks_cluster.example.name
# }

# # Fetch authentication token for the cluster
# data "aws_eks_cluster_auth" "example" {
#   name = aws_eks_cluster.example.name
# }

# Fetch the current aws-auth ConfigMap
data "kubernetes_config_map" "aws_auth" {
  metadata {
    name      = "aws-auth"
    namespace = "kube-system"
  }

  depends_on = [aws_eks_node_group.example]
}

# Define New role to be added
locals {
  new_role = <<EOT
    - rolearn: ${aws_iam_role.jenkins_ci.arn}
      username: jenkins
      groups:
        - system:masters
EOT

  # Merge the existing roles with the new role
  updated_map_roles = <<EOT
${data.kubernetes_config_map.aws_auth.data["mapRoles"]}
${local.new_role}
EOT
}

# # Update the aws-auth ConfigMap
# resource "kubernetes_config_map" "aws_auth" {
#   metadata {
#     name      = "aws-auth"
#     namespace = "kube-system"
#   }

#   data = {
#     mapRoles = local.updated_map_roles
#   }

# depends_on = [ aws_eks_cluster.example, aws_eks_node_group.example, data.kubernetes_config_map.aws_auth ]
# }
resource "null_resource" "backup_aws_auth" {
  provisioner "local-exec" {
    command = <<EOT
      kubectl get configmap -n kube-system aws-auth -o yaml > aws-auth-backup.yaml
    EOT
  }

  depends_on = [aws_eks_cluster.example, aws_eks_node_group.example]
}

resource "kubernetes_manifest" "aws_auth_patch" {
  provider = kubernetes
  manifest = {
    "apiVersion" = "v1"
    "kind"       = "ConfigMap"
    "metadata" = {
      "name"      = "aws-auth"
      "namespace" = "kube-system"
    }
    "data" = {
      "mapRoles" = "${data.kubernetes_config_map.aws_auth.data["mapRoles"]}${local.new_role}"
    }
  }

  # Ensure this update runs only after the backup and cluster/nodegroup are ready
  depends_on = [
    null_resource.backup_aws_auth, 
    aws_eks_cluster.example, 
    aws_eks_node_group.example
  ]
}

provider "kubernetes" {
  host                   = aws_eks_cluster.example.endpoint
  cluster_ca_certificate = base64decode(aws_eks_cluster.example.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.example.token
}


# #1. In this case, the data source checks the current state of the EKS cluster and allows you to perform actions based on the cluster's availability:
# data "aws_eks_cluster" "example" {
#   name = aws_eks_cluster.example.name
# }

# data "kubernetes_config_map" "aws_auth" {
#   metadata {
#     name      = "aws-auth"
#     namespace = "kube-system"
#   }
# }


# locals {
#   new_role = <<EOT
#     - rolearn: ${aws_iam_role.jenkins_ci.arn}
#       username: jenkins
#       groups:
#         - system:masters
# EOT
# }

# locals {
#   updated_map_roles = "${data.kubernetes_config_map.aws_auth.data["mapRoles"]}${local.new_role}"
# }

# resource "kubernetes_config_map" "aws_auth" {
#   metadata {
#     name      = "aws-auth"
#     namespace = "kube-system"
#   }

#   data = {
#     mapRoles = local.updated_map_roles
#   }
# }





# #2. Configure aws-auth configmap for eks to allow jenkins access
# resource "kubernetes_config_map" "aws_auth" {
#   depends_on = [aws_eks_cluster.example, aws_eks_node_group.example]

#   metadata {
#     name      = "aws-auth"
#     namespace = "kube-system"
#   }

#   data = {
#     mapRoles = jsonencode([
#       {
#         rolearn  = aws_iam_role.jenkins_ci.arn
#         username = "jenkins" #change to preferred username
#         groups   = ["system:masters"]
#       }
#     ])
#   }
# }

# # ---------------------------
# # Kubernetes Provider Configuration
# # ---------------------------

# # Use kubectl and Kubernetes resources
# #   # Ensure the EKS cluster is active before creating the aws-auth config map
# #   lifecycle {
# #     ignore_changes = [
# #       data
# #     ]
# #   }
# # }

