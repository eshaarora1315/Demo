# Terraform Project Structure

## Directory Organization

```
terraform/
├── main.tf                          # Root module configuration
├── variables.tf                     # Input variables
├── outputs.tf                       # Root outputs
├── versions.tf                      # Provider versions
├── locals.tf                        # Local values and data sources
│
├── backend_setup.tf                 # S3 + DynamoDB for state management
├── eks_cluster.tf                   # EKS cluster instantiation
├── iam_cross_account.tf             # IAM roles and IRSA configuration
├── workload_accounts.tf             # Multi-account workload setup
├── opensearch.tf                    # Centralized logging
├── monitoring.tf                    # Prometheus/Grafana/Fluent Bit
├── ssm_documents.tf                 # Diagnostic automation
├── network_firewall.tf              # Network egress inspection
├── karpenter.tf                     # Advanced autoscaling
├── modules_vpc_main.tf              # VPC module instantiation
├── modules_transit_gateway.tf       # Transit Gateway setup
│
├── modules/
│   ├── transit-gateway/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │
│   ├── eks/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │
│   ├── opensearch/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │
│   └── irsa/
│       ├── main.tf
│       ├── variables.tf
│       └── outputs.tf
│
├── terraform.tfvars.example         # Example variables
└── TERRAFORM_STRUCTURE.md           # This file
```

## File Organization Guide

### Root Level Files
- **main.tf**: Provider configuration and module orchestration
- **variables.tf**: All input variables with validation
- **outputs.tf**: Root module outputs
- **versions.tf**: Terraform and provider version constraints
- **locals.tf**: Local values and data source queries
- **backend_setup.tf**: S3/DynamoDB state backend resources

### Feature-Specific Files
- **eks_cluster.tf**: EKS VPC, cluster, and node group configuration
- **iam_cross_account.tf**: IAM roles, IRSA, Pod Identities
- **workload_accounts.tf**: Multi-account VPC and TGW attachments
- **opensearch.tf**: OpenSearch domain and log aggregation
- **monitoring.tf**: Prometheus, Grafana, Fluent Bit, Metrics Server
- **ssm_documents.tf**: SSM documents for diagnostics and remediation
- **network_firewall.tf**: Network Firewall policies and rules
- **karpenter.tf**: Karpenter Helm chart and configuration

### Module Directory
Each module follows standard structure:
- `main.tf`: Core resource definitions
- `variables.tf`: Module input variables
- `outputs.tf`: Module outputs

## Module Descriptions

### transit-gateway/
Centralized Transit Gateway with multi-account attachment support
- TGW creation and route tables
- Hub-spoke topology support
- Route propagation and association

### eks/
Amazon EKS cluster with heterogeneous OS support
- EKS cluster creation (Kubernetes 1.30+)
- Linux (Amazon Linux 3) and Windows (Server 2022) managed node groups
- Pod Identity associations
- Security groups and OIDC provider

### opensearch/
Centralized logging using OpenSearch Serverless
- OpenSearch Serverless collection
- Kinesis Firehose for log ingestion
- Security policies and encryption
- CloudWatch log group creation

### irsa/
IAM Roles for Service Accounts (Pod Identities)
- OIDC provider integration
- Namespace and service account mapping
- Cross-account assume role policies

## State Management

### Remote State Configuration
Backend must be configured in `main.tf`:
```hcl
backend "s3" {
  bucket         = "terraform-state-bucket"
  key            = "prod/terraform.tfstate"
  region         = "us-east-1"
  encrypt        = true
  dynamodb_table = "terraform-locks"
}
```

### State Isolation Strategy
- **Per-environment**: Separate state files (`dev/`, `staging/`, `prod/`)
- **Per-account**: Managed via assume roles in providers
- **Locking**: DynamoDB table prevents concurrent modifications
- **Encryption**: S3-side encryption (AES256)
- **Versioning**: S3 versioning enabled for state recovery

## Provider Configuration

### Multi-Account Strategy
```hcl
provider "aws" {
  region = var.primary_region
}

provider "aws" {
  alias  = "network_hub"
  assume_role {
    role_arn = "arn:aws:iam::${var.network_hub_account_id}:role/TerraformExecutionRole"
  }
}
```

Each account provider uses:
- Cross-account IAM role (`TerraformExecutionRole`)
- Temporary credentials (STS assume role)
- Default tags for resource tracking

## DRY Principles Implementation

### Code Reusability
1. **Modular Structure**: Each component is a reusable module
2. **Common Tags**: Centralized `local.common_tags` applied to all resources
3. **Variable Validation**: Input validation using `validation` blocks
4. **Locals**: Repeated calculations stored in `locals` block
5. **Data Sources**: AMI lookup and AZ discovery via data sources

### Module Instantiation Examples
```hcl
module "eks" {
  source = "./modules/eks"
  
  environment  = var.environment
  project_name = var.project_name
  common_tags  = local.common_tags
  # ... other variables
}
```

## Deployment Workflow

### Step 1: Initialize
```bash
terraform init -backend-config="bucket=STATE_BUCKET" \
  -backend-config="key=prod/terraform.tfstate" \
  -backend-config="dynamodb_table=terraform-locks"
```

### Step 2: Plan
```bash
terraform plan -out=tfplan -var-file=terraform.tfvars
```

### Step 3: Apply
```bash
terraform apply tfplan
```

### Step 4: Monitor
```bash
terraform show
terraform state list
terraform output
```

## Variable Hierarchy

1. **Default Values** (lowest): Defined in `variables.tf`
2. **Variable Files**: `terraform.tfvars`
3. **Command Line**: `-var` flags (highest)

## Tagging Strategy

All resources include:
```hcl
merge(
  local.common_tags,
  {
    Name        = "resource-name"
    Component   = "component-type"
    Env         = var.environment
  }
)
```

Common tags include:
- `Environment`: dev/staging/prod
- `Project`: project_name
- `ManagedBy`: "Terraform"
- `CreatedAt`: timestamp()

## Security Best Practices

1. **State Encryption**: S3 default encryption + DynamoDB
2. **Access Control**: IAM roles per account
3. **Secret Management**: Sensitive values marked and excluded from logs
4. **Principle of Least Privilege**: Minimal IAM permissions
5. **Audit Logging**: CloudTrail for all API calls

## Validation & Testing

### Pre-Deployment Checks
```bash
terraform fmt -recursive
terraform validate
tflint --init && tflint
checkov -d . --framework terraform
```

### State Locking
DynamoDB table prevents concurrent modifications during apply operations.

## Disaster Recovery

### State Backup
- S3 versioning enabled
- Point-in-time recovery available via S3 versioning
- Regular backups recommended

### State Recovery
```bash
# List versions
aws s3api list-object-versions --bucket STATE_BUCKET

# Restore specific version
aws s3api get-object --bucket STATE_BUCKET \
  --key prod/terraform.tfstate \
  --version-id VERSION_ID recovered.tfstate
```

## Cost Optimization

### Right-Sizing
- Instance type selection based on workload
- Spot instances for non-critical workloads
- Graviton (ARM64) for cost savings

### Resource Lifecycle
- S3 Lifecycle policies for log data
- DynamoDB on-demand billing
- Auto-scaling for compute resources

## Monitoring & Operations

### CloudWatch Integration
- EKS cluster logs to CloudWatch
- OpenSearch for centralized log aggregation
- Prometheus/Grafana for metrics

### Diagnostic Automation
- SSM documents for automated troubleshooting
- Systems Manager Run Command execution
- EventBridge-triggered remediation workflows
