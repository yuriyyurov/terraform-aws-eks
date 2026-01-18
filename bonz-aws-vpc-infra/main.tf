################################################################################
# VPC Module
################################################################################

module "vpc" {
  source = "../terraform-aws-vpc"

  name = var.vpc_name
  cidr = var.vpc_cidr

  azs = local.azs

  # Subnet CIDRs (calculated in locals.tf)
  public_subnets  = local.public_subnets
  private_subnets = local.private_subnets
  intra_subnets   = local.intra_subnets

  # Subnet names
  public_subnet_names  = local.public_subnet_names
  private_subnet_names = local.private_subnet_names
  intra_subnet_names   = local.intra_subnet_names

  # DNS settings
  enable_dns_hostnames = var.enable_dns_hostnames
  enable_dns_support   = var.enable_dns_support
  instance_tenancy     = var.instance_tenancy

  ################################################################################
  # Internet Gateway
  ################################################################################
  # Create IGW only if we have public subnets
  create_igw = length(local.public_subnets) > 0

  ################################################################################
  # NAT Gateway
  ################################################################################
  # Enable NAT only if private subnets have nat=true
  enable_nat_gateway = local.enable_nat_gateway

  # NAT Gateway strategy
  single_nat_gateway     = var.single_nat_gateway
  one_nat_gateway_per_az = var.one_nat_gateway_per_az

  # Create route to NAT for private subnets
  create_private_nat_gateway_route = local.enable_nat_gateway

  ################################################################################
  # Default Resources Management
  ################################################################################
  manage_default_network_acl    = true
  manage_default_route_table    = true
  manage_default_security_group = true

  # Default security group - deny all traffic by default
  default_security_group_ingress = []
  default_security_group_egress  = []

  ################################################################################
  # Subnet suffixes for naming
  ################################################################################
  public_subnet_suffix  = local.public_config != null ? local.public_config.prefix : "public"
  private_subnet_suffix = local.private_config != null ? local.private_config.prefix : "private"
  intra_subnet_suffix   = local.dmz_config != null ? local.dmz_config.prefix : "intra"

  ################################################################################
  # VPC Flow Logs
  ################################################################################
  enable_flow_log           = var.enable_flow_log
  flow_log_destination_type = var.flow_log_destination_type
  flow_log_destination_arn  = var.flow_log_destination_arn

  ################################################################################
  # Tags
  ################################################################################
  tags = var.tags

  vpc_tags            = var.vpc_tags
  public_subnet_tags  = var.public_subnet_tags
  private_subnet_tags = var.private_subnet_tags
  intra_subnet_tags   = var.intra_subnet_tags

  igw_tags = {
    Name = "${var.vpc_name}-igw"
  }

  nat_gateway_tags = {
    Name = "${var.vpc_name}-nat"
  }

  nat_eip_tags = {
    Name = "${var.vpc_name}-nat-eip"
  }

  public_route_table_tags = {
    Name = "${var.vpc_name}-public-rt"
  }

  private_route_table_tags = {
    Name = "${var.vpc_name}-private-rt"
  }

  intra_route_table_tags = {
    Name = "${var.vpc_name}-intra-rt"
  }

  default_network_acl_tags = {
    Name = "${var.vpc_name}-default-nacl"
  }

  default_route_table_tags = {
    Name = "${var.vpc_name}-default-rt"
  }

  default_security_group_tags = {
    Name = "${var.vpc_name}-default-sg"
  }
}

################################################################################
# Route53 Hosted Zone
################################################################################

resource "aws_route53_zone" "this" {
  count = var.enable_hosted_zone ? 1 : 0

  name = var.domain_name

  # For private hosted zones, associate with VPC
  dynamic "vpc" {
    for_each = var.hosted_zone_private ? [1] : []
    content {
      vpc_id = module.vpc.vpc_id
    }
  }

  tags = merge(
    var.tags,
    {
      Name = var.domain_name
    }
  )
}

################################################################################
# DHCP Options Set
################################################################################

resource "aws_vpc_dhcp_options" "this" {
  count = var.enable_hosted_zone ? 1 : 0

  domain_name         = var.domain_name
  domain_name_servers = ["AmazonProvidedDNS"]

  tags = merge(
    var.tags,
    {
      Name = "${var.vpc_name}-dhcp-options"
    }
  )
}

resource "aws_vpc_dhcp_options_association" "this" {
  count = var.enable_hosted_zone ? 1 : 0

  vpc_id          = module.vpc.vpc_id
  dhcp_options_id = aws_vpc_dhcp_options.this[0].id
}

