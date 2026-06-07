# ---------------------------------------------------------------------------
# dns-hybrid/rules.tf
#
# Route 53 Resolver forwarding rules.
#
# Resolver rules tell the outbound endpoint where to send DNS queries for
# specific domains.  Two rule types are supported:
#
#   FORWARD  — send queries for a domain to the specified target IPs.
#              Used for on-premises (corp.internal) and partner domains.
#
#   SYSTEM   — override Route 53 default behaviour for a domain (e.g., force
#              a domain to resolve locally even when a FORWARD rule exists).
#
# Rules are shared to spoke VPCs via Resource Access Manager so that any
# VPC in the organisation can resolve on-premises records.
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# Forward rules — on-premises / private domains
# ---------------------------------------------------------------------------

resource "aws_route53_resolver_rule" "forward" {
  for_each = var.forwarding_rules

  name                 = replace("${local.name_prefix}-${each.key}", "/[^a-zA-Z0-9_-]/", "-")
  rule_type            = "FORWARD"
  domain_name          = each.value.domain
  resolver_endpoint_id = aws_route53_resolver_endpoint.outbound.id

  dynamic "target_ip" {
    for_each = each.value.target_ips
    content {
      ip   = target_ip.value.ip
      port = lookup(target_ip.value, "port", 53)
    }
  }

  tags = merge(local.common_tags, {
    Name       = replace("${local.name_prefix}-${each.key}", "/[^a-zA-Z0-9_-]/", "-")
    RuleType   = "FORWARD"
    TargetDomain = each.value.domain
  })
}

# ---------------------------------------------------------------------------
# Associate forwarding rules with the hub VPC
# ---------------------------------------------------------------------------

resource "aws_route53_resolver_rule_association" "forward_hub" {
  for_each = aws_route53_resolver_rule.forward

  resolver_rule_id = each.value.id
  vpc_id           = var.vpc_id
}

# ---------------------------------------------------------------------------
# Associate forwarding rules with spoke VPCs
#
# This creates a cross-product of (rule × spoke_vpc_id).  Each association
# lets the spoke VPC resolver use the forwarding rule.
# ---------------------------------------------------------------------------

locals {
  # Flatten (rule_key × spoke_vpc_id) into a map keyed by a unique string.
  spoke_rule_associations = {
    for pair in flatten([
      for rule_key, rule in aws_route53_resolver_rule.forward : [
        for vpc_id in var.spoke_vpc_ids : {
          key      = "${rule_key}__${vpc_id}"
          rule_id  = rule.id
          vpc_id   = vpc_id
        }
      ]
    ]) : pair.key => pair
  }
}

resource "aws_route53_resolver_rule_association" "forward_spokes" {
  for_each = local.spoke_rule_associations

  resolver_rule_id = each.value.rule_id
  vpc_id           = each.value.vpc_id
}

# ---------------------------------------------------------------------------
# RAM resource share — share rules to spoke accounts
#
# When spoke VPCs live in different AWS accounts (common in a multi-account
# landing zone), the rules must be shared via RAM before the associations
# above can succeed.
# ---------------------------------------------------------------------------

resource "aws_ram_resource_share" "resolver_rules" {
  count = var.enable_ram_share ? 1 : 0

  name                      = "${local.name_prefix}-resolver-rules"
  allow_external_principals = false

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-resolver-rules"
  })
}

resource "aws_ram_resource_association" "resolver_rules" {
  for_each = var.enable_ram_share ? aws_route53_resolver_rule.forward : {}

  resource_share_arn = aws_ram_resource_share.resolver_rules[0].arn
  resource_arn       = each.value.arn
}

resource "aws_ram_principal_association" "resolver_rules" {
  for_each = var.enable_ram_share ? toset(var.ram_principal_arns) : []

  resource_share_arn = aws_ram_resource_share.resolver_rules[0].arn
  principal          = each.value
}
