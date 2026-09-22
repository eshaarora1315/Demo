data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_ami" "amazon_linux_3" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

data "aws_ami" "windows_server_2022" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["Windows_Server-2022-English-Core-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

locals {
  availability_zones = var.availability_zones != null ? var.availability_zones : slice(data.aws_availability_zones.available.names, 0, 3)
  
  subnet_mapping = {
    public  = 1
    private = 10
    intra   = 20
  }

  workload_accounts_list = [
    var.workload_account_ids.dev,
    var.workload_account_ids.staging,
    var.workload_account_ids.prod
  ]

  environment_cidrs = {
    dev     = "10.10.0.0/16"
    staging = "10.20.0.0/16"
    prod    = "10.30.0.0/16"
  }
}
