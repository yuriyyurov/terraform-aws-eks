################################################################################
# Self-Managed Node Groups Configuration
################################################################################

self_managed_node_groups = {
  # General purpose worker nodes (with Spot instances support)
  general = {
    name = "workers-general"

    # Scaling configuration
    min_size     = 1
    max_size     = 5
    desired_size = 2

    # Instance configuration (base type, overridden by mixed_instances_policy)
    instance_type = "t3.medium"
    ami_type      = "AL2023_x86_64_STANDARD"

    # Network - uses private_subnet_ids from variables.auto.tfvars by default
    # Uncomment to specify custom subnets for this node group:
    # subnet_ids = [
    #   "subnet-0ed313767477cdccf",
    #   "subnet-01260a20ec080d5d6",
    # ]

    # Kubernetes labels
    labels = {
      "workload"    = "general"
      "environment" = "dev"
      "lifecycle"   = "mixed" # on-demand + spot
    }

    # Kubernetes taints (optional)
    # taints = {
    #   dedicated = {
    #     key    = "dedicated"
    #     value  = "general"
    #     effect = "NO_SCHEDULE"
    #   }
    # }

    # Storage configuration
    block_device_mappings = {
      xvda = {
        device_name = "/dev/xvda"
        ebs = {
          volume_size           = 50
          volume_type           = "gp3"
          encrypted             = true
          delete_on_termination = true
        }
      }
    }

    # IMDSv2 configuration (recommended for security)
    metadata_options = {
      http_endpoint               = "enabled"
      http_tokens                 = "required"
      http_put_response_hop_limit = 2
    }

    #---------------------------------------------------------------------------
    # Mixed Instances Policy (On-Demand + Spot)
    #---------------------------------------------------------------------------
    use_mixed_instances_policy = true
    mixed_instances_policy = {
      instances_distribution = {
        # Keep 1 on-demand instance as baseline for stability
        on_demand_base_capacity = 1
        # Above base capacity: 25% on-demand, 75% spot
        on_demand_percentage_above_base_capacity = 25
        # Spot allocation strategy: capacity-optimized reduces interruptions
        spot_allocation_strategy = "capacity-optimized"
      }
      launch_template = {
        # Multiple instance types for better spot availability
        override = [
          { instance_type = "t3.medium" },
          { instance_type = "t3a.medium" },
          { instance_type = "t3.large" },
          { instance_type = "t3a.large" },
        ]
      }
    }

    # Auto-replace spot instances when AWS sends rebalance recommendation
    capacity_rebalance = true

    # Additional tags for this node group
    tags = {
      NodeGroup = "general"
      Purpose   = "general-workloads"
      Lifecycle = "mixed"
    }
  }

  # Example: Compute-optimized node group (uncomment to use)
  # compute = {
  #   name = "workers-compute"
  #
  #   min_size     = 0
  #   max_size     = 10
  #   desired_size = 0
  #
  #   instance_type = "c6i.xlarge"
  #   ami_type      = "AL2023_x86_64_STANDARD"
  #
  #   # Custom subnets for this node group
  #   # subnet_ids = ["subnet-xxx", "subnet-yyy"]
  #
  #   labels = {
  #     "workload" = "compute"
  #   }
  #
  #   taints = {
  #     compute = {
  #       key    = "workload"
  #       value  = "compute"
  #       effect = "NO_SCHEDULE"
  #     }
  #   }
  #
  #   block_device_mappings = {
  #     xvda = {
  #       device_name = "/dev/xvda"
  #       ebs = {
  #         volume_size = 100
  #         volume_type = "gp3"
  #         encrypted   = true
  #       }
  #     }
  #   }
  #
  #   tags = {
  #     NodeGroup = "compute"
  #     Purpose   = "compute-intensive-workloads"
  #   }
  # }

  # Example: Memory-optimized node group (uncomment to use)
  # memory = {
  #   name = "workers-memory"
  #
  #   min_size     = 0
  #   max_size     = 5
  #   desired_size = 0
  #
  #   instance_type = "r6i.xlarge"
  #   ami_type      = "AL2023_x86_64_STANDARD"
  #
  #   labels = {
  #     "workload" = "memory"
  #   }
  #
  #   taints = {
  #     memory = {
  #       key    = "workload"
  #       value  = "memory"
  #       effect = "NO_SCHEDULE"
  #     }
  #   }
  #
  #   block_device_mappings = {
  #     xvda = {
  #       device_name = "/dev/xvda"
  #       ebs = {
  #         volume_size = 100
  #         volume_type = "gp3"
  #         encrypted   = true
  #       }
  #     }
  #   }
  #
  #   tags = {
  #     NodeGroup = "memory"
  #     Purpose   = "memory-intensive-workloads"
  #   }
  # }

  # Example: Spot instances with mixed instance policy (uncomment to use)
  # spot = {
  #   name = "workers-spot"
  #
  #   min_size     = 0
  #   max_size     = 20
  #   desired_size = 0
  #
  #   instance_type = "t3.large"
  #   ami_type      = "AL2023_x86_64_STANDARD"
  #
  #   labels = {
  #     "workload"       = "spot"
  #     "lifecycle"      = "spot"
  #   }
  #
  #   taints = {
  #     spot = {
  #       key    = "lifecycle"
  #       value  = "spot"
  #       effect = "NO_SCHEDULE"
  #     }
  #   }
  #
  #   use_mixed_instances_policy = true
  #   mixed_instances_policy = {
  #     instances_distribution = {
  #       on_demand_base_capacity                  = 0
  #       on_demand_percentage_above_base_capacity = 0
  #       spot_allocation_strategy                 = "capacity-optimized"
  #     }
  #     launch_template = {
  #       override = [
  #         { instance_type = "t3.large" },
  #         { instance_type = "t3a.large" },
  #         { instance_type = "m5.large" },
  #         { instance_type = "m5a.large" },
  #       ]
  #     }
  #   }
  #
  #   capacity_rebalance = true
  #
  #   tags = {
  #     NodeGroup = "spot"
  #     Purpose   = "cost-optimized-workloads"
  #   }
  # }
}

