# AWS Configuration
aws_profile = "suadmin"
aws_region  = "us-east-1"

# Cluster Configuration
cluster_name       = "bonz-dev"
kubernetes_version = "1.33"

# Control Plane Configuration
control_plane_scaling_config = {
  tier = "standard"
}

# Existing VPC Configuration
vpc_id = "vpc-0615189de3c480655"

# Control plane subnets (public)
control_plane_subnet_ids = [
  "subnet-0488896d249bade3b", # bonz-dev-subnet-public1-us-east-1a
  "subnet-08c430ad8476c5f45", # bonz-dev-subnet-public2-us-east-1b
]

# Worker node subnets (private) - default for node groups
private_subnet_ids = [
  "subnet-0ed313767477cdccf", # bonz-dev-subnet-private1-us-east-1a
  "subnet-01260a20ec080d5d6", # bonz-dev-subnet-private2-us-east-1b
]

# Public subnets for VoIP/edge nodes (SIP/RTP) - nodes with public IP requirement
# These nodes need direct internet access via Internet Gateway (not NAT Gateway)
public_subnet_ids = [
  "subnet-0488896d249bade3b", # bonz-dev-subnet-public1-us-east-1a
  "subnet-08c430ad8476c5f45", # bonz-dev-subnet-public2-us-east-1b
]

# Tags
tags = {
  Environment = "dev"
  Project     = "bonz-dev"
  ManagedBy   = "terraform"
}

