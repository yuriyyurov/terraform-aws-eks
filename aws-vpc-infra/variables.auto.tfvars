################################################################################
# VPC Configuration Example
################################################################################

vpc_name    = "bonz-dev"
vpc_cidr    = "172.17.0.0/16"
region      = "us-east-1"
aws_profile = "suadmin"

################################################################################
# Subnet Configuration
################################################################################
# 
# Supported subnet types:
#   - public:  Subnets with Internet Gateway (direct internet access)
#   - private: Subnets with NAT Gateway (outbound internet via NAT)
#   - dmz:     Isolated subnets (no internet access)
#
# Each subnet type supports:
#   - prefix:              Name prefix for the subnet
#   - number:              Number of subnets to create (distributed across AZs)
#   - size_of_each_subnet: CIDR prefix length (e.g., 24 for /24 = 256 IPs)
#   - nat:                 (private only) Enable NAT gateway access
#
################################################################################

subnets = {
  public = {
    prefix              = "public"
    number              = 2
    size_of_each_subnet = 22
  }
  private = {
    prefix              = "private"
    number              = 2
    nat                 = true
    size_of_each_subnet = 22
  }
  dmz = {
    prefix              = "dmz"
    number              = 1
    size_of_each_subnet = 24
  }
}

################################################################################
# VPC Options
################################################################################

enable_dns_hostnames = true
enable_dns_support   = true
instance_tenancy     = "default"

################################################################################
# NAT Gateway Strategy
################################################################################
# single_nat_gateway = true  -> One NAT for all subnets (cost-effective)
# one_nat_gateway_per_az = true -> One NAT per AZ (high availability)

single_nat_gateway     = true
one_nat_gateway_per_az = false

################################################################################
# Tags
################################################################################

tags = {
  Environment = "development"
  ManagedBy   = "terraform"
}

vpc_tags = {
  Purpose = "main-vpc"
}

public_subnet_tags = {
  "kubernetes.io/role/elb" = "1"
}

private_subnet_tags = {
  "kubernetes.io/role/internal-elb" = "1"
}

intra_subnet_tags = {
  Isolation = "true"
}

################################################################################
# Flow Logs (optional)
################################################################################

enable_flow_log = false
# flow_log_destination_type = "cloud-watch-logs"
# flow_log_destination_arn  = "arn:aws:logs:us-east-1:123456789012:log-group:vpc-flow-logs"

