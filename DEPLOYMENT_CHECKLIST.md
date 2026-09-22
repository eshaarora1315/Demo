# Terraform Deployment Checklist

## Pre-Deployment Phase

### Prerequisites Verification
- [ ] AWS CLI configured with appropriate credentials
- [ ] Terraform >= 1.5.0 installed (`terraform version`)
- [ ] kubectl configured and connected to EKS cluster (post-deployment)
- [ ] Helm 3.x installed (`helm version`)
- [ ] All required IAM permissions in place
- [ ] Multi-account cross-account IAM roles created (`TerraformExecutionRole`)

### Account Setup
- [ ] AWS Organization created
- [ ] Management account identified
- [ ] Network Hub account created (Transit Gateway hub)
- [ ] Security/Logging account created (OpenSearch, logs)
- [ ] Workload accounts created (Dev, Staging, Prod)
- [ ] EKS platform account created
- [ ] Cross-account IAM roles in all accounts with trust policy

### Network Prerequisites
- [ ] IP CIDR ranges reserved for all VPCs
  - [ ] Network Hub: 10.100.0.0/16
  - [ ] EKS: 10.50.0.0/16
  - [ ] Dev Workload: 10.10.0.0/16
  - [ ] Staging Workload: 10.20.0.0/16
  - [ ] Prod Workload: 10.30.0.0/16
- [ ] No CIDR overlaps verified
- [ ] Routing requirements documented
- [ ] Firewall rules requirements identified

## Configuration Phase

### Variables Setup
- [ ] Copy `terraform.tfvars.example` to `terraform.tfvars`
- [ ] Update all required variables:
  - [ ] `primary_region` and `secondary_region`
  - [ ] `environment` (dev/staging/prod)
  - [ ] `project_name`
  - [ ] `organization_id`
  - [ ] All account IDs (management, network_hub, security, workload, eks)
  - [ ] VPC CIDR blocks
  - [ ] EKS configuration (version, instance types, node counts)
  - [ ] OpenSearch configuration
- [ ] Validate variable values with business requirements
- [ ] Review and set all optional variables
- [ ] Save `.tfvars` file in secure location

### Backend Configuration
- [ ] S3 bucket name specified for Terraform state
- [ ] DynamoDB table name configured
- [ ] Primary region set correctly
- [ ] Encryption enabled for S3 bucket
- [ ] Versioning enabled for S3 bucket
- [ ] Block public access configured

### Provider Configuration
- [ ] AWS provider version pinned to ~> 5.40
- [ ] Kubernetes provider version pinned to ~> 2.27
- [ ] Helm provider version pinned to ~> 2.13
- [ ] All provider aliases configured correctly
- [ ] Cross-account assume role ARNs verified

## Code Quality Checks

### Code Formatting
```bash
terraform fmt -recursive
```
- [ ] All `.tf` files formatted correctly
- [ ] Indentation consistent (2 spaces)
- [ ] No trailing whitespace

### Code Validation
```bash
terraform validate
```
- [ ] All `.tf` files parse correctly
- [ ] Variable references valid
- [ ] Module sources accessible
- [ ] No configuration errors reported

### Linting
```bash
tflint --init
tflint
```
- [ ] No linting errors in root module
- [ ] No linting errors in modules/
- [ ] Potential issues reviewed and documented

### Security Scanning
```bash
checkov -d . --framework terraform
```
- [ ] No high-severity findings
- [ ] Medium findings reviewed and mitigated
- [ ] Compliance requirements verified

## Initialization Phase

### Terraform Init
```bash
terraform init \
  -backend-config="bucket=BUCKET_NAME" \
  -backend-config="key=prod/terraform.tfstate" \
  -backend-config="region=us-east-1" \
  -backend-config="dynamodb_table=terraform-locks"
```
- [ ] No errors during initialization
- [ ] `.terraform/` directory created
- [ ] `.terraform.lock.hcl` generated (commit to VCS)
- [ ] Backend configuration successful
- [ ] Provider plugins downloaded

### Provider Credentials
- [ ] AWS credentials configured (AWS_PROFILE or AWS_ACCESS_KEY_ID)
- [ ] Cross-account role assumption tested
- [ ] IAM permissions verified for each account
- [ ] Credentials not hardcoded anywhere

## Planning Phase

