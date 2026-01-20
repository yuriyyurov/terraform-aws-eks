locals {
  name = var.cluster_name

  tags = merge(var.tags, {
    ClusterName = var.cluster_name
  })

  # Automatically assign subnets based on node group characteristics:
  # - If node group has network_interfaces with public IP, use public_subnet_ids
  # - If node group explicitly specifies subnet_ids, use those
  # - Otherwise, use private_subnet_ids
  self_managed_node_groups_with_subnets = {
    for k, v in var.self_managed_node_groups : k => merge(v, {
      subnet_ids = coalesce(
        v.subnet_ids, # Use explicitly specified subnets if provided
        # Auto-detect: if network_interfaces require public IP, use public subnets
        try(v.network_interfaces[0].associate_public_ip_address, false) ? var.public_subnet_ids : null,
        # Default to private subnets
        var.private_subnet_ids
      )
    })
  }
}

################################################################################
# EBS CSI Driver IAM Role
################################################################################

data "aws_iam_policy_document" "ebs_csi_assume_role" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }
    actions = ["sts:AssumeRole", "sts:TagSession"]
  }
}

resource "aws_iam_role" "ebs_csi" {
  name               = "${local.name}-ebs-csi-driver"
  assume_role_policy = data.aws_iam_policy_document.ebs_csi_assume_role.json
  tags               = local.tags
}

resource "aws_iam_role_policy_attachment" "ebs_csi" {
  role       = aws_iam_role.ebs_csi.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

################################################################################
# EKS Module
################################################################################

module "eks" {
  source = "../"

  name               = local.name
  kubernetes_version = var.kubernetes_version

  # Gives Terraform identity admin access to cluster which will
  # allow deploying resources into the cluster
  enable_cluster_creator_admin_permissions = true
  endpoint_public_access                   = true

  # EKS Provisioned Control Plane configuration
  control_plane_scaling_config = var.control_plane_scaling_config

  addons = {
    coredns = {
      configuration_values = jsonencode({
        tolerations = [
          {
            key      = "dedicated"
            operator = "Equal"
            value    = "general"
            effect   = "NoSchedule"
          }
        ]
      })
    }
    eks-pod-identity-agent = {
      before_compute = true
    }
    kube-proxy = {}
    vpc-cni = {
      before_compute = true
    }
    aws-ebs-csi-driver = {
      pod_identity_association = [{
        role_arn        = aws_iam_role.ebs_csi.arn
        service_account = "ebs-csi-controller-sa"
      }]
      configuration_values = jsonencode({
        controller = {
          tolerations = [
            {
              key      = "dedicated"
              operator = "Equal"
              value    = "general"
              effect   = "NoSchedule"
            }
          ]
        }
        node = {
          tolerations = [
            {
              key      = "dedicated"
              operator = "Equal"
              value    = "general"
              effect   = "NoSchedule"
            },
            {
              key      = "voip-environment"
              operator = "Exists"
              effect   = "NoSchedule"
            }
          ]
        }
      })
    }
  }

  vpc_id                   = var.vpc_id
  subnet_ids               = var.private_subnet_ids
  control_plane_subnet_ids = var.control_plane_subnet_ids

  # Self-managed node groups with auto-assigned subnets
  self_managed_node_groups = local.self_managed_node_groups_with_subnets

  tags = local.tags
}

################################################################################
# Supporting Resources - Tag existing subnets for ELB discovery
################################################################################

resource "aws_ec2_tag" "private_subnet_internal_elb" {
  for_each = toset(var.private_subnet_ids)

  resource_id = each.value
  key         = "kubernetes.io/role/internal-elb"
  value       = "1"
}

resource "aws_ec2_tag" "public_subnet_elb" {
  for_each = toset(var.control_plane_subnet_ids)

  resource_id = each.value
  key         = "kubernetes.io/role/elb"
  value       = "1"
}

