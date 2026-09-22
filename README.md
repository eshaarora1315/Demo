# Demo
Demo Architecture

# Enterprise Cloud Modernization: Multi-Account EKS Migration

## Architecture Overview

### Account Structure
- **Management**: AWS Organizations control plane, state management
- **Network Hub**: Transit Gateway, Network Firewall, centralized egress inspection
- **Security**: Centralized logging, monitoring, compliance
- **EKS Platform**: Kubernetes control plane, workload orchestration
- **Workloads** (Dev, Staging, Prod): Isolated application VPCs with hub-spoke topology

### Network Topology
- **Hub-Spoke via Transit Gateway**: Multi-VPC connectivity without full mesh
- **Micro-segmentation**: Public Ingress → App/Compute Private → Data Private subnets
- **Centralized Egress**: Network Firewall inspects all outbound traffic
- **Zero Trust**: No direct internet access from private subnets

### Container Orchestration
- **EKS Cluster**: Kubernetes 1.30 with managed node groups
- **Heterogeneous Compute**: Linux (Amazon Linux 3) + Windows Server 2022 worker nodes
- **Pod Identity (IRSA)**: Fine-grained IAM roles for Kubernetes workloads
- **Managed Add-ons**: VPC CNI, CoreDNS, kube-proxy, EBS CSI Driver

### Observability
- **OpenSearch**: Centralized log aggregation and full-text search
- **CloudWatch**: Native AWS metrics, alarms, dashboards
- **EKS Logs**: API, audit, authenticator, controller manager, scheduler
- **Application Logs**: Kubernetes and application-level structured logging

## Directory Structure

```
terraform/
├── main.tf                     # Root configuration
├── providers.tf                # Multi-account provider setup
├── variables.tf                # Input variables with validation
├── outputs.tf                  # Output values
├── terraform.tfvars.example    # Configuration template
├── modules/
│   ├── aws_organization/       # Organization, OUs, SCPs
│   ├── hub_spoke_network/      # TGW, hub VPC, firewall endpoints
│   ├── network_firewall/       # Egress inspection policies
│   ├── spoke_vpc/              # Workload VPCs (reusable)
│   ├── eks_cluster/            # EKS, node groups, OIDC
│   ├── observability/          # OpenSearch, CloudWatch, alarms
│   └── iam_cross_account/      # Cross-account roles

scripts/
├── linux-triage.sh             # Linux diagnostics (via SSM)
└── windows-triage.ps1          # Windows diagnostics (via SSM)
```

## Prerequisites

- Terraform >= 1.5.0
- AWS CLI v2
- jq (for JSON parsing)
- Ability to create AWS Organizations (requires payer account)
- Email addresses for all AWS accounts (unique per account)

## Deployment Steps

### 1. Setup Management Account

```bash
# Clone and configure
git clone <repo>
cd terraform

# Copy and customize variables
cp terraform.tfvars.example terraform.tfvars

# Edit terraform.tfvars with your email addresses and configuration
vim terraform.tfvars

# Initialize Terraform
terraform init

# Validate syntax
terraform validate
terraform fmt -recursive
```

### 2. Deploy Organization and State Backend

```bash
# Deploy in stages
terraform apply -target='module.aws_organization' \
  -target='aws_s3_bucket.terraform_state' \
  -target='aws_dynamodb_table.terraform_locks'

# Migrate state to S3 backend
terraform init  # Confirm migration to S3
```

### 3. Deploy Hub-Spoke Networking

```bash
terraform apply -target='module.hub_spoke_network' \
  -target='module.network_firewall'
```

### 4. Deploy Workload VPCs

```bash
terraform apply -target='module.workload_vpcs' \
  -target='module.cross_account_iam'
```

### 5. Deploy EKS Platform

```bash
terraform apply -target='module.eks_platform_vpc' \
  -target='module.eks_cluster'
```

### 6. Deploy Observability

```bash
terraform apply -target='module.observability'
```

### 7. Full Deployment

```bash
terraform apply
```