### Terraform Plan
```bash
terraform plan -out=tfplan -var-file=terraform.tfvars
```
- [ ] Plan executes without errors
- [ ] Expected resource count reasonable
- [ ] No unintended destructive changes (`-/+`, `destroy`)
- [ ] All VPCs will be created
- [ ] Transit Gateway properly configured
- [ ] EKS cluster resources included
- [ ] IAM roles and policies correct
- [ ] Security groups properly scoped
- [ ] Plan saved to file for review

### Plan Review
- [ ] All resources in plan are intentional
- [ ] Resource naming follows convention
- [ ] No security violations in configuration
- [ ] No dangling resources (orphaned from state)
- [ ] Dependency order appears correct
- [ ] Regional configuration correct

### Resource-Specific Verification
- [ ] VPC CIDR blocks: 10.100.0.0/16, 10.50.0.0/16, 10.10.0.0/16, etc.
- [ ] Subnets correctly distributed across AZs (3 AZs)
- [ ] NAT Gateways: 1 per AZ (if not single_nat_gateway)
- [ ] Transit Gateway attachments: 5 total (hub + 3 workloads + EKS)
- [ ] Security groups: Inbound/egress rules correctly scoped
- [ ] EKS cluster: Version 1.30, multi-AZ, logging enabled
- [ ] Node groups: Linux (3 nodes) + Windows (2 nodes) if enabled
- [ ] OpenSearch: 3-node cluster with encryption
- [ ] Network Firewall: Rule groups attached if enabled
- [ ] IAM roles: Proper trust policies and permissions

## Pre-Deployment Review Meeting

- [ ] Business stakeholders approval
- [ ] Security team review completed
- [ ] Network team verification
- [ ] Change request submitted (if required)
- [ ] Maintenance window scheduled
- [ ] Rollback plan documented

## Deployment Phase

### Backup Before Deployment
- [ ] Current state backed up (if existing infrastructure)
- [ ] Configuration backed up to version control
- [ ] Manual resources documented

### Apply Configuration
```bash
terraform apply tfplan
```
- [ ] Apply starts without prompts
- [ ] Resources created in correct order
- [ ] No errors during apply
- [ ] Approximately same number of resources as planned
- [ ] Apply completes successfully
- [ ] State file updated and synced to S3

### Deployment Monitoring
- [ ] CloudWatch logs monitored during apply
- [ ] No unexpected API errors
- [ ] VPC creation verified in console
- [ ] Transit Gateway creation verified
- [ ] EKS cluster status: Active (takes ~10 minutes)
- [ ] Node groups: Healthy status
- [ ] Security groups: Correct rules
- [ ] IAM roles: Properly created

## Post-Deployment Phase

### State Verification
```bash
terraform show
terraform output
```
- [ ] State file contains all created resources
- [ ] All outputs retrieved successfully
- [ ] State file size reasonable
- [ ] No sensitive data in state (marked correctly)

### EKS Cluster Validation
```bash
aws eks describe-cluster --name enterprise-eks
aws eks list-node-groups --cluster-name enterprise-eks
kubectl get nodes
kubectl get pods --all-namespaces
```
- [ ] EKS cluster endpoint accessible
- [ ] Node groups in "Active" state
- [ ] All nodes in "Ready" state
- [ ] System pods running (kube-system, karpenter)
- [ ] Karpenter deployed (if enabled)
- [ ] Metrics server deployed (if enabled)
- [ ] Prometheus/Grafana deployed (if enabled)

### Network Validation
```bash
aws ec2 describe-transit-gateways
aws ec2 describe-vpcs
aws ec2 describe-subnets
aws ec2 describe-route-tables
```
- [ ] Transit Gateway created and active
- [ ] All VPCs attached to Transit Gateway
- [ ] Route tables propagating correctly
- [ ] Subnet associations correct
- [ ] Nat Gateway operational (public IPs assigned)
- [ ] VPC Flow Logs enabled

### Security Validation
- [ ] Security groups have proper ingress rules
- [ ] No overly permissive rules (0.0.0.0/0 only where intended)
- [ ] Network ACLs properly configured
- [ ] IAM roles have least privilege permissions
- [ ] KMS encryption enabled for sensitive data
- [ ] VPC endpoint configured for AWS services

### Logging Validation
- [ ] CloudWatch log groups created for EKS
- [ ] EKS cluster logs flowing to CloudWatch
- [ ] OpenSearch domain accessible
- [ ] Kinesis Firehose forwarding logs
- [ ] SSM document diagnostic execution tested

