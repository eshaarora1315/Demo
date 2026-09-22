variable "oidc_provider_arn" {
  description = "OIDC Provider ARN"
  type        = string
}

variable "oidc_provider_url" {
  description = "OIDC Provider URL"
  type        = string
}

variable "namespace" {
  description = "Kubernetes namespace"
  type        = string
}

variable "service_account" {
  description = "Kubernetes service account name"
  type        = string
}

variable "role_name_prefix" {
  description = "Prefix for IAM role name"
  type        = string
}

variable "common_tags" {
  description = "Common tags to apply"
  type        = map(string)
}
