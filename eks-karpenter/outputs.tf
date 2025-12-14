################################################################################
# Cluster
################################################################################

output "cluster_arn" {
  description = "The Amazon Resource Name (ARN) of the cluster"
  value       = module.eks.cluster_arn
}

output "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data required to communicate with the cluster"
  value       = module.eks.cluster_certificate_authority_data
}

output "cluster_endpoint" {
  description = "Endpoint for your Kubernetes API server"
  value       = module.eks.cluster_endpoint
}

output "cluster_name" {
  description = "The name of the EKS cluster"
  value       = module.eks.cluster_name
}

output "cluster_oidc_issuer_url" {
  description = "The URL on the EKS cluster for the OpenID Connect identity provider"
  value       = module.eks.cluster_oidc_issuer_url
}

output "cluster_primary_security_group_id" {
  description = "Cluster security group that was created by Amazon EKS for the cluster"
  value       = module.eks.cluster_primary_security_group_id
}

################################################################################
# Karpenter
################################################################################

output "karpenter_node_iam_role_name" {
  description = "The name of the Karpenter node IAM role"
  value       = module.karpenter.node_iam_role_name
}

output "karpenter_node_iam_role_arn" {
  description = "The Amazon Resource Name (ARN) specifying the Karpenter node IAM role"
  value       = module.karpenter.node_iam_role_arn
}

output "karpenter_queue_name" {
  description = "The name of the SQS queue for Karpenter interruption handling"
  value       = module.karpenter.queue_name
}

output "karpenter_instance_profile_name" {
  description = "The name of the Karpenter instance profile"
  value       = module.karpenter.instance_profile_name
}

################################################################################
# EBS CSI Driver
################################################################################

output "ebs_csi_driver_role_arn" {
  description = "ARN of the IAM role used by the EBS CSI driver"
  value       = aws_iam_role.ebs_csi.arn
}

################################################################################
# kubectl Configuration
################################################################################

output "configure_kubectl" {
  description = "Configure kubectl: make sure you're logged in with the correct AWS profile and run the following command to update your kubeconfig"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name} --profile ${var.aws_profile}"
}
