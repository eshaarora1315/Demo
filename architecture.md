# Enterprise Cloud Modernization Architecture

## Multi-Account Organization Structure

```
AWS Organizations Root
├── Management Account (us-east-1)
│   ├── Organization Control
│   ├── Terraform State (S3 + DynamoDB)
│   ├── CloudTrail (all API logs)
│   └── Service Control Policies
│
├── Platform OU
│   ├── Network Hub Account (us-east-1)
│   │   ├── Transit Gateway (central)
│   │   ├── Hub VPC (10.1.0.0/16)
│   │   ├── Network Firewall (egress inspection)
│   │   └── AWS Service endpoints
│   │
│   ├── Security Account (us-east-1)
│   │   ├── Centralized CloudTrail logs
│   │   ├── OpenSearch cluster
│   │   ├── Kibana dashboard
│   │   ├── SecurityHub
│   │   └── Config recorder
│   │
│   └── EKS Platform Account (us-east-1)
│       ├── EKS Cluster (1.30)
│       ├── EKS Platform VPC (10.40.0.0/16)
│       ├── Linux Node Group (m6i.xlarge)
│       ├── Windows Node Group (m6i.2xlarge)
│       └── Prometheus/Grafana (future)
│
└── Workload OU
    ├── Dev Workload Account (us-east-1)
    │   ├── VPC (10.10.0.0/16)
    │   ├── Application subnets
    │   ├── RDS database (isolated)
    │   └── S3 bucket (app state)
    │
    ├── Staging Workload Account (us-east-1)
    │   ├── VPC (10.20.0.0/16)
    │   ├── Multi-AZ applications
    │   ├── RDS replication
    │   └── Lambda functions
    │
    └── Prod Workload Account (us-east-1)
        ├── VPC (10.30.0.0/16)
        ├── HA application tier
        ├── RDS clustered database
        └── Disaster recovery replicas
```

## Hub-Spoke Network Topology (with Transit Gateway)

```
                        ┌─────────────────────────────────────┐
                        │     Network Hub Account (AWS)       │
                        │   ┌────────────────────────────┐   │
                        │   │   Transit Gateway (TGW)    │   │
                        │   │  - Default RT: disabled    │   │
                        │   │  - 5 Spoke RTs per env    │   │
                        │   └────────────────────────────┘   │
                        │             ▲                       │
                  ┌─────┼─────────────┼─────────────┬─────┐  │
                  │     │             │             │     │  │
        ┌─────────┴──┐  │  ┌──────────┴───┐  ┌─────┴──────┴─────┐
        │   Hub VPC  │  │  │ Firewall     │  │  RAM Share (TGW)│
        │ 10.1.0.0/16│  │  │ Endpoints    │  └──────────────────┘
        │            │  │  └──────────────┘        ▲
        │ Subnets:   │  │                          │
        │ Pub (IGW)  │  │      ┌──────────────────┘
        │ Tran (TGW) │  │      │
        │ Data (NAT) │  │      │
        └────────────┘  │      │
                        │      │
        ─────────────────┴──────┴───────────────────────────────
        │                                              │
        ▼                                              ▼
    
    ┌──────────────────┐              ┌──────────────────┐
    │ Dev VPC          │              │ Staging VPC      │
    │ 10.10.0.0/16     │              │ 10.20.0.0/16     │
    ├──────────────────┤              ├──────────────────┤
    │ Public (ALB/NAT) │              │ Public (ALB/NAT) │
    │ ├─ a.10.0.0/24   │              │ ├─ a.20.0.0/24   │
    │ ├─ b.10.1.0/24   │              │ ├─ b.20.1.0/24   │
    │ └─ c.10.2.0/24   │              │ └─ c.20.2.0/24   │
    │                  │              │                  │
    │ Transit (TGW)    │              │ Transit (TGW)    │
    │ ├─ a.10.4.0/24   │              │ ├─ a.20.4.0/24   │
    │ ├─ b.10.5.0/24   │              │ ├─ b.20.5.0/24   │
    │ └─ c.10.6.0/24   │              │ └─ c.20.6.0/24   │
    │                  │              │                  │
    │ App Private      │              │ App Private      │
    │ ├─ a.10.8.0/24   │              │ ├─ a.20.8.0/24   │
    │ ├─ b.10.9.0/24   │              │ ├─ b.20.9.0/24   │
    │ └─ c.10.10.0/24  │              │ └─ c.20.10.0/24  │
    │                  │              │                  │
    │ Data Private     │              │ Data Private     │
    │ ├─ a.10.24.0/25  │              │ ├─ a.20.24.0/25  │
    │ ├─ b.10.24.128/25│              │ ├─ b.20.24.128/25│
    │ └─ c.10.25.0/25  │              │ └─ c.20.25.0/25  │
    └──────────────────┘              └──────────────────┘
            ▲                                  ▲
            │                                  │
            └──────────┬───────────────────────┘
                       │
                   TGW RT: all spokes
                   0.0.0.0/0 → local
    
    ┌──────────────────────────────────────────────┐
    │ Prod VPC                                     │
    │ 10.30.0.0/16                                │
    ├──────────────────────────────────────────────┤
    │ (Same subnet structure as Dev/Staging)      │
    └──────────────────────────────────────────────┘
```