## Validation Checklist

### Organization
- [ ] All 6 accounts created and active
- [ ] OUs correctly organized (root, platform, workload)
- [ ] SCPs attached to workload OU
- [ ] AWS CloudTrail enabled across organization

### Networking
- [ ] Transit Gateway created and shared via RAM
- [ ] All VPCs attached to TGW with isolated route tables
- [ ] Network Firewall deployed and endpoints active
- [ ] NAT Gateways provisioned for egress
- [ ] Route table propagation verified

### EKS
- [ ] Cluster in ACTIVE state
- [ ] Linux and Windows node groups healthy
- [ ] Nodes registered in cluster
- [ ] OIDC provider created
- [ ] Add-ons deployed (VPC CNI, CoreDNS, EBS CSI)

### Observability
- [ ] OpenSearch domain healthy
- [ ] Kibana accessible
- [ ] CloudWatch log groups created
- [ ] Alarms in ALARM or OK state
- [ ] SNS topic verified

## Cross-Account Access

### From Management Account to Workload Accounts

```bash
# Set environment variable with workload account ID
export WORKLOAD_ACCOUNT_ID="123456789012"

# Assume role using external ID
aws sts assume-role \
  --role-arn "arn:aws:iam::${WORKLOAD_ACCOUNT_ID}:role/${ENVIRONMENT}-cross-account-role" \
  --role-session-name "management-access" \
  --external-id "your-external-id"

# Use returned credentials in subsequent AWS CLI calls
```

## EKS Access

### Configure kubectl

```bash
# Update kubeconfig
aws eks update-kubeconfig \
  --name enterprise-mod-prod-eks \
  --region us-east-1 \
  --role-arn arn:aws:iam::${EKS_ACCOUNT_ID}:role/cross-account-role

# Verify access
kubectl get nodes
kubectl get pods -A
```

### Pod Identity (IRSA) Setup

```bash
# Example: Grant S3 access to application pods
kubectl create namespace apps

# Create service account
kubectl create serviceaccount app-sa -n apps

# Create IAM role for pod
cat > pod-role-policy.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["s3:GetObject", "s3:ListBucket"],
      "Resource": ["arn:aws:s3:::my-bucket", "arn:aws:s3:::my-bucket/*"]
    }
  ]
}
EOF

# Create role and attach policy
aws iam create-role \
  --role-name app-pod-role \
  --assume-role-policy-document file://assume-role-policy.json

# Annotate service account
kubectl annotate serviceaccount app-sa -n apps \
  eks.amazonaws.com/role-arn=arn:aws:iam::${ACCOUNT_ID}:role/app-pod-role
```

## Operational Runbook

### Linux Diagnostics via SSM

```bash
# Run triage script on EC2 instance
aws ssm send-command \
  --document-name "AWS-RunShellScript" \
  --targets "Key=tag:Environment,Values=dev" \
  --parameters 'commands=["bash -s < /opt/scripts/linux-triage.sh"]'

# Get command execution status
aws ssm get-command-invocation \
  --command-id <command-id> \
  --instance-id <instance-id> \
  --plugin-name "aws:runShellScript"

# View logs in CloudWatch
aws logs tail /aws/ssm/linux-triage --follow
```

### Windows Diagnostics via SSM

```bash
# Run triage script on Windows instance
aws ssm send-command \
  --document-name "AWS-RunPowerShellScript" \
  --targets "Key=tag:Environment,Values=prod" \
  --parameters 'commands=["C:\\scripts\\windows-triage.ps1"]'

# View logs
aws logs tail /aws/ssm/windows-triage --follow
```

### Check EKS Node Health

```bash
# Describe node groups
aws eks describe-nodegroup \
  --cluster-name enterprise-mod-prod-eks \
  --nodegroup-name enterprise-mod-prod-eks-linux-nodes

# Check node status
kubectl get nodes -o wide
kubectl top nodes
kubectl describe node <node-name>

# Check for pod issues
kubectl get pods --all-namespaces --field-selector=status.phase!=Running
```

