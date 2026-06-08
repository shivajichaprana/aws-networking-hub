# -----------------------------------------------------------------------------
# AWS Network Firewall — main.tf
#
# Creates an AWS Network Firewall with a stateful inspection policy for egress
# filtering. Designed to sit in a dedicated "Inspection VPC" (or the hub VPC)
# so that all spoke-to-internet traffic is inspected before leaving the network.
#
# Architecture:
#   Spoke VPC → TGW → Inspection VPC → [Network Firewall] → NAT GW → Internet
# -----------------------------------------------------------------------------

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

# ---------------------------------------------------------------------------
# Data sources
# ---------------------------------------------------------------------------

data "aws_region" "current" {}
data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

# ---------------------------------------------------------------------------
# Firewall Policy
# ---------------------------------------------------------------------------

resource "aws_networkfirewall_firewall_policy" "this" {
  name = "${var.name_prefix}-egress-policy"

  firewall_policy {
    # Default action for traffic not matching stateless rules: forward to stateful engine
    stateless_default_actions          = ["aws:forward_to_sfe"]
    stateless_fragment_default_actions = ["aws:forward_to_sfe"]

    # Stateful rule groups (evaluated in priority order)
    dynamic "stateful_rule_group_reference" {
      for_each = [
        aws_networkfirewall_rule_group.domain_blocklist.arn,
        aws_networkfirewall_rule_group.tls_sni_allowlist.arn,
      ]
      content {
        resource_arn = stateful_rule_group_reference.value
      }
    }

    # Default stateful action: DROP unmatched traffic (deny-by-default egress)
    stateful_default_actions = ["aws:drop_strict"]

    stateful_engine_options {
      rule_order = "STRICT_ORDER"
    }
  }

  tags = merge(var.tags, {
    Name    = "${var.name_prefix}-egress-policy"
    Module  = "network-firewall"
    ManagedBy = "terraform"
  })
}

# ---------------------------------------------------------------------------
# Network Firewall
# ---------------------------------------------------------------------------

resource "aws_networkfirewall_firewall" "this" {
  name                = "${var.name_prefix}-egress-fw"
  description         = "Stateful egress firewall for hub-and-spoke networking (${var.name_prefix})"
  firewall_policy_arn = aws_networkfirewall_firewall_policy.this.arn
  vpc_id              = var.inspection_vpc_id

  # One firewall endpoint per AZ/subnet (traffic must be routed to these endpoints)
  dynamic "subnet_mapping" {
    for_each = var.firewall_subnet_ids
    content {
      subnet_id = subnet_mapping.value
    }
  }

  # Reject the update request if the firewall policy would cause traffic disruption
  firewall_policy_change_protection = var.enable_change_protection
  subnet_change_protection          = var.enable_change_protection

  tags = merge(var.tags, {
    Name    = "${var.name_prefix}-egress-fw"
    Module  = "network-firewall"
    ManagedBy = "terraform"
  })

  # Logging is configured separately (depends on CloudWatch log groups)
  depends_on = [aws_cloudwatch_log_group.flow, aws_cloudwatch_log_group.alert]
}

# ---------------------------------------------------------------------------
# Logging Configuration  (defined here; log group resources are in logging.tf)
# ---------------------------------------------------------------------------

resource "aws_networkfirewall_logging_configuration" "this" {
  firewall_arn = aws_networkfirewall_firewall.this.arn

  logging_configuration {
    # FLOW logs — capture all accepted/dropped connections
    log_destination_config {
      log_type             = "FLOW"
      log_destination_type = "CloudWatchLogs"
      log_destination = {
        logGroup = aws_cloudwatch_log_group.flow.name
      }
    }

    # ALERT logs — capture rule matches (blocked domains, SNI violations)
    log_destination_config {
      log_type             = "ALERT"
      log_destination_type = "CloudWatchLogs"
      log_destination = {
        logGroup = aws_cloudwatch_log_group.alert.name
      }
    }

    # ALERT logs also forwarded to S3 for long-term retention + Athena queries
    log_destination_config {
      log_type             = "ALERT"
      log_destination_type = "S3"
      log_destination = {
        bucketName = aws_s3_bucket.logs.bucket
        prefix     = "network-firewall/alerts"
      }
    }
  }

  depends_on = [
    aws_cloudwatch_log_group.flow,
    aws_cloudwatch_log_group.alert,
    aws_s3_bucket.logs,
    aws_s3_bucket_policy.logs,
  ]
}
