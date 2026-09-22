variable "environment" {
  type = string
}

variable "project_name" {
  type = string
}

variable "common_tags" {
  type = map(string)
}

variable "vpc_id" {
  type = string
}

variable "private_subnets" {
  type = list(string)
}

variable "eks_cluster_version" {
  type = string
}

variable "eks_instance_types" {
  type = list(string)
}

variable "eks_windows_instance_types" {
  type = list(string)
}

variable "eks_desired_size" {
  type = number
}

variable "eks_min_size" {
  type = number
}

variable "eks_max_size" {
  type = number
}

variable "enable_windows_nodes" {
  type = bool
}

variable "windows_desired_size" {
  type = number
}

variable "windows_min_size" {
  type = number
}

variable "windows_max_size" {
  type = number
}

variable "log_retention_days" {
  type = number
}

variable "cloudwatch_log_kms_key_id" {
  type    = string
  default = ""
}