### Troubleshoot Network Connectivity

```bash
# Test path between spokes via TGW
aws ec2 describe-transit-gateway-attachments \
  --filters "Name=resource-type,Values=vpc"

# Verify route tables
aws ec2 describe-route-tables \
  --filters "Name=route.transit-gateway-id,Values=<tgw-id>"

# Test network reachability
aws ec2 describe-network-interface-attribute \
  --network-interface-id <eni-id> \
  --attribute sourceDestCheck
```

### View Firewall Logs

```bash
# Alert logs (dropped traffic)
aws logs tail /aws/networkfirewall/alert --follow

# Flow logs (all traffic)
aws logs tail /aws/networkfirewall/flow --follow

# Query specific rule violations
aws logs filter-log-events \
  --log-group-name /aws/networkfirewall/alert \
  --filter-pattern "DROP"
```

### Scale EKS Nodes

```bash
# Linux nodes
aws eks update-nodegroup-config \
  --cluster-name enterprise-mod-prod-eks \
  --nodegroup-name enterprise-mod-prod-eks-linux-nodes \
  --scaling-config minSize=1,maxSize=20,desiredSize=5

# Windows nodes
aws eks update-nodegroup-config \
  --cluster-name enterprise-mod-prod-eks \
  --nodegroup-name enterprise-mod-prod-eks-windows-nodes \
  --scaling-config minSize=1,maxSize=10,desiredSize=4
```

## State Management

### State Isolation Strategy

```
s3://enterprise-mod-terraform-state/
├── prod/terraform.tfstate              # Management account
├── workload/dev/terraform.tfstate      # Dev account state
├── workload/staging/terraform.tfstate  # Staging account state
└── workload/prod/terraform.tfstate     # Prod account state
```

### DynamoDB Locking

- Lock table: `terraform-locks`
- Billing: On-demand (scales automatically)
- Lock expiry: 38 seconds (configurable)

### State Access Control

```bash
# Restrict state bucket access
aws s3api get-bucket-policy \
  --bucket enterprise-mod-terraform-state-123456789012

# Encrypt state in transit and at rest (default AES-256)
aws s3api head-bucket-encryption \
  --bucket enterprise-mod-terraform-state-123456789012
```

## Cost Optimization

### Compute
- Spot instances for non-critical workloads
- Graviton instances for ARM64 workloads
- Right-sizing based on actual utilization
- Scheduled scaling for predictable workloads

### Network
- VPC endpoints for AWS services (no NAT cost)
- Data transfer optimization via TGW
- Consolidate NAT gateways per AZ

### Storage
- S3 Lifecycle policies for logs and backups
- EBS gp3 for better price/performance
- EBS snapshot scheduling

### Observability
- Log retention policies (30 days default)
- OpenSearch warm tier for older logs
- CloudWatch Insights for ad-hoc queries

## Disaster Recovery

### Backup Strategy

```bash
# EBS snapshot automation
aws ec2 create-snapshot \
  --volume-id <vol-id> \
  --description "Daily backup"

# RDS backup retention
aws rds modify-db-instance \
  --db-instance-identifier <db-id> \
  --backup-retention-period 35

# EKS cluster backup (via application)
# - Use Velero for persistent volume snapshots
# - Use AWS Backup for EBS volumes
```

### Failover Procedures

1. **RTO Target**: < 15 minutes
2. **RPO Target**: < 1 hour
3. **Failover steps**:
   - Promote read replicas to primary
   - Update Route53 DNS records
   - Trigger Lambda for app-level failover
   - Validate in secondary region

## Security Best Practices

### IAM
- Use role-based access (no long-term keys)
- Implement permission boundaries
- Regular access reviews (90-day cycle)
- MFA required for human users

### Network
- Zero-trust egress via Network Firewall
- NACLs for subnet-level filtering
- Security groups for instance-level filtering
- TLS 1.2+ only

### Encryption
- EBS: Encrypted by default (KMS)
- S3: Server-side encryption (S3-managed)
- Secrets: AWS Secrets Manager
- TLS: ACM certificates

