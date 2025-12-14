################################################################################
# VPC Configuration
################################################################################

variable "vpc_name" {
  description = "Name of the VPC"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "vpc_cidr must be a valid CIDR block."
  }
}

variable "region" {
  description = "AWS region where VPC will be created"
  type        = string
}

################################################################################
# Subnet Configuration
################################################################################

variable "subnets" {
  description = <<-EOT
    Map of subnet configurations. Each subnet type can have:
    - prefix: Name prefix for the subnet (e.g., "public", "private", "dmz")
    - number: Number of subnets to create (distributed across AZs)
    - size_of_each_subnet: CIDR prefix length for each subnet (e.g., 24 for /24)
    - nat: (optional) Whether subnets should have NAT gateway access (only for private subnets)
    
    Example:
    subnets = {
      public = {
        prefix              = "public"
        number              = 2
        size_of_each_subnet = 24
      }
      private = {
        prefix              = "private"
        number              = 3
        nat                 = true
        size_of_each_subnet = 24
      }
      dmz = {
        prefix              = "dmz"
        number              = 1
        size_of_each_subnet = 26
      }
    }
  EOT
  type = map(object({
    prefix              = string
    number              = number
    size_of_each_subnet = number
    nat                 = optional(bool, false)
  }))

  validation {
    condition = alltrue([
      for k, v in var.subnets : contains(["public", "private", "dmz"], k)
    ])
    error_message = "Subnet keys must be one of: public, private, dmz."
  }

  validation {
    condition = alltrue([
      for k, v in var.subnets : v.number > 0
    ])
    error_message = "Each subnet must have at least 1 subnet (number > 0)."
  }

  validation {
    condition = alltrue([
      for k, v in var.subnets : v.size_of_each_subnet >= 16 && v.size_of_each_subnet <= 28
    ])
    error_message = "size_of_each_subnet must be between 16 and 28."
  }
}

################################################################################
# VPC Options
################################################################################

variable "enable_dns_hostnames" {
  description = "Enable DNS hostnames in the VPC"
  type        = bool
  default     = true
}

variable "enable_dns_support" {
  description = "Enable DNS support in the VPC"
  type        = bool
  default     = true
}

variable "instance_tenancy" {
  description = "Tenancy option for instances launched into the VPC"
  type        = string
  default     = "default"

  validation {
    condition     = contains(["default", "dedicated", "host"], var.instance_tenancy)
    error_message = "instance_tenancy must be one of: default, dedicated, host."
  }
}

################################################################################
# NAT Gateway Options
################################################################################

variable "single_nat_gateway" {
  description = "Use a single NAT Gateway for all private subnets (cost-effective)"
  type        = bool
  default     = true
}

variable "one_nat_gateway_per_az" {
  description = "Use one NAT Gateway per Availability Zone (high availability)"
  type        = bool
  default     = false
}

################################################################################
# Tags
################################################################################

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "vpc_tags" {
  description = "Additional tags for the VPC"
  type        = map(string)
  default     = {}
}

variable "public_subnet_tags" {
  description = "Additional tags for public subnets"
  type        = map(string)
  default     = {}
}

variable "private_subnet_tags" {
  description = "Additional tags for private subnets"
  type        = map(string)
  default     = {}
}

variable "intra_subnet_tags" {
  description = "Additional tags for intra/DMZ subnets"
  type        = map(string)
  default     = {}
}

################################################################################
# Flow Logs
################################################################################

variable "enable_flow_log" {
  description = "Enable VPC Flow Logs"
  type        = bool
  default     = false
}

variable "flow_log_destination_type" {
  description = "Type of flow log destination. Can be s3, kinesis-data-firehose or cloud-watch-logs"
  type        = string
  default     = "cloud-watch-logs"
}

variable "flow_log_destination_arn" {
  description = "ARN of the destination for VPC Flow Logs"
  type        = string
  default     = ""
}

