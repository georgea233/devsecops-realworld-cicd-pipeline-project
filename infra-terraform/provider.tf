terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0.0"
    }
  }
}

provider "aws" {
  region  = var.aws_region
  # profile = var.profile
}

#rtee
# # Fetching the EKS Cluster Authentication Token
# data "aws_eks_cluster_auth" "example" {
#   name = aws_eks_cluster.example.name

#   # Optional: explicitly set dependencies to ensure EKS cluster is created first
#   depends_on = [aws_eks_cluster.example]
# }

# # Kubernetes Provider configuration (depends on EKS cluster creation)
# provider "kubernetes" {
#   host                   = aws_eks_cluster.example.endpoint
#   cluster_ca_certificate = base64decode(aws_eks_cluster.example.certificate_authority[0].data)
#   token                  = data.aws_eks_cluster_auth.example.token
# }

# ---------------------------
# Data Source to fetch EKS Cluster Authentication Token
# ---------------------------

##er4
#rt5t
