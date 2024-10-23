variable "aws_profile" {
  default = "george"
}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "selected" {
  filter {
    name   = "vpc-id"
    values = ["${data.aws_vpc.default.id}"]
  }
}

# variable "access_key" {
#   default = ""
# }

# variable "secret_key" {
#   default = ""
# }

variable "aws_region" {
  default = "us-east-2"
}

variable "aws_eks_cluster_config" {
  default = {
    # "EKS-cluster" = {
    #   eks_cluster_name = "EKS-cluster"
    #   tags = {
    #     "Name" = "EKS-cluster"
    #   }
    # }
  }
}

variable "eks_node_group_config" {
  default = {
    # "node1" = {
    #   eks_cluster_name = "EKS-cluster"
    #   node_group_name  = "mynode"
    #   nodes_iam_role   = "eks-node-group-general1"
    #   tags = {
    #     "Name" = "node1"
    #   }
    # }
  }
}





# variable "aws_profile" {
#   default = "george"
# }



# variable "access_key" {
#   default = ""
# }
# variable "secret_key" {
#   default = ""
# }


# variable "region" {
#   default = "ap-south-1"
# }

# variable "aws_eks_cluster_config" {
#   default = {}
# }
# variable "eks_node_group_config" {
#   default = {}
# }























