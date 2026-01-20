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
vpc_id = "vpc-02cd6ac6167097a01"

# Control plane subnets (public)
control_plane_subnet_ids = [
  "subnet-0421df49996ddace1", # bonz-dev-subnet-public1-us-east-1a
  "subnet-0739da08bd41f1623", # bonz-dev-subnet-public2-us-east-1b
]

# Worker node subnets (private) - default for node groups
private_subnet_ids = [
  "subnet-086ed49666f6a0f04", # bonz-dev-subnet-private1-us-east-1a
  "subnet-047f82639e56e29eb", # bonz-dev-subnet-private2-us-east-1b
]

# Public subnets for VoIP/edge nodes (SIP/RTP) - nodes with public IP requirement
# These nodes need direct internet access via Internet Gateway (not NAT Gateway)
public_subnet_ids = [
  "subnet-0739da08bd41f1623", # bonz-dev-subnet-public1-us-east-1a
  "subnet-0421df49996ddace1", # bonz-dev-subnet-public2-us-east-1b
]

# Tags
tags = {
  Environment = "dev"
  Project     = "bonz-dev"
  ManagedBy   = "terraform"
}

