################################################################################
# Self-Managed Node Groups Configuration
################################################################################

self_managed_node_groups = {
  # General purpose worker nodes (with Spot instances support)
  general = {
    name = "workers-general"

    # Scaling configuration
    min_size     = 0
    max_size     = 6
    desired_size = 6

    # Instance configuration (base type, overridden by mixed_instances_policy)
    instance_type = "c7i-flex.large"
    ami_type      = "AL2023_x86_64_STANDARD"

    # Network - uses private_subnet_ids from variables.auto.tfvars by default
    # Uncomment to specify custom subnets for this node group:
    subnet_ids = [
      "subnet-05e10f853964b3405",
      "subnet-033a2601ea48d5bdf",
    ]

    # Kubernetes labels
    labels = {
      "workload"    = "general"
      "environment" = "dev"
      "lifecycle"   = "mixed" # on-demand + spot
    }

    # Kubernetes taints (optional)
    taints = {
      dedicated = {
        key    = "dedicated"
        value  = "general"
        effect = "NO_SCHEDULE"
      }
    }

    # Apply labels and taints via NodeConfig (required for AL2023 self-managed nodes)
    cloudinit_pre_nodeadm = [{
      content_type = "application/node.eks.aws"
      content      = <<-EOT
        ---
        apiVersion: node.eks.aws/v1alpha1
        kind: NodeConfig
        spec:
          kubelet:
            flags:
              - --node-labels=workload=general,environment=dev,lifecycle=mixed
            config:
              registerWithTaints:
                - key: dedicated
                  value: general
                  effect: NoSchedule
      EOT
    }]

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
          { instance_type = "c7i-flex.large" },
          { instance_type = "m7i-flex.xlarge" },
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

  #=============================================================================
  # VoIP Edge Nodes - SIP Signaling (Jambonz SBC-SIP DaemonSet)
  #=============================================================================
  # These nodes run with hostNetwork: true and need public IP for SIP traffic
  # DaemonSet uses nodeSelector: voip-environment: sip
  #
  # Components deployed here:
  #   - drachtio (SIP signaling server)
  #   - sbc-sip-sidecar (registrar, OPTIONS handler)
  #   - smpp (SMS gateway)
  #=============================================================================
  voip-sip = {
    name = "voip-sip"

    # Scaling configuration - typically 1 node per AZ for HA
    min_size     = 1
    max_size     = 1
    desired_size = 1

    # Compute-optimized instance for SIP signaling
    # Minimum recommended: 2 vCPU, 4GB RAM
    instance_type = "c7i-flex.large"
    ami_type      = "AL2023_x86_64_STANDARD"

    # IMPORTANT: Public subnet for direct internet access via Internet Gateway
    # VoIP traffic cannot go through NAT Gateway (SIP embeds IP in headers)
    subnet_ids = [
      "subnet-05a0eaf28e6b3a036",
      "subnet-09c6bf666cc32de74" # bonz-dev-subnet-public1-us-east-1a
    ]

    # Network interface with public IP assignment
    # This is required for SIP - carriers need to reach this node directly
    network_interfaces = [{
      associate_public_ip_address = true
      device_index                = 0
      delete_on_termination       = true
      description                 = "Primary ENI for SIP node with public IP"
    }]

    # Kubernetes labels for DaemonSet nodeSelector
    # DaemonSet manifest uses: nodeSelector: { voip-environment: sip }
    labels = {
      "voip-environment" = "sip"
      "workload"         = "voip-edge"
      "network"          = "public"
    }

    # Taint to prevent general workloads from scheduling on VoIP nodes
    taints = {
      voip = {
        key    = "voip-environment"
        value  = "sip"
        effect = "NO_SCHEDULE"
      }
    }

    # Apply labels and taints via NodeConfig (required for AL2023 self-managed nodes)
    cloudinit_pre_nodeadm = [{
      content_type = "application/node.eks.aws"
      content      = <<-EOT
        ---
        apiVersion: node.eks.aws/v1alpha1
        kind: NodeConfig
        spec:
          kubelet:
            flags:
              - --node-labels=voip-environment=sip,workload=voip-edge,network=public
            config:
              registerWithTaints:
                - key: voip-environment
                  value: sip
                  effect: NoSchedule
      EOT
    }]

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

    # IMDSv2 configuration
    metadata_options = {
      http_endpoint               = "enabled"
      http_tokens                 = "required"
      http_put_response_hop_limit = 2
    }

    #---------------------------------------------------------------------------
    # Security Group Rules for SIP Traffic
    # Zadarma IP ranges for SIP signaling
    #---------------------------------------------------------------------------
    create_security_group = true

    security_group_ingress_rules = {
      #-------------------------------------------------------------------------
      # SIP signaling - UDP (port 5060) - Zadarma IP ranges
      #-------------------------------------------------------------------------
      sip_udp_zadarma_1 = {
        from_port   = "5060"
        to_port     = "5060"
        ip_protocol = "udp"
        cidr_ipv4   = "185.45.152.0/24"
        description = "SIP UDP - Zadarma"
      }
      sip_udp_zadarma_2 = {
        from_port   = "5060"
        to_port     = "5060"
        ip_protocol = "udp"
        cidr_ipv4   = "185.45.154.0/24"
        description = "SIP UDP - Zadarma"
      }
      sip_udp_zadarma_3 = {
        from_port   = "5060"
        to_port     = "5060"
        ip_protocol = "udp"
        cidr_ipv4   = "185.45.155.0/24"
        description = "SIP UDP - Zadarma"
      }
      sip_udp_zadarma_4 = {
        from_port   = "5060"
        to_port     = "5060"
        ip_protocol = "udp"
        cidr_ipv4   = "195.122.19.0/27"
        description = "SIP UDP - Zadarma"
      }
      sip_udp_zadarma_5 = {
        from_port   = "5060"
        to_port     = "5060"
        ip_protocol = "udp"
        cidr_ipv4   = "103.109.103.64/28"
        description = "SIP UDP - Zadarma"
      }
      sip_udp_zadarma_6 = {
        from_port   = "5060"
        to_port     = "5060"
        ip_protocol = "udp"
        cidr_ipv4   = "31.31.222.192/27"
        description = "SIP UDP - Zadarma"
      }
      sip_udp_zadarma_7 = {
        from_port   = "5060"
        to_port     = "5060"
        ip_protocol = "udp"
        cidr_ipv4   = "15.235.128.64/28"
        description = "SIP UDP - Zadarma"
      }

      #-------------------------------------------------------------------------
      # SIP signaling - TCP (port 5060) - Zadarma IP ranges
      #-------------------------------------------------------------------------
      sip_tcp_zadarma_1 = {
        from_port   = "5060"
        to_port     = "5060"
        ip_protocol = "tcp"
        cidr_ipv4   = "185.45.152.0/24"
        description = "SIP TCP - Zadarma"
      }
      sip_tcp_zadarma_2 = {
        from_port   = "5060"
        to_port     = "5060"
        ip_protocol = "tcp"
        cidr_ipv4   = "185.45.154.0/24"
        description = "SIP TCP - Zadarma"
      }
      sip_tcp_zadarma_3 = {
        from_port   = "5060"
        to_port     = "5060"
        ip_protocol = "tcp"
        cidr_ipv4   = "185.45.155.0/24"
        description = "SIP TCP - Zadarma"
      }
      sip_tcp_zadarma_4 = {
        from_port   = "5060"
        to_port     = "5060"
        ip_protocol = "tcp"
        cidr_ipv4   = "195.122.19.0/27"
        description = "SIP TCP - Zadarma"
      }
      sip_tcp_zadarma_5 = {
        from_port   = "5060"
        to_port     = "5060"
        ip_protocol = "tcp"
        cidr_ipv4   = "103.109.103.64/28"
        description = "SIP TCP - Zadarma"
      }
      sip_tcp_zadarma_6 = {
        from_port   = "5060"
        to_port     = "5060"
        ip_protocol = "tcp"
        cidr_ipv4   = "31.31.222.192/27"
        description = "SIP TCP - Zadarma"
      }
      sip_tcp_zadarma_7 = {
        from_port   = "5060"
        to_port     = "5060"
        ip_protocol = "tcp"
        cidr_ipv4   = "15.235.128.64/28"
        description = "SIP TCP - Zadarma"
      }

      #-------------------------------------------------------------------------
      # SIP over TLS - TCP (port 5061) - Zadarma IP ranges
      #-------------------------------------------------------------------------
      sip_tls_zadarma_1 = {
        from_port   = "5061"
        to_port     = "5061"
        ip_protocol = "tcp"
        cidr_ipv4   = "185.45.152.0/24"
        description = "SIP TLS - Zadarma"
      }
      sip_tls_zadarma_2 = {
        from_port   = "5061"
        to_port     = "5061"
        ip_protocol = "tcp"
        cidr_ipv4   = "185.45.154.0/24"
        description = "SIP TLS - Zadarma"
      }
      sip_tls_zadarma_3 = {
        from_port   = "5061"
        to_port     = "5061"
        ip_protocol = "tcp"
        cidr_ipv4   = "185.45.155.0/24"
        description = "SIP TLS - Zadarma"
      }
      sip_tls_zadarma_4 = {
        from_port   = "5061"
        to_port     = "5061"
        ip_protocol = "tcp"
        cidr_ipv4   = "195.122.19.0/27"
        description = "SIP TLS - Zadarma"
      }
      sip_tls_zadarma_5 = {
        from_port   = "5061"
        to_port     = "5061"
        ip_protocol = "tcp"
        cidr_ipv4   = "103.109.103.64/28"
        description = "SIP TLS - Zadarma"
      }
      sip_tls_zadarma_6 = {
        from_port   = "5061"
        to_port     = "5061"
        ip_protocol = "tcp"
        cidr_ipv4   = "31.31.222.192/27"
        description = "SIP TLS - Zadarma"
      }
      sip_tls_zadarma_7 = {
        from_port   = "5061"
        to_port     = "5061"
        ip_protocol = "tcp"
        cidr_ipv4   = "15.235.128.64/28"
        description = "SIP TLS - Zadarma"
      }

      # drachtio admin port (internal only - VPC CIDR)
      drachtio_admin = {
        from_port   = "9022"
        to_port     = "9022"
        ip_protocol = "tcp"
        cidr_ipv4   = "172.31.0.0/16" # VPC CIDR
        description = "drachtio admin port (internal)"
      }
    }

    security_group_egress_rules = {
      # Allow all outbound traffic (no port specified for ip_protocol = -1)
      all_outbound = {
        ip_protocol = "-1"
        cidr_ipv4   = "0.0.0.0/0"
        description = "Allow all outbound traffic"
      }
    }

    # Tags
    tags = {
      NodeGroup = "voip-sip"
      Purpose   = "sip-signaling"
      Component = "jambonz-sbc-sip"
    }
  }

  #=============================================================================
  # VoIP Edge Nodes - RTP Media (Jambonz SBC-RTP DaemonSet)
  #=============================================================================
  # These nodes run rtpengine with hostNetwork: true for RTP media processing
  # DaemonSet uses nodeSelector: voip-environment: rtp
  #
  # Components deployed here:
  #   - rtpengine (RTP media proxy, transcoding)
  #   - rtpengine-sidecar (DTMF events, stats)
  #=============================================================================
  voip-rtp = {
    name = "voip-rtp"

    # Scaling configuration - typically 1 node per AZ
    min_size     = 1
    max_size     = 1
    desired_size = 1

    # Compute-optimized instance for media processing
    # Minimum recommended: 4 vCPU, 8GB RAM (media is CPU intensive)
    instance_type = "c7i-flex.large"
    ami_type      = "AL2023_x86_64_STANDARD"

    # IMPORTANT: Public subnet for direct RTP traffic
    subnet_ids = [
      "subnet-09c6bf666cc32de74",
      "subnet-05a0eaf28e6b3a036" # bonz-dev-subnet-public1-us-east-1a
    ]

    # Network interface with public IP assignment
    network_interfaces = [{
      associate_public_ip_address = true
      device_index                = 0
      delete_on_termination       = true
      description                 = "Primary ENI for RTP node with public IP"
    }]

    # Kubernetes labels for DaemonSet nodeSelector
    labels = {
      "voip-environment" = "rtp"
      "workload"         = "voip-edge"
      "network"          = "public"
    }

    # Taint to prevent general workloads from scheduling
    taints = {
      voip = {
        key    = "voip-environment"
        value  = "rtp"
        effect = "NO_SCHEDULE"
      }
    }

    # Apply labels and taints via NodeConfig (required for AL2023 self-managed nodes)
    cloudinit_pre_nodeadm = [{
      content_type = "application/node.eks.aws"
      content      = <<-EOT
        ---
        apiVersion: node.eks.aws/v1alpha1
        kind: NodeConfig
        spec:
          kubelet:
            flags:
              - --node-labels=voip-environment=rtp,workload=voip-edge,network=public
            config:
              registerWithTaints:
                - key: voip-environment
                  value: rtp
                  effect: NoSchedule
      EOT
    }]

    # Storage configuration
    block_device_mappings = {
      xvda = {
        device_name = "/dev/xvda"
        ebs = {
          volume_size           = 100 # More storage for recordings
          volume_type           = "gp3"
          encrypted             = true
          delete_on_termination = true
        }
      }
    }

    # IMDSv2 configuration
    metadata_options = {
      http_endpoint               = "enabled"
      http_tokens                 = "required"
      http_put_response_hop_limit = 2
    }

    #---------------------------------------------------------------------------
    # Security Group Rules for RTP Traffic
    # RTP uses wide port range (10000-60000) for media streams
    #---------------------------------------------------------------------------
    create_security_group = true

    security_group_ingress_rules = {
      # RTP media streams - wide UDP port range
      # Source IP may differ from SIP provider (media relay)
      rtp_media = {
        from_port   = "10000"
        to_port     = "60000"
        ip_protocol = "udp"
        cidr_ipv4   = "0.0.0.0/0"
        description = "RTP media streams"
      }
      # rtpengine NG control protocol (internal only)
      rtpengine_ng = {
        from_port   = "22222"
        to_port     = "22222"
        ip_protocol = "tcp"
        cidr_ipv4   = "172.31.0.0/16" # VPC CIDR
        description = "rtpengine NG control (internal)"
      }
      # rtpengine sidecar (internal only)
      rtpengine_sidecar = {
        from_port   = "22223"
        to_port     = "22223"
        ip_protocol = "udp"
        cidr_ipv4   = "172.31.0.0/16" # VPC CIDR
        description = "rtpengine sidecar DTMF (internal)"
      }
    }

    security_group_egress_rules = {
      # Allow all outbound traffic for return RTP (no port specified for ip_protocol = -1)
      all_outbound = {
        ip_protocol = "-1"
        cidr_ipv4   = "0.0.0.0/0"
        description = "Allow all outbound traffic"
      }
    }

    # Tags
    tags = {
      NodeGroup = "voip-rtp"
      Purpose   = "rtp-media"
      Component = "jambonz-sbc-rtp"
    }
  }

  #=============================================================================
  # Alternative: Combined VoIP Edge Node (for dev/staging - cost savings)
  #=============================================================================
  # Uncomment to use a single node for both SIP and RTP
  # Both DaemonSets will run on the same node
  #=============================================================================
  # voip-edge = {
  #   name = "voip-edge"
  #
  #   min_size     = 1
  #   max_size     = 2
  #   desired_size = 1
  #
  #   instance_type = "c5.2xlarge" # Larger instance for both SIP and RTP
  #   ami_type      = "AL2023_x86_64_STANDARD"
  #
  #   subnet_ids = [
  #     "subnet-0488896d249bade3b",
  #   ]
  #
  #   network_interfaces = [{
  #     associate_public_ip_address = true
  #     device_index                = 0
  #     delete_on_termination       = true
  #   }]
  #
  #   # Both labels for combined node
  #   labels = {
  #     "voip-environment" = "edge"  # Use with nodeSelector tolerations
  #     "voip-sip"         = "true"
  #     "voip-rtp"         = "true"
  #     "workload"         = "voip-edge"
  #   }
  #
  #   taints = {
  #     voip = {
  #       key    = "voip-environment"
  #       value  = "edge"
  #       effect = "NO_SCHEDULE"
  #     }
  #   }
  #
  #   create_security_group = true
  #
  #   # Combined security group rules for SIP + RTP
  #   security_group_ingress_rules = {
  #     sip_udp = {
  #       from_port   = "5060"
  #       to_port     = "5060"
  #       ip_protocol = "udp"
  #       cidr_ipv4   = "0.0.0.0/0"
  #       description = "SIP UDP"
  #     }
  #     sip_tcp = {
  #       from_port   = "5060"
  #       to_port     = "5060"
  #       ip_protocol = "tcp"
  #       cidr_ipv4   = "0.0.0.0/0"
  #       description = "SIP TCP"
  #     }
  #     rtp_media = {
  #       from_port   = "10000"
  #       to_port     = "60000"
  #       ip_protocol = "udp"
  #       cidr_ipv4   = "0.0.0.0/0"
  #       description = "RTP media"
  #     }
  #   }
  #
  #   security_group_egress_rules = {
  #     all_outbound = {
  #       from_port   = "0"
  #       to_port     = "0"
  #       ip_protocol = "-1"
  #       cidr_ipv4   = "0.0.0.0/0"
  #       description = "Allow all outbound"
  #     }
  #   }
  #
  #   tags = {
  #     NodeGroup = "voip-edge"
  #     Purpose   = "voip-combined"
  #   }
  # }

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

