# ---------------------------------------------------------------------------
# dns-hybrid/private-hosted-zones.tf
#
# Private Hosted Zone (PHZ) management for the hub-and-spoke network.
#
# PHZs created here are associated with:
#   1. The hub VPC (always)
#   2. Every spoke VPC listed in var.spoke_vpc_ids
#
# This allows workloads in any spoke to resolve private records (e.g.,
# hub.internal, shared-services.internal) without the records being
# publicly resolvable.
#
# Optionally, PHZs can be associated across accounts by attaching them
# to spoke VPCs in separate AWS accounts.  Cross-account associations
# require a one-time authorisation from the zone-owning account — see
# docs/privatelink-guide.md for the manual step.
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# Private Hosted Zones
# ---------------------------------------------------------------------------

resource "aws_route53_zone" "private" {
  for_each = var.private_hosted_zones

  name    = each.value.domain
  comment = lookup(each.value, "comment", "Managed by Terraform — ${each.key}")

  # Associate with the hub VPC during zone creation.
  vpc {
    vpc_id     = var.vpc_id
    vpc_region = data.aws_region.current.name
  }

  # Prevent accidental deletion — zones must be emptied before destroy.
  lifecycle {
    prevent_destroy = false
    # In production, set prevent_destroy = true and manage deletion manually.
  }

  tags = merge(local.common_tags, {
    Name        = each.key
    Domain      = each.value.domain
    ZoneType    = "private"
  })
}

# ---------------------------------------------------------------------------
# PHZ records defined inline
#
# Allows callers to seed starter records (e.g., CNAME → NLB DNS name,
# A record for a shared service).
# ---------------------------------------------------------------------------

resource "aws_route53_record" "phz_records" {
  for_each = {
    for r in flatten([
      for zone_key, zone in var.private_hosted_zones : [
        for record in lookup(zone, "records", []) : {
          key     = "${zone_key}__${record.name}__${record.type}"
          zone_id = aws_route53_zone.private[zone_key].zone_id
          name    = record.name
          type    = record.type
          ttl     = lookup(record, "ttl", 300)
          records = record.records
        }
      ]
    ]) : r.key => r
  }

  zone_id = each.value.zone_id
  name    = each.value.name
  type    = each.value.type
  ttl     = each.value.ttl
  records = each.value.records
}

# ---------------------------------------------------------------------------
# Associate PHZs with spoke VPCs
#
# The primary VPC association is done in the aws_route53_zone resource above.
# Additional associations are created here for every spoke VPC so that spoke
# workloads can resolve private records in each zone.
# ---------------------------------------------------------------------------

locals {
  # Build (zone_key × spoke_vpc_id) pairs, excluding the hub VPC which is
  # already associated inside the zone resource.
  phz_spoke_associations = {
    for pair in flatten([
      for zone_key in keys(var.private_hosted_zones) : [
        for vpc_id in var.spoke_vpc_ids : {
          key     = "${zone_key}__${vpc_id}"
          zone_id = aws_route53_zone.private[zone_key].zone_id
          vpc_id  = vpc_id
        }
      ]
    ]) : pair.key => pair
  }
}

resource "aws_route53_zone_association" "spoke_phz" {
  for_each = local.phz_spoke_associations

  zone_id = each.value.zone_id
  vpc_id  = each.value.vpc_id

  # Note: Cross-account associations (where the spoke VPC is in a different
  # account) require a separate aws_route53_vpc_association_authorization
  # resource in the zone-owning account BEFORE this association can be applied
  # from the spoke account.  See docs/hybrid-dns.md for the full procedure.
}

# ---------------------------------------------------------------------------
# Cross-account zone authorisations (hub side)
#
# When spoke VPCs live in separate AWS accounts, the zone owner (this account)
# must authorise the association before the spoke account can associate.
# var.cross_account_association_requests lists those authorisations.
# ---------------------------------------------------------------------------

resource "aws_route53_vpc_association_authorization" "cross_account" {
  for_each = {
    for pair in flatten([
      for zone_key in keys(var.private_hosted_zones) : [
        for req in var.cross_account_association_requests : {
          key     = "${zone_key}__${req.vpc_id}"
          zone_id = aws_route53_zone.private[zone_key].zone_id
          vpc_id  = req.vpc_id
          region  = req.vpc_region
        }
      ]
    ]) : pair.key => pair
  }

  zone_id    = each.value.zone_id
  vpc_id     = each.value.vpc_id
  vpc_region = each.value.region
}
