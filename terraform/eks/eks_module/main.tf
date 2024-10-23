module "aws_eks_cluster" {
  source = "./modules/aws_eks"

  for_each = var.aws_eks_cluster_config

  eks_cluster_name = each.value.eks_cluster_name
  subnet_ids       = data.aws_subnets.selected.ids
  tags             = each.value.tags
}

module "aws_eks_node_group" {
  source = "./modules/aws_eks_nodegroup"

  for_each = var.eks_node_group_config

  node_group_name  = each.value.node_group_name
  eks_cluster_name = module.aws_eks_cluster[each.value.eks_cluster_name].eks_cluster_name
  subnet_ids       = data.aws_subnets.selected.ids
  nodes_iam_role   = each.value.nodes_iam_role
  tags             = each.value.tags
}

##Infrastructure (VPC, Subnets etc) to host eks cluster and node group would already be created by the time eks cluster is created. so no need for the bleow: 

# # Data source to fetch VPC ID
# data "aws_vpc" "selected" {
#   filter {
#     name   = "isDefault"
#     values = ["true"]
#     # name   = "tag:Name"
#     # values = ["your-vpc-name"]
#   }
# }

# # Data source to fetch subnets
# data "aws_subnets" "selected" {
#   filter {
#     name   = "vpc-id"
#     values = [data.aws_vpc.selected.id]
#   }
# }

# # Fetch subnet IDs
# data "aws_subnet_ids" "selected" {
#   vpc_id = data.aws_vpc.selected.id
# }
