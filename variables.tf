# VPC  module vars

variable "vpc_name" {
  type        = string
  description = "name for primary VPC"
  default     = "syndicate"
}

variable "vpc_cidr" {
  type        = string
  description = "CODR block for primary VPC"
  default     = "10.0.0.0/16"
}

variable "vpc_azs" {
  type        = list(string)
  description = "Avaliability zones for the primary VPC"
  default     = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

variable "vpc_private_subnets" {
  type        = list(string)
  description = "Private subnet CIDRs"
  default     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "vpc_public_subnets" {
  type        = list(string)
  description = "Public subnet CIDRs. Make sure to specify at leats 2 public subnets in two azs for ALB"
  default     = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
}

variable "vpc_enable_nat_gateway" {
  type        = bool
  description = "Enable or disable NAT for private subnets"
  default     = true
}

variable "vpc_enable_single_nat_gateway" {
  type        = bool
  description = "Enable or disable single NAT"
  default     = true
}

variable "vpc_enable_dns_hostnames" {
  type        = bool
  description = "Enable or disable DNS hostnames support"
  default     = true
}

# EKS mosule vars

variable "eks_cluster_name" {
  type        = string
  description = "Define the name for the EKS cluster"
  default     = "my-cluster"
}

variable "eks_cluster_varsion" {
  type        = string
  description = "Define the Kubernetes version to deploy"
  default     = "1.28"
}

variable "eks_cluster_addons" {
  type        = map(any)
  description = "Define the Kubernetes addons to install"
  default = {
    coredns = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent = true
    }
    aws-ebs-csi-driver = {
      most_recent = true
    }
  }
}

variable "eks_manager_node_group_ami_type" {
  type        = string
  description = "Define the ami type"
  default     = "AL2_x86_64"
}

variable "eks_managed_node_group_instance_types" {
  type        = list(string)
  description = "Define avaliable instance types"
  default     = ["t3.medium"]
}

variable "eks_cluster_endpoint_public_access" {
  type        = bool
  description = "Define if cluster endpoint should be visible publicly"
  default     = true
}

variable "eks_managed_node_groups" {
  type = map(object({
    min_size     = number
    max_size     = number
    desired_size = number
  }))
  description = "Define node groups configurations"
  default = {
    primary = {
      min_size     = 1
      max_size     = 4
      desired_size = 2
    },
  }
}
