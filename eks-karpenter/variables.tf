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
  description = "List of subnet IDs for worker nodes (private subnets)"
  type        = list(string)
}

################################################################################
# Node Group
################################################################################

variable "node_instance_types" {
  description = "Instance types for the Karpenter controller node group"
  type        = list(string)
  default     = ["t3a.small"]
}

variable "node_group_min_size" {
  description = "Minimum size of the Karpenter controller node group"
  type        = number
  default     = 0
}

variable "node_group_max_size" {
  description = "Maximum size of the Karpenter controller node group"
  type        = number
  default     = 2
}

variable "node_group_desired_size" {
  description = "Desired size of the Karpenter controller node group"
  type        = number
  default     = 2
}

################################################################################
# Karpenter
################################################################################

variable "karpenter_version" {
  description = "Karpenter Helm chart version"
  type        = string
  default     = "1.6.0"
}
