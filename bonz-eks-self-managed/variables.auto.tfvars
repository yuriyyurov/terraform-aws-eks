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
vpc_id = "vpc-0cd84a72adb38b35c"

# Control plane subnets (public)
control_plane_subnet_ids = [
  "subnet-09c6bf666cc32de74", # bonz-dev-subnet-public1-us-east-1a
  "subnet-05a0eaf28e6b3a036", # bonz-dev-subnet-public2-us-east-1b
]

# Worker node subnets (private) - default for node groups
private_subnet_ids = [
  "subnet-05e10f853964b3405", # bonz-dev-subnet-private1-us-east-1a
  "subnet-033a2601ea48d5bdf", # bonz-dev-subnet-private2-us-east-1b
]

# Public subnets for VoIP/edge nodes (SIP/RTP) - nodes with public IP requirement
# These nodes need direct internet access via Internet Gateway (not NAT Gateway)
public_subnet_ids = [
  "subnet-09c6bf666cc32de74", # bonz-dev-subnet-public1-us-east-1a
  "subnet-05a0eaf28e6b3a036", # bonz-dev-subnet-public2-us-east-1b
]

# Tags
tags = {
  Environment = "dev"
  Project     = "bonz-dev"
  ManagedBy   = "terraform"
}

