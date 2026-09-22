resource "aws_ssm_document" "linux_diagnostics" {
  name            = "${var.environment}-linux-diagnostics"
  document_type   = "Command"
  document_format = "JSON"

  content = jsonencode({
    schemaVersion = "2.2"
    description   = "Automated Linux Service Health and Diagnostics Check"
    mainSteps = [
      {
        action = "aws:runShellScript"
        name   = "linux_health_check"
        onFailure = "Continue"
        inputs = {
          runCommand = [
            "#!/bin/bash",
            "set -euo pipefail",
            "echo '=== Linux Service Health Check ==='",
            "echo 'Checking critical services...'",
            "systemctl is-active --quiet nginx && echo 'Nginx: RUNNING' || echo 'Nginx: STOPPED'",
            "systemctl is-active --quiet apache2 && echo 'Apache: RUNNING' || echo 'Apache: STOPPED'",
            "systemctl is-active --quiet docker && echo 'Docker: RUNNING' || echo 'Docker: STOPPED'",
            "",
            "echo '=== Memory and Disk Usage ==='",
            "echo 'Memory Usage:'",
            "free -h | grep Mem",
            "echo ''",
            "echo 'Disk Usage (Critical >85%):'",
            "df -h | awk 'NR==1 || $5 > 85 {print $0}'",
            "",
            "echo '=== Top 5 Memory Consuming Processes ==='",
            "ps aux --sort=-%mem | head -6",
            "",
            "echo '=== Top 5 CPU Consuming Processes ==='",
            "ps aux --sort=-%cpu | head -6",
            "",
            "echo '=== Recent Critical Errors (Last 20) ==='",
            "journalctl -p 3 -n 20 --no-pager",
            "",
            "echo '=== Network Connectivity Check ==='",
            "netstat -tulpn | grep LISTEN | head -10",
            "",
            "echo '=== DNS Resolution Check ==='",
            "nslookup 8.8.8.8 || echo 'DNS resolution failed'",
            "",
            "echo '=== Network Statistics ==='",
            "ss -s",
            "",
            "echo 'Diagnostics collection completed at $(date)'"
          ]
        }
      }
    ]
  })

  tags = merge(
    local.common_tags,
    {
      Name = "${var.environment}-linux-diagnostics"
    }
  )
}

resource "aws_ssm_document" "windows_diagnostics" {
  name            = "${var.environment}-windows-diagnostics"
  document_type   = "Command"
  document_format = "JSON"

  content = jsonencode({
    schemaVersion = "2.2"
    description   = "Automated Windows Server Health and Diagnostics Check"
    mainSteps = [
      {
        action = "aws:runPowerShellScript"
        name   = "windows_health_check"
        onFailure = "Continue"
        inputs = {
          runCommand = [
            "$ErrorActionPreference = 'Continue'",
            "Write-Output '=== Windows Service Health Check ==='",
            "Write-Output 'Checking critical services...'",
            "$services = @('W3SVC', 'MSSQLSERVER', 'BITS', 'winrm')",
            "foreach ($service in $services) {",
            "  $svc = Get-Service -Name $service -ErrorAction SilentlyContinue",
            "  if ($svc) {",
            "    Write-Output \"$service`: $($svc.Status)\"",
            "  } else {",
            "    Write-Output \"$service`: NOT FOUND\"",
            "  }",
            "}",
            "",
            "Write-Output ''",
            "Write-Output '=== IIS Application Pool Status ==='",
            "Import-Module WebAdministration -ErrorAction SilentlyContinue",
            "Get-WebAppPool | Select-Object Name, State | Format-Table",
            "",
            "Write-Output ''",
            "Write-Output '=== IIS Web Site Status ==='",
            "Get-WebSite | Select-Object Name, State | Format-Table",
            "",
            "Write-Output ''",
            "Write-Output '=== Memory and Disk Usage ==='",
            "Write-Output 'Memory Usage:'",
            "$mem = (Get-WmiObject -Class Win32_ComputerSystem).TotalPhysicalMemory / 1GB",
            "$used = ((Get-WmiObject -Class Win32_OperatingSystem).TotalVisibleMemorySize - (Get-WmiObject -Class Win32_OperatingSystem).FreePhysicalMemory) / 1MB / 1024",
            "Write-Output \"Total: ${mem}GB, Used: ${used}GB\"",
            "",
            "Write-Output ''",
            "Write-Output 'Disk Usage (Critical >85%):'",
            "Get-Volume | Where-Object {$_.SizeRemaining -gt 0} | ForEach-Object {",
            "  $pctUsed = ([math]::Round((($_.Size - $_.SizeRemaining) / $_.Size) * 100))",
            "  if ($pctUsed -gt 85) {",
            "    Write-Output \"$($_.DriveLetter): $pctUsed% used\"",
            "  }",
            "}",
            "",
            "Write-Output ''",
            "Write-Output '=== Top 10 Memory Consuming Processes ==='",
            "Get-Process | Sort-Object -Property WorkingSet -Descending | Select-Object -First 10 Name, Id, WorkingSet | Format-Table",
            "",
            "Write-Output ''",
            "Write-Output '=== System Event Log Errors (Last 2 Hours) ==='",
            "Get-EventLog -LogName System -EntryType Error -After (Get-Date).AddHours(-2) -ErrorAction SilentlyContinue | Select-Object -First 5 TimeGenerated, Source, Message | Format-Table",
            "",
            "Write-Output ''",
            "Write-Output '=== Application Event Log Errors (Last 2 Hours) ==='",
            "Get-EventLog -LogName Application -EntryType Error -After (Get-Date).AddHours(-2) -ErrorAction SilentlyContinue | Select-Object -First 5 TimeGenerated, Source, Message | Format-Table",
            "",
            "Write-Output ''",
            "Write-Output '=== Network Configuration ==='",
            "Get-NetIPConfiguration | Format-Table",
            "",
            "Write-Output ''",
            "Write-Output 'Diagnostics collection completed at $(Get-Date)'"
          ]
        }
      }
    ]
  })

  tags = merge(
    local.common_tags,
    {
      Name = "${var.environment}-windows-diagnostics"
    }
  )
}

