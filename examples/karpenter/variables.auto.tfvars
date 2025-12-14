# AWS Configuration
aws_profile = "suadmin"
aws_region  = "us-east-1"

# Cluster Configuration
cluster_name       = "bonz-dev"
kubernetes_version = "1.33"

# Existing VPC Configuration
vpc_id = "vpc-0615189de3c480655"

# Control plane subnets (public)
control_plane_subnet_ids = [
  "subnet-0488896d249bade3b", # bonz-dev-subnet-public1-us-east-1a
  "subnet-08c430ad8476c5f45", # bonz-dev-subnet-public2-us-east-1b
]

# Worker node subnets (private)
private_subnet_ids = [
  "subnet-0ed313767477cdccf", # bonz-dev-subnet-private1-us-east-1a
  "subnet-01260a20ec080d5d6", # bonz-dev-subnet-private2-us-east-1b
]

# Node Group Configuration
node_instance_types     = ["t3.small"]
node_group_min_size     = 0
node_group_max_size     = 2
node_group_desired_size = 2

# Karpenter Configuration
karpenter_version = "1.6.0"

# Tags
tags = {
  Environment = "dev"
  Project     = "bonz-dev"
  ManagedBy   = "terraform"
}

