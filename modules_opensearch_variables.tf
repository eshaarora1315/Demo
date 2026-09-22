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

variable "opensearch_domain_name" {
  type = string
}

variable "opensearch_version" {
  type = string
}

variable "master_user_name" {
  type = string
}

variable "master_user_password" {
  type      = string
  sensitive = true
}

variable "instance_type" {
  type = string
}

variable "instance_count" {
  type = number
}

variable "warm_instance_enabled" {
  type = bool
}

variable "ebs_volume_size" {
  type = number
}

variable "ebs_volume_type" {
  type = string
}

variable "log_retention_days" {
  type = number
}