## EKS Cluster Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│ EKS Platform Account: EKS Cluster (enterprise-mod-prod-eks)     │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │ EKS Control Plane (AWS Managed)                          │  │
│  │ ├─ API Server (TLS 1.3)                                  │  │
│  │ ├─ etcd (encrypted at rest)                              │  │
│  │ ├─ kube-controller-manager                               │  │
│  │ ├─ kube-scheduler                                        │  │
│  │ └─ kubelet (agent on nodes)                              │  │
│  │                                                           │  │
│  │ Logging: API, Audit, Auth, Controller, Scheduler         │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │ Worker Nodes (Multi-AZ)                                  │  │
│  │                                                           │  │
│  │  AZ-a                  AZ-b                  AZ-c        │  │
│  │  ┌──────────┐         ┌──────────┐         ┌──────────┐ │  │
│  │  │ Linux    │         │ Linux    │         │ Linux    │ │  │
│  │  │ m6i.xl   │         │ m6i.xl   │         │ m6i.xl   │ │  │
│  │  │ (AL2023) │         │ (AL2023) │         │ (AL2023) │ │  │
│  │  │ ─────────│         │ ─────────│         │ ─────────│ │  │
│  │  │ 30 pods  │         │ 30 pods  │         │ 30 pods  │ │  │
│  │  └──────────┘         └──────────┘         └──────────┘ │  │
│  │                                                           │  │
│  │  Windows (Optional)    (Optional)          (Optional)    │  │
│  │  ┌──────────┐         ┌──────────┐         ┌──────────┐ │  │
│  │  │ Windows  │         │ Windows  │         │ Windows  │ │  │
│  │  │ m6i.2xl  │         │ m6i.2xl  │         │ m6i.2xl  │ │  │
│  │  │ 2022 Core│         │ 2022 Core│         │ 2022 Core│ │  │
│  │  │ ─────────│         │ ─────────│         │ ─────────│ │  │
│  │  │ 10 pods  │         │ 10 pods  │         │ 10 pods  │ │  │
│  │  └──────────┘         └──────────┘         └──────────┘ │  │
│  │                                                           │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │ EKS Managed Add-ons                                      │  │
│  │ ├─ VPC CNI (aws-vpc): Pod networking                     │  │
│  │ ├─ CoreDNS (v1.10): Service discovery                    │  │
│  │ ├─ kube-proxy (v1.30): Network rules                     │  │
│  │ └─ AWS EBS CSI Driver: Persistent volumes               │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │ IRSA (IAM Roles for Service Accounts)                    │  │
│  │ ├─ OIDC Provider: ${TGW-ID}.eks.amazonaws.com           │  │
│  │ ├─ ServiceAccount → IAM Role mapping                     │  │
│  │ └─ Example: app-sa (namespace: apps) →                   │  │
│  │            arn:aws:iam::ACCOUNT:role/app-pod-role       │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## Data Flow: Request Path (North-South)

```
                      Internet (0.0.0.0/0)
                              │
                              ▼
                    ┌──────────────────┐
                    │ Internet Gateway │ (Hub VPC)
                    └────────┬─────────┘
                             │
                             ▼
                    ┌──────────────────┐
                    │   Public Subnet  │ (ALB/Ingress)
                    │  10.1.0.0/24     │
                    └────────┬─────────┘
                             │
                             ▼
                    ┌──────────────────────┐
                    │  Network Firewall    │
                    │  (rule evaluation)   │
                    └────────┬─────────────┘
                             │
                             ▼
                    ┌──────────────────┐
                    │  Transit Gateway │
                    │   (routing TGW)  │
                    └────────┬─────────┘
                             │
        ┌────────────────────┼────────────────────┐
        │                    │                    │
        ▼                    ▼                    ▼
  ┌──────────┐         ┌──────────┐         ┌──────────┐
  │ Spoke RT │         │ Spoke RT │         │ Spoke RT │
  │ (Dev)    │         │(Staging) │         │ (Prod)   │
  │ Transit  │         │ Transit  │         │ Transit  │
  └────┬─────┘         └────┬─────┘         └────┬─────┘
       │                    │                    │
       ▼                    ▼                    ▼
  ┌──────────┐         ┌──────────┐         ┌──────────┐
  │App Subnet│         │App Subnet│         │App Subnet│
  │10.10.0/24         │10.20.0/24         │10.30.0/24│
  └─────┬────┘         └────┬─────┘         └────┬─────┘
        │                   │                    │
        ▼                   ▼                    ▼
    [EKS Pods]        [EKS Pods]            [EKS Pods]
 (via kube-proxy)  (via kube-proxy)      (via kube-proxy)
```