### Compliance
- CloudTrail: All API calls logged
- Config: Continuous compliance monitoring
- SecurityHub: Aggregated security findings
- VPC Flow Logs: Network traffic analysis

## Scaling Considerations

### Account Limits
- 10 VPCs per region (default, can increase)
- 5 Internet Gateways per region
- 5 NAT Gateways per AZ
- 100 TGW attachments per TGW

### EKS Scaling
- Max 1,000 nodes per cluster
- Max 110 pods per node (CNI-dependent)
- Max 40,000 pods per cluster

### Network Scaling
- TGW bandwidth: 50 Gbps per attachment
- Network Firewall: 1.4 Gbps per endpoint
- Increase via AWS support ticket

## Maintenance Windows

### Cluster Upgrades
```bash
# Control plane upgrade
aws eks update-cluster-version \
  --name enterprise-mod-prod-eks \
  --kubernetes-version 1.31

# Monitor upgrade status
aws eks describe-update \
  --name enterprise-mod-prod-eks \
  --update-id <update-id>

# Node group upgrade (managed)
aws eks update-nodegroup-version \
  --cluster-name enterprise-mod-prod-eks \
  --nodegroup-name enterprise-mod-prod-eks-linux-nodes
```

### Addon Updates
```bash
# VPC CNI update
aws eks update-addon \
  --cluster-name enterprise-mod-prod-eks \
  --addon-name vpc-cni \
  --addon-version v1.14.1-eksbuild.1
```

## Cost Estimation (Monthly)

| Component | Monthly Cost |
|-----------|--------------|
| EKS Control Plane | $73 |
| EC2 Nodes (6 Linux m6i.xlarge) | ~$840 |
| EC2 Nodes (4 Windows m6i.2xlarge) | ~$1,280 |
| NAT Gateways (3x) | ~$315 |
| Network Firewall | ~$360 |
| OpenSearch (3 r6g.xlarge) | ~$1,200 |
| CloudWatch Logs (100 GB) | ~$50 |
| Transit Gateway | ~$36 |
| Storage (S3, EBS) | ~$200 |
| **Total (Estimated)** | **~$4,354** |

## Troubleshooting Guide

### Terraform Apply Failures

**Issue**: State lock timeout
```bash
# Check lock status
aws dynamodb get-item \
  --table-name terraform-locks \
  --key '{"LockID": {"S": "enterprise-mod-terraform-state/prod/terraform.tfstate"}}'

# Force unlock (last resort)
terraform force-unlock <LOCK_ID>
```

**Issue**: Provider authentication fails
```bash
# Verify IAM credentials
aws sts get-caller-identity

# Check role trust relationship
aws iam get-role --role-name OrganizationAccountAccessRole
```

### EKS Cluster Issues

**Issue**: Nodes not joining cluster
```bash
# Check node group events
aws eks describe-nodegroup \
  --cluster-name enterprise-mod-prod-eks \
  --nodegroup-name enterprise-mod-prod-eks-linux-nodes

# View kubelet logs on node (via SSM)
aws ssm start-session --target <instance-id>
```

**Issue**: Pod cannot pull image
```bash
# Verify ECR access from node
kubectl describe pod <pod-name> -n <namespace>

# Check pod service account
kubectl get sa -n <namespace>
```

### Network Connectivity Issues

**Issue**: Cannot reach pod from spoke VPC
```bash
# Test pod security group
kubectl get pod <pod-name> -n <namespace> -o yaml | grep securityGroups

# Verify TGW route tables
aws ec2 describe-transit-gateway-route-tables
```

## Support & Escalation

1. **L1 Support**: Check CloudWatch Logs, run triage scripts
2. **L2 Support**: Review VPC Flow Logs, TGW route diagnostics
3. **L3 Support**: AWS Support case with CloudTrail logs, architecture review

---

**Last Updated**: 2026-09-22  
**Terraform Version**: >= 1.5.0  
**AWS Provider**: >= 5.0

