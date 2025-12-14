################################################################################
# Local Values - Subnet CIDR Calculation
################################################################################

locals {
  # Get the list of available AZs
  azs = slice(data.aws_availability_zones.available.names, 0, 3)

  # Extract VPC CIDR prefix length (e.g., 16 from "10.0.0.0/16")
  vpc_cidr_prefix = tonumber(split("/", var.vpc_cidr)[1])

  # Get subnet configurations by type
  public_config  = lookup(var.subnets, "public", null)
  private_config = lookup(var.subnets, "private", null)
  dmz_config     = lookup(var.subnets, "dmz", null)

  # Calculate subnet counts
  public_count  = local.public_config != null ? local.public_config.number : 0
  private_count = local.private_config != null ? local.private_config.number : 0
  dmz_count     = local.dmz_config != null ? local.dmz_config.number : 0

  # Total subnets for offset calculation
  total_subnets = local.public_count + local.private_count + local.dmz_count

  # Calculate new bits needed for each subnet type
  # newbits = desired_prefix - vpc_prefix (e.g., for /24 subnet in /16 VPC: 24-16=8)
  public_newbits  = local.public_config != null ? local.public_config.size_of_each_subnet - local.vpc_cidr_prefix : 0
  private_newbits = local.private_config != null ? local.private_config.size_of_each_subnet - local.vpc_cidr_prefix : 0
  dmz_newbits     = local.dmz_config != null ? local.dmz_config.size_of_each_subnet - local.vpc_cidr_prefix : 0

  # Calculate netnum offsets for each subnet type to avoid overlapping CIDRs
  # We need to account for different subnet sizes when calculating offsets

  # Public subnets start at index 0
  public_subnets = local.public_config != null ? [
    for i in range(local.public_count) : cidrsubnet(
      var.vpc_cidr,
      local.public_newbits,
      i
    )
  ] : []

  # Private subnets start after public subnets
  # Calculate the offset based on how many /24-equivalent blocks public subnets take
  private_offset = local.public_count > 0 ? (
    local.public_newbits < local.private_newbits ?
    local.public_count * pow(2, local.private_newbits - local.public_newbits) :
    local.public_count / pow(2, local.public_newbits - local.private_newbits)
  ) : 0

  private_subnets = local.private_config != null ? [
    for i in range(local.private_count) : cidrsubnet(
      var.vpc_cidr,
      local.private_newbits,
      floor(local.private_offset) + i
    )
  ] : []

  # DMZ/Intra subnets start after private subnets
  # Calculate offset considering both public and private subnets
  dmz_offset_from_public = local.public_count > 0 ? (
    local.public_newbits < local.dmz_newbits ?
    local.public_count * pow(2, local.dmz_newbits - local.public_newbits) :
    local.public_count / pow(2, local.public_newbits - local.dmz_newbits)
  ) : 0

  dmz_offset_from_private = local.private_count > 0 ? (
    local.private_newbits < local.dmz_newbits ?
    local.private_count * pow(2, local.dmz_newbits - local.private_newbits) :
    local.private_count / pow(2, local.private_newbits - local.dmz_newbits)
  ) : 0

  dmz_offset = local.dmz_offset_from_public + local.dmz_offset_from_private

  intra_subnets = local.dmz_config != null ? [
    for i in range(local.dmz_count) : cidrsubnet(
      var.vpc_cidr,
      local.dmz_newbits,
      floor(local.dmz_offset) + i
    )
  ] : []

  # Determine if NAT gateway should be enabled
  enable_nat_gateway = local.private_config != null ? lookup(local.private_config, "nat", false) : false

  # Subnet names
  public_subnet_names = local.public_config != null ? [
    for i in range(local.public_count) : "${var.vpc_name}-${local.public_config.prefix}-${element(local.azs, i % length(local.azs))}"
  ] : []

  private_subnet_names = local.private_config != null ? [
    for i in range(local.private_count) : "${var.vpc_name}-${local.private_config.prefix}-${element(local.azs, i % length(local.azs))}"
  ] : []

  intra_subnet_names = local.dmz_config != null ? [
    for i in range(local.dmz_count) : "${var.vpc_name}-${local.dmz_config.prefix}-${element(local.azs, i % length(local.azs))}"
  ] : []
}