## Data Flow: Egress Path (East-West & South)

```
EKS Pod (10.40.x.x)
        │
        ▼
   [CoreDNS]
        │
        ▼
   [kube-proxy]
        │
        ▼
   AWS VPC CNI (eni-xxx)
        │
        ▼
   App Private Subnet (10.40.8.0/24)
        │
        ▼
   Route Table: 0.0.0.0/0 → NAT Gateway
        │
        ▼
   NAT Gateway (Elastic IP)
        │
        ▼
   Transit Gateway (routing)
        │
        ▼
   Hub VPC: Transit Subnet (10.1.4.0/24)
        │
        ▼
   ┌─────────────────────────────────┐
   │  Network Firewall Inspection    │
   │  ├─ Stateless rules (100)       │
   │  │  └─ DENYLIST (malicious)     │
   │  └─ Stateful rules (200)        │
   │     └─ ALLOWLIST (internal)     │
   └─────────────┬───────────────────┘
                 │
        ┌────────┴──────────┐
        │                   │
        ▼                   ▼
    [ALLOWED]         [DROPPED]
        │                  │
        ▼                  ▼
  Internet Gateway  CloudWatch Logs
        │           /aws/networkfirewall/alert
        │
        ▼
   Internet (0.0.0.0/0)
```

## Cross-Account IAM Model

```
Management Account
├─ Root User
├─ OrganizationAccountAccessRole (auto-created)
└─ Terraform Assume Role (with ExternalId)
        │
        ├─ Trust: All accounts (SCP boundary)
        │
        └─ Permissions:
           ├─ organizations:*
           ├─ ec2:*
           ├─ eks:*
           ├─ iam:*
           └─ s3:* (state only)

Workload Account (Dev/Staging/Prod)
├─ OrganizationAccountAccessRole
│   └─ Trust: Management account root
│
├─ cross-account-role
│   ├─ Trust:
│   │  └─ arn:aws:iam::MGMT:root
│   │     with Condition: sts:ExternalId
│   │
│   └─ Permissions:
│      ├─ ec2:Describe*, ec2:RunInstances
│      ├─ ssm:SendCommand
│      ├─ logs:PutLogEvents
│      ├─ s3:GetObject (terraform state)
│      └─ Deny: DeleteSecurityGroup, DeleteVpc
│
└─ Permission Boundary
    └─ Prevents: EC2 termination, VPC deletion

EKS Platform Account
├─ EKS Service Role
│   ├─ Trust: eks.amazonaws.com
│   └─ Policy: AmazonEKSClusterPolicy
│
├─ EKS Node Group Role
│   ├─ Trust: ec2.amazonaws.com
│   └─ Policy:
│      ├─ AmazonEKSWorkerNodePolicy
│      ├─ AmazonEKS_CNI_Policy
│      ├─ AmazonEC2ContainerRegistryReadOnly
│      └─ AmazonSSMManagedInstanceCore
│
└─ Pod Execution Role (IRSA)
    ├─ Trust: OIDC Provider
    │         (sts:AssumeRoleWithWebIdentity)
    │
    └─ Permissions: Per-pod scoped
       ├─ s3:GetObject
       ├─ dynamodb:Query
       └─ secretsmanager:GetSecretValue
```

## Observability & Logging Architecture

