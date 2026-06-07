# ---------------------------------------------------------------------------
# dns-hybrid/variables.tf
# ---------------------------------------------------------------------------

variable "name" {
  description = "Name prefix applied to all resources in this module."
  type        = string

  validation {
    condition     = length(var.name) > 0 && length(var.name) <= 64
    error_message = "name must be between 1 and 64 characters."
  }
}

variable "vpc_id" {
  description = "ID of the hub VPC that hosts the Route 53 Resolver endpoints."
  type        = string

  validation {
    condition     = can(regex("^vpc-[a-f0-9]+$", var.vpc_id))
    error_message = "vpc_id must be a valid VPC ID starting with 'vpc-'."
  }
}

variable "vpc_cidr" {
  description = "CIDR block of the hub VPC. Used in the Resolver endpoint security group."
  type        = string

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "vpc_cidr must be a valid IPv4 CIDR block."
  }
}

variable "resolver_subnet_ids" {
  description = "List of subnet IDs (one per AZ) to attach Route 53 Resolver endpoint ENIs to. Typically private subnets."
  type        = list(string)

  validation {
    condition     = length(var.resolver_subnet_ids) >= 2
    error_message = "At least two subnet IDs (one per AZ) are required for Resolver endpoint HA."
  }
}

variable "on_prem_cidrs" {
  description = "CIDR blocks of on-premises networks allowed to query the inbound Resolver endpoint."
  type        = list(string)
  default     = []
}

# ---------------------------------------------------------------------------
# Forwarding rules
# ---------------------------------------------------------------------------

variable "forwarding_rules" {
  description = <<-EOT
    Map of forwarding rules.  Key is a short rule identifier; value is an
    object with:
      domain     — the DNS domain to forward (e.g., "corp.internal")
      target_ips — list of objects with 'ip' (required) and 'port' (default 53)
  EOT
  type = map(object({
    domain = string
    target_ips = list(object({
      ip   = string
      port = optional(number, 53)
    }))
  }))
  default = {}
}

# ---------------------------------------------------------------------------
# Spoke VPC connectivity
# ---------------------------------------------------------------------------

variable "spoke_vpc_ids" {
  description = "List of spoke VPC IDs that should have forwarding rules and PHZs associated."
  type        = list(string)
  default     = []
}

# ---------------------------------------------------------------------------
# Private Hosted Zones
# ---------------------------------------------------------------------------

variable "private_hosted_zones" {
  description = <<-EOT
    Map of private hosted zones to create.  Key is a short logical name;
    value is an object with:
      domain   — DNS zone name (e.g., "hub.internal")
      comment  — (optional) zone comment
      records  — (optional) list of starter DNS records, each with:
                   name, type, ttl (default 300), records (list of values)
  EOT
  type = map(object({
    domain  = string
    comment = optional(string, "")
    records = optional(list(object({
      name    = string
      type    = string
      ttl     = optional(number, 300)
      records = list(string)
    })), [])
  }))
  default = {}
}

variable "cross_account_association_requests" {
  description = <<-EOT
    List of cross-account PHZ association authorisation requests (hub side).
    Each entry specifies a spoke VPC in a different account that should be
    authorised to associate with every PHZ managed by this module.
    Fields: vpc_id (required), vpc_region (required).
  EOT
  type = list(object({
    vpc_id     = string
    vpc_region = string
  }))
  default = []
}

# ---------------------------------------------------------------------------
# RAM sharing for resolver rules
# ---------------------------------------------------------------------------

variable "enable_ram_share" {
  description = "Share Resolver forwarding rules to spoke accounts via Resource Access Manager."
  type        = bool
  default     = false
}

variable "ram_principal_arns" {
  description = "AWS account IDs or OU ARNs to share Resolver rules with (requires enable_ram_share = true)."
  type        = list(string)
  default     = []
}

# ---------------------------------------------------------------------------
# Tagging
# ---------------------------------------------------------------------------

variable "tags" {
  description = "Tags merged onto every resource in this module."
  type        = map(string)
  default     = {}
}