### Monitoring Validation
- [ ] Prometheus scraping targets
- [ ] Grafana dashboards accessible
- [ ] Alertmanager rules configured
- [ ] Metrics flowing to monitoring stack

## Testing Phase

### Connectivity Tests
```bash
# Test pod-to-pod communication
kubectl run test-pod --image=busybox --rm -it -- wget SERVICE_IP:PORT

# Test egress to external services
kubectl run test-pod --image=curlimages/curl --rm -it -- curl https://api.github.com
```
- [ ] Pods can communicate within cluster
- [ ] DNS resolution working
- [ ] External connectivity working (if Network Firewall configured)

### Scaling Tests
- [ ] Scale node groups up/down
- [ ] Karpenter provisioning works (if enabled)
- [ ] Horizontal Pod Autoscaler functions

### Failover Tests
- [ ] Node failure recovery
- [ ] Pod eviction and rescheduling
- [ ] AZ outage simulation (if applicable)

### SSM Diagnostics Tests
```bash
aws ssm send-command \
  --instance-ids i-xxxxx \
  --document-name ${ENVIRONMENT}-linux-diagnostics
```
- [ ] Linux diagnostics script executes
- [ ] Windows diagnostics script executes
- [ ] Output captured in CloudWatch Logs

## Documentation Phase

### Documentation Created
- [ ] Infrastructure architecture diagram updated
- [ ] Network topology diagram updated
- [ ] IAM roles and policies documented
- [ ] EKS cluster configuration documented
- [ ] Runbook updated with new resources
- [ ] Disaster recovery procedures updated
- [ ] KMS key ARNs documented
- [ ] Security group rules documented

### Knowledge Transfer
- [ ] Operations team trained
- [ ] Support documentation provided
- [ ] Escalation procedures documented
- [ ] Contact information updated

## Monitoring & Alerts Setup

### CloudWatch Alarms
- [ ] EKS cluster health alarm
- [ ] Node group unhealthy alarm
- [ ] OpenSearch cluster health alarm
- [ ] NAT Gateway connection count alarm
- [ ] Network Firewall alert alarm

### Log Aggregation
- [ ] CloudWatch Logs retention set to 30 days
- [ ] OpenSearch retention policy configured
- [ ] Log parsing rules configured

### Dashboards
- [ ] CloudWatch dashboard created
- [ ] Grafana dashboards created
- [ ] Cost monitoring dashboard (if applicable)

## Handoff & Closure

### Sign-off
- [ ] Infrastructure owner sign-off
- [ ] Security team sign-off
- [ ] Business stakeholder sign-off

### Runbook Handoff
- [ ] Runbook provided to operations
- [ ] Emergency contacts documented
- [ ] Escalation procedures confirmed

### Final Verification
- [ ] All resources tagged correctly
- [ ] Cost allocation tags applied
- [ ] No stray resources created
- [ ] Documentation complete and accurate
- [ ] Version control repository updated

## Post-Deployment Operations (Day 2)

### Day 1-7 Monitoring
- [ ] Monitor infrastructure metrics
- [ ] Check logs for errors
- [ ] Verify auto-scaling behavior
- [ ] Monitor costs

### Day 30 Review
- [ ] Performance baseline established
- [ ] Optimization opportunities identified
- [ ] Lessons learned documented
- [ ] Cost optimization recommendations

### Ongoing
- [ ] Regular patching schedule established
- [ ] Security scanning enabled
- [ ] Backup procedures tested
- [ ] Disaster recovery drills scheduled

## Rollback Plan

If deployment fails at any point:

1. **Immediate Actions**
   - [ ] Stop further changes
   - [ ] Document error messages
   - [ ] Notify stakeholders
   - [ ] Assess impact scope

2. **Rollback Decision**
   - [ ] If before 50% apply: `terraform destroy` or manual cleanup
   - [ ] If after 50% apply: Complete deployment, then troubleshoot
   - [ ] Revert state file if necessary

3. **Root Cause Analysis**
   - [ ] Identify failure point
   - [ ] Document lessons learned
   - [ ] Plan corrective actions
   - [ ] Schedule re-deployment

## Sign-Off

- **Prepared by**: ____Esha Julka__________
- **Reviewed by**: _______________________
- **Approved by**: _______________________
- **Date**: _____22-09-2026_______________
- **Deployment Date**: _______________________
- **Completed by**: _______________________
