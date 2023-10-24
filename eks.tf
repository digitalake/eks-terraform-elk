module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 19.0"

  cluster_name    = var.eks_cluster_name
  cluster_version = var.eks_cluster_varsion

  cluster_endpoint_public_access = var.eks_cluster_endpoint_public_access

  cluster_addons = var.eks_cluster_addons

  vpc_id                   = module.vpc.vpc_id
  subnet_ids               = module.vpc.private_subnets
  control_plane_subnet_ids = module.vpc.public_subnets

  # EKS Managed Node Group(s)
  eks_managed_node_group_defaults = {
    ami_type       = var.eks_manager_node_group_ami_type
    instance_types = var.eks_managed_node_group_instance_types
  }

  eks_managed_node_groups = var.eks_managed_node_groups

  tags = {
    Terraform = "true"
  }
}