variable "primary_region" {
  description = "Primary AWS region"
  type        = string
  default     = "us-east-1"
}

variable "secondary_region" {
  description = "Secondary AWS region for disaster recovery"
  type        = string
  default     = "us-west-2"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "organization_id" {
  description = "AWS Organization ID"
  type        = string
}

variable "management_account_id" {
  description = "Management account ID"
  type        = string
}

variable "network_hub_account_id" {
  description = "Network Hub account ID"
  type        = string
}

variable "security_account_id" {
  description = "Security/Logging account ID"
  type        = string
}

variable "workload_account_ids" {
  description = "Map of workload account IDs for Dev, Staging, Prod"
  type = object({
    dev     = string
    staging = string
    prod    = string
  })
}

variable "eks_account_id" {
  description = "Shared EKS platform account ID"
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
  default     = "10.0.0.0/16"
}

variable "enable_nat_gateway" {
  description = "Enable NAT Gateway for private subnets"
  type        = bool
  default     = true
}

variable "single_nat_gateway" {
  description = "Use single NAT Gateway across all AZs"
  type        = bool
  default     = false
}

variable "enable_vpn_gateway" {
  description = "Enable VPN Gateway for hybrid connectivity"
  type        = bool
  default     = false
}

variable "eks_cluster_version" {
  description = "Kubernetes cluster version"
  type        = string
  default     = "1.30"
}

variable "eks_cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "eks_instance_types" {
  description = "Instance types for EKS Linux nodes"
  type        = list(string)
  default     = ["m7g.xlarge", "m7g.2xlarge"]
}

variable "eks_windows_instance_types" {
  description = "Instance types for EKS Windows nodes"
  type        = list(string)
  default     = ["m6i.2xlarge"]
}

variable "eks_desired_size" {
  description = "Desired number of worker nodes"
  type        = number
  default     = 3
}

variable "eks_min_size" {
  description = "Minimum number of worker nodes"
  type        = number
  default     = 2
}

variable "eks_max_size" {
  description = "Maximum number of worker nodes"
  type        = number
  default     = 10
}

variable "enable_windows_nodes" {
  description = "Enable Windows worker nodes in EKS"
  type        = bool
  default     = true
}

variable "windows_desired_size" {
  description = "Desired number of Windows worker nodes"
  type        = number
  default     = 2
}

variable "windows_min_size" {
  description = "Minimum number of Windows worker nodes"
  type        = number
  default     = 1
}

variable "windows_max_size" {
  description = "Maximum number of Windows worker nodes"
  type        = number
  default     = 5
}

variable "enable_network_firewall" {
  description = "Enable AWS Network Firewall for egress inspection"
  type        = bool
  default     = true
}

variable "centralized_logging_enabled" {
  description = "Enable centralized logging to OpenSearch"
  type        = bool
  default     = true
}

variable "opensearch_domain_name" {
  description = "OpenSearch domain name"
  type        = string
  default     = "enterprise-logs"
}

variable "opensearch_version" {
  description = "OpenSearch version"
  type        = string
  default     = "2.11"
}

variable "enable_cloudwatch_logs" {
  description = "Enable CloudWatch Logs"
  type        = bool
  default     = true
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 30
}

variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "availability_zones" {
  description = "Availability zones for multi-AZ deployment"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

variable "enable_karpenter" {
  description = "Enable Karpenter for advanced autoscaling"
  type        = bool
  default     = false
}

variable "enable_monitoring" {
  description = "Enable Prometheus/Grafana monitoring stack"
  type        = bool
  default     = true
}

variable "sso_identity_store_id" {
  description = "AWS IAM Identity Center store ID"
  type        = string
  default     = ""
}