resource "aws_ssm_document" "eks_pod_diagnostics" {
  name            = "${var.environment}-eks-pod-diagnostics"
  document_type   = "Command"
  document_format = "JSON"

  content = jsonencode({
    schemaVersion = "2.2"
    description   = "EKS Pod and Cluster Diagnostics"
    mainSteps = [
      {
        action = "aws:runShellScript"
        name   = "eks_diagnostics"
        onFailure = "Continue"
        inputs = {
          runCommand = [
            "#!/bin/bash",
            "set -euo pipefail",
            "echo '=== EKS Cluster Diagnostics ==='",
            "echo 'Kubernetes Version:'",
            "kubectl version --short 2>/dev/null || echo 'kubectl not available'",
            "",
            "echo ''",
            "echo '=== Node Status ==='",
            "kubectl get nodes -o wide 2>/dev/null || echo 'Cannot fetch nodes'",
            "",
            "echo ''",
            "echo '=== Pod Status (All Namespaces) ==='",
            "kubectl get pods --all-namespaces -o wide 2>/dev/null || echo 'Cannot fetch pods'",
            "",
            "echo ''",
            "echo '=== Failed Pods ==='",
            "kubectl get pods --all-namespaces --field-selector=status.phase!=Running 2>/dev/null || echo 'Cannot fetch failed pods'",
            "",
            "echo ''",
            "echo '=== Node Resource Allocation ==='",
            "kubectl top nodes 2>/dev/null || echo 'Metrics server not available'",
            "",
            "echo ''",
            "echo '=== Pod Resource Usage ==='",
            "kubectl top pods --all-namespaces 2>/dev/null || echo 'Metrics server not available'",
            "",
            "echo ''",
            "echo 'EKS diagnostics completed at $(date)'"
          ]
        }
      }
    ]
  })

  tags = merge(
    local.common_tags,
    {
      Name = "${var.environment}-eks-pod-diagnostics"
    }
  )
}

resource "aws_iam_role" "ssm_automation_role" {
  name_prefix = "ssm-automation-"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ssm.amazonaws.com"
        }
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "ssm_automation_policy" {
  role       = aws_iam_role.ssm_automation_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonSSMAutomationRole"
}

resource "aws_iam_role_policy" "ssm_automation_custom_policy" {
  name_prefix = "ssm-automation-custom-"
  role        = aws_iam_role.ssm_automation_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances",
          "ssm:GetAutomationExecution",
          "ssm:StartAutomationExecution",
          "ssm:SendCommand",
          "ssm:GetCommandInvocation",
          "ssm:ListCommandInvocations"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_ssm_document" "automated_remediation" {
  name            = "${var.environment}-automated-remediation"
  document_type   = "Automation"
  document_format = "JSON"

  content = jsonencode({
    schemaVersion = "0.3"
    description   = "Automated remediation workflow for common failures"
    parameters = {
      InstanceId = {
        type        = "String"
        description = "EC2 Instance ID"
      }
      ActionType = {
        type        = "String"
        description = "Action to perform (restart_service, restart_instance, collect_logs)"
        allowedValues = ["restart_service", "restart_instance", "collect_logs"]
      }
      ServiceName = {
        type        = "String"
        description = "Service name to restart (if applicable)"
        default     = ""
      }
    }
    mainSteps = [
      {
        name   = "CheckInstanceStatus"
        action = "aws:executeAwsApi"
        inputs = {
          Service = "ec2"
          Api     = "DescribeInstanceStatus"
          InstanceIds = ["{{ InstanceId }}"]
        }
      },
      {
        name   = "ExecuteRemediationAction"
        action = "aws:branch"
        inputs = {
          Choices = [
            {
              NextStep    = "RestartService"
              Variable    = "{{ ActionType }}"
              StringEquals = "restart_service"
            },
            {
              NextStep    = "RestartInstance"
              Variable    = "{{ ActionType }}"
              StringEquals = "restart_instance"
            },
            {
              NextStep    = "CollectDiagnostics"
              Variable    = "{{ ActionType }}"
              StringEquals = "collect_logs"
            }
          ]
          Default = "CollectDiagnostics"
        }
      },
      {
        name   = "RestartService"
        action = "aws:executeAwsApi"
        inputs = {
          Service = "ssm"
          Api     = "SendCommand"
          InstanceIds = ["{{ InstanceId }}"]
          DocumentName = "${var.environment}-linux-diagnostics"
        }
      },
      {
        name   = "RestartInstance"
        action = "aws:executeAwsApi"
        inputs = {
          Service = "ec2"
          Api     = "RebootInstances"
          InstanceIds = ["{{ InstanceId }}"]
        }
      },
      {
        name   = "CollectDiagnostics"
        action = "aws:executeAwsApi"
        inputs = {
          Service = "ssm"
          Api     = "SendCommand"
          InstanceIds = ["{{ InstanceId }}"]
          DocumentName = "${var.environment}-linux-diagnostics"
        }
      }
    ]
  })

  tags = merge(
    local.common_tags,
    {
      Name = "${var.environment}-automated-remediation"
    }
  )
}
