resource "aws_ec2_network_insights_path" "egress_path" {
  count = var.enable_network_firewall ? 1 : 0
  
  source      = module.eks_vpc.nat_gateway_ids[0]
  destination = "203.0.113.0"
  protocol    = "tcp"

  tags = merge(
    local.common_tags,
    {
      Name = "${var.environment}-egress-insights"
    }
  )
}

resource "aws_networkfirewall_firewall_policy" "egress_policy" {
  count = var.enable_network_firewall ? 1 : 0
  name  = "${var.environment}-egress-firewall-policy"

  firewall_policy {
    stateless_default_actions          = ["aws:pass"]
    stateless_fragment_default_actions = ["aws:pass"]

    stateless_rule_group_reference {
      priority           = 1
      resource_arn       = aws_networkfirewall_rule_group.stateless[0].arn
    }

    stateful_engine_options {
      rule_order = "STRICT_ORDER"
    }

    stateful_rule_group_reference {
      priority      = 1
      resource_arn  = aws_networkfirewall_rule_group.stateful_domain_allow[0].arn
    }

    stateful_rule_group_reference {
      priority      = 2
      resource_arn  = aws_networkfirewall_rule_group.stateful_domain_deny[0].arn
    }
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${var.environment}-egress-firewall-policy"
    }
  )
}

resource "aws_networkfirewall_rule_group" "stateless" {
  count    = var.enable_network_firewall ? 1 : 0
  name     = "${var.environment}-stateless-rules"
  type     = "STATELESS"
  capacity = 100

  rule_group {
    rules_source {
      stateless_rules_and_custom_actions {
        stateless_rule {
          priority = 1
          rule_definition {
            actions = ["aws:pass"]
            match_attributes {
              destination {
                address_definition = "0.0.0.0/0"
              }
              destination_port {
                from_port = 443
                to_port   = 443
              }
              protocols = [6]
              source {
                address_definition = "10.0.0.0/8"
              }
            }
          }
        }

        stateless_rule {
          priority = 2
          rule_definition {
            actions = ["aws:drop"]
            match_attributes {
              destination {
                address_definition = "0.0.0.0/0"
              }
              protocols = [6]
              source {
                address_definition = "10.0.0.0/8"
              }
            }
          }
        }
      }
    }
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${var.environment}-stateless-rules"
    }
  )
}

resource "aws_networkfirewall_rule_group" "stateful_domain_allow" {
  count    = var.enable_network_firewall ? 1 : 0
  name     = "${var.environment}-domain-allow-rules"
  type     = "STATEFUL"
  capacity = 1000

  rule_group {
    rule_variables {
      ip_sets {
        key = "HOME_NET"
        ip_set {
          definition = ["10.0.0.0/8"]
        }
      }
    }

    rules_source {
      rules_string = join("\n", [
        "pass http $HOME_NET any -> any any (msg:\"Allow AWS API\"; flow:to_server; content:\"Host|3b| api.aws.amazonaws.com\"; http_header; sid:1001;)",
        "pass https $HOME_NET any -> any any (msg:\"Allow AWS API HTTPS\"; flow:to_server; content:\"Host|3b| api.aws.amazonaws.com\"; http_header; sid:1002;)",
        "pass https $HOME_NET any -> any any (msg:\"Allow GitHub HTTPS\"; flow:to_server; content:\"Host|3b| github.com\"; http_header; sid:1003;)",
        "pass https $HOME_NET any -> any any (msg:\"Allow Docker Hub HTTPS\"; flow:to_server; content:\"Host|3b| registry.hub.docker.com\"; http_header; sid:1004;)"
      ])
    }
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${var.environment}-domain-allow-rules"
    }
  )
}

resource "aws_networkfirewall_rule_group" "stateful_domain_deny" {
  count    = var.enable_network_firewall ? 1 : 0
  name     = "${var.environment}-domain-deny-rules"
  type     = "STATEFUL"
  capacity = 1000

  rule_group {
    rules_source {
      rules_string = join("\n", [
        "drop http $HOME_NET any -> any any (msg:\"Drop unencrypted HTTP\"; flow:to_server; sid:2001;)",
        "drop https $HOME_NET any -> any 53 (msg:\"Drop DNS over HTTPS\"; sid:2002;)"
      ])
    }
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${var.environment}-domain-deny-rules"
    }
  )
}

resource "aws_networkfirewall_firewall" "main" {
  count = var.enable_network_firewall ? 1 : 0

  name                = "${var.environment}-egress-firewall"
  firewall_policy_arn = aws_networkfirewall_firewall_policy.egress_policy[0].arn
  vpc_id              = module.network_hub_vpc.vpc_id
  subnet_mapping {
    subnet_id = module.network_hub_vpc.private_subnets[0]
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${var.environment}-egress-firewall"
    }
  )
}

resource "aws_cloudwatch_log_group" "firewall_flow_logs" {
  count             = var.enable_network_firewall ? 1 : 0
  name              = "/aws/networkfirewall/${var.environment}/flow-logs"
  retention_in_days = var.log_retention_days

  tags = merge(
    local.common_tags,
    {
      Name = "/aws/networkfirewall/${var.environment}/flow-logs"
    }
  )
}

resource "aws_cloudwatch_log_group" "firewall_alert_logs" {
  count             = var.enable_network_firewall ? 1 : 0
  name              = "/aws/networkfirewall/${var.environment}/alert-logs"
  retention_in_days = var.log_retention_days

  tags = merge(
    local.common_tags,
    {
      Name = "/aws/networkfirewall/${var.environment}/alert-logs"
    }
  )
}