```
┌──────────────────────────────────────┐
│      Logging Sources                  │
├──────────────────────────────────────┤
│ EKS Control Plane Logs                │
│ ├─ /aws/eks/cluster/api               │
│ ├─ /aws/eks/cluster/audit             │
│ ├─ /aws/eks/cluster/authenticator    │
│ ├─ /aws/eks/cluster/controllerManager │
│ └─ /aws/eks/cluster/scheduler         │
│                                       │
│ Application Logs (stdout/stderr)      │
│ ├─ JSON structured logs               │
│ ├─ Via STDOUT → kubelet → CW Logs     │
│ └─ Namespace: /aws/eks/apps           │
│                                       │
│ Infrastructure Logs                   │
│ ├─ VPC Flow Logs (all traffic)        │
│ ├─ Network Firewall Logs              │
│ │  ├─ /aws/networkfirewall/alert      │
│ │  └─ /aws/networkfirewall/flow       │
│ ├─ CloudTrail Events                  │
│ └─ Config Changes                     │
│                                       │
│ Windows Event Logs (via SSM)          │
│ ├─ System events                      │
│ ├─ Application events                 │
│ ├─ Security events                    │
│ └─ IIS logs                           │
└──────────┬───────────────────────────┘
           │
           ▼
    ┌────────────────────┐
    │   CloudWatch Logs  │
    │                    │
    │ Log Groups:        │
    │ ├─ /aws/eks/*      │
    │ ├─ /aws/nfw/*      │
    │ ├─ /aws/ssm/*      │
    │ └─ /aws/lambda/*   │
    │                    │
    │ Retention: 30 days │
    │ Encrypted: KMS     │
    └────────┬───────────┘
             │
             ├────────────────────┬────────────────────┐
             │                    │                    │
             ▼                    ▼                    ▼
    ┌──────────────────┐  ┌──────────────────┐  ┌──────────────┐
    │  Metric Filters  │  │  Log Insights    │  │   OpenSearch │
    │                  │  │                  │  │              │
    │  CloudWatch      │  │  Ad-hoc queries  │  │ Full-text    │
    │  Metrics         │  │  on log data     │  │ indexing &   │
    │  (via filters)   │  │                  │  │ analysis     │
    └────────┬─────────┘  └──────────────────┘  │              │
             │                                   │ Kibana       │
             ▼                                   │ Dashboard    │
    ┌──────────────────┐                        └──────────────┘
    │   Alarms/SNS     │                              ▲
    │                  │                              │
    │ Trigger: CPUHigh │         ┌────────────────────┘
    │ Trigger: MemHigh │         │
    │ Trigger: DiskFull
    │                  │         │
    └────────┬─────────┘         │
             │              CloudWatch
             ▼              Subscription
    ┌──────────────────┐   Filter
    │    SNS Topic     │─────────┘
    │                  │
    │ alert@example.com
    │ slack-webhook
    │ pagerduty-api
    └──────────────────┘
```

## SCP (Service Control Policy) Enforcement

```
SCPs Attached to OU: "workload"

┌──────────────────────────────────────────────────────────┐
│ Policy: deny-destructive-actions                         │
├──────────────────────────────────────────────────────────┤
│ Effect: Deny                                             │
│ Actions:                                                 │
│  - s3:DeleteBucketEncryption                             │
│  - kms:ScheduleKeyDeletion                               │
│  - ec2:DeleteSecurityGroup                               │
│  - ec2:DeleteVpc                                         │
│  - ec2:DeleteSubnet                                      │
│  - rds:DeleteDBInstance (Prod only)                      │
│  - lambda:DeleteFunction (Prod only)                     │
│                                                          │
│ Condition: Always (all accounts in workload OU)          │
│                                                          │
│ Result:                                                  │
│ ✓ Dev account: Can destroy resources (agile)            │
│ ✓ Staging: Limited deletions (promoted to prod path)    │
│ ✗ Prod account: No destruction (fail-safe)              │
└──────────────────────────────────────────────────────────┘
```

## Terraform State Isolation

```
S3 Backend: enterprise-mod-terraform-state-123456789012

├── prod/                          (Management account)
│   ├── terraform.tfstate
│   ├── terraform.tfstate.backup
│   └── .terraform.lock.hcl
│
├── workload/dev/                  (Dev account)
│   ├── terraform.tfstate
│   ├── terraform.tfstate.backup
│   └── .terraform.lock.hcl
│
├── workload/staging/              (Staging account)
│   ├── terraform.tfstate
│   ├── terraform.tfstate.backup
│   └── .terraform.lock.hcl
│
└── workload/prod/                 (Prod account)
    ├── terraform.tfstate
    ├── terraform.tfstate.backup
    └── .terraform.lock.hcl

DynamoDB: terraform-locks
└── LockID (Partition Key)
    ├─ enterprise-mod-terraform-state/prod/terraform.tfstate
    ├─ enterprise-mod-terraform-state/workload/dev/terraform.tfstate
    ├─ enterprise-mod-terraform-state/workload/staging/terraform.tfstate
    └─ enterprise-mod-terraform-state/workload/prod/terraform.tfstate
```

---

**Architecture Version**: 1.0  
**Last Updated**: 2026-09-21  
**Compliance**: AWS Well-Architected Framework (all 6 pillars)
