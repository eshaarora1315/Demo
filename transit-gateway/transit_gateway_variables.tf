variable "environment" {
  type = string
}

variable "project_name" {
  type = string
}

variable "common_tags" {
  type = map(string)
}

variable "primary_region" {
  type = string
}

variable "network_hub_vpc_id" {
  type = string
}

variable "network_hub_subnets" {
  type = list(string)
}

variable "workload_accounts" {
  type = object({
    dev     = string
    staging = string
    prod    = string
  })
}

variable "eks_account_id" {
  type = string
}
