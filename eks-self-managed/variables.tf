################################################################################
# General
################################################################################

variable "aws_profile" {
  description = "AWS CLI profile to use for authentication"
  type        = string
}

variable "aws_region" {
  description = "AWS region for the EKS cluster"
  type        = string
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "kubernetes_version" {
  description = "Kubernetes version for the EKS cluster"
  type        = string
  default     = "1.33"
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}

################################################################################
# Control Plane
################################################################################

variable "control_plane_scaling_config" {
  description = "Configuration block for the EKS Provisioned Control Plane scaling tier. Valid values for tier are 'standard', 'tier-xl', 'tier-2xl', and 'tier-4xl'"
  type = object({
    tier = string
  })
  default = {
    tier = "standard"
  }
}

################################################################################
# VPC & Networking
################################################################################

variable "vpc_id" {
  description = "ID of the existing VPC"
  type        = string
}

variable "control_plane_subnet_ids" {
  description = "List of subnet IDs for the EKS control plane (typically public subnets)"
  type        = list(string)
}

variable "private_subnet_ids" {
  description = "List of subnet IDs for worker nodes (private subnets) - used as default if node group doesn't specify subnet_ids"
  type        = list(string)
}

################################################################################
# Self-Managed Node Groups
################################################################################

variable "self_managed_node_groups" {
  description = "Map of self-managed node group definitions to create"
  type = map(object({
    # Basic configuration
    name         = optional(string)       # Will fall back to map key if not specified
    min_size     = optional(number, 1)
    max_size     = optional(number, 3)
    desired_size = optional(number, 2)

    # Instance configuration
    instance_type = optional(string, "t3.medium")
    ami_type      = optional(string, "AL2023_x86_64_STANDARD") # AL2023_x86_64_STANDARD, AL2023_ARM_64_STANDARD
    ami_id        = optional(string)                           # Custom AMI ID (optional)

    # Networking
    subnet_ids = optional(list(string)) # If not specified, uses var.private_subnet_ids

    # Kubernetes configuration
    labels = optional(map(string), {})
    taints = optional(map(object({
      key    = string
      value  = optional(string)
      effect = string # NO_SCHEDULE, NO_EXECUTE, or PREFER_NO_SCHEDULE
    })), {})

    # Storage configuration
    block_device_mappings = optional(map(object({
      device_name = optional(string)
      ebs = optional(object({
        delete_on_termination = optional(bool, true)
        encrypted             = optional(bool, true)
        iops                  = optional(number)
        kms_key_id            = optional(string)
        snapshot_id           = optional(string)
        throughput            = optional(number)
        volume_size           = optional(number, 50)
        volume_type           = optional(string, "gp3")
      }))
    })))

    # IAM configuration
    iam_role_additional_policies = optional(map(string), {})

    # Bootstrap configuration (AL2023)
    pre_bootstrap_user_data  = optional(string)
    post_bootstrap_user_data = optional(string)
    cloudinit_pre_nodeadm = optional(list(object({
      content      = string
      content_type = optional(string)
      filename     = optional(string)
      merge_type   = optional(string)
    })))
    cloudinit_post_nodeadm = optional(list(object({
      content      = string
      content_type = optional(string)
      filename     = optional(string)
      merge_type   = optional(string)
    })))

    # Advanced configuration
    use_mixed_instances_policy = optional(bool, false)
    mixed_instances_policy = optional(object({
      instances_distribution = optional(object({
        on_demand_allocation_strategy            = optional(string)
        on_demand_base_capacity                  = optional(number)
        on_demand_percentage_above_base_capacity = optional(number)
        spot_allocation_strategy                 = optional(string)
        spot_instance_pools                      = optional(number)
        spot_max_price                           = optional(string)
      }))
      launch_template = object({
        override = optional(list(object({
          instance_type     = optional(string)
          weighted_capacity = optional(string)
        })))
      })
    }))

    # Capacity and scaling
    capacity_rebalance   = optional(bool, false)
    protect_from_scale_in = optional(bool, false)

    # Metadata options (IMDSv2)
    metadata_options = optional(object({
      http_endpoint               = optional(string, "enabled")
      http_protocol_ipv6          = optional(string)
      http_put_response_hop_limit = optional(number, 2)
      http_tokens                 = optional(string, "required")
      instance_metadata_tags      = optional(string)
    }))

    # Tags specific to this node group (merged with global tags)
    tags = optional(map(string), {})
  }))
  default = {}
}

