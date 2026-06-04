# ---------------------------------------------------------------------------
# Transit Gateway Module — variables.tf
# ---------------------------------------------------------------------------

variable "name" {
  description = "Name prefix applied to the TGW and all child resources."
  type        = string

  validation {
    condition     = length(var.name) > 0 && length(var.name) <= 64
    error_message = "name must be between 1 and 64 characters."
  }
}

variable "amazon_side_asn" {
  description = "Private BGP ASN for the Transit Gateway. Must be in 64512-65534 or 4200000000-4294967294."
  type        = number
  default     = 64512

  validation {
    condition = (
      (var.amazon_side_asn >= 64512 && var.amazon_side_asn <= 65534) ||
      (var.amazon_side_asn >= 4200000000 && var.amazon_side_asn <= 4294967294)
    )
    error_message = "amazon_side_asn must be in range 64512-65534 or 4200000000-4294967294."
  }
}

variable "dns_support" {
  description = "Enable DNS resolution across TGW attachments."
  type        = string
  default     = "enable"

  validation {
    condition     = contains(["enable", "disable"], var.dns_support)
    error_message = "dns_support must be 'enable' or 'disable'."
  }
}

variable "vpn_ecmp_support" {
  description = "Enable ECMP support for VPN connections to the TGW."
  type        = string
  default     = "enable"

  validation {
    condition     = contains(["enable", "disable"], var.vpn_ecmp_support)
    error_message = "vpn_ecmp_support must be 'enable' or 'disable'."
  }
}

variable "auto_accept_shared" {
  description = "Auto-accept cross-account attachment requests via RAM."
  type        = string
  default     = "disable"

  validation {
    condition     = contains(["enable", "disable"], var.auto_accept_shared)
    error_message = "auto_accept_shared must be 'enable' or 'disable'."
  }
}

# ---------------------------------------------------------------------------
# Spoke attachment variables
# ---------------------------------------------------------------------------

variable "prod_spoke_vpc_ids" {
  description = "List of production VPC IDs to attach to the TGW."
  type        = list(string)
  default     = []
}

variable "nonprod_spoke_vpc_ids" {
  description = "List of non-production VPC IDs to attach to the TGW."
  type        = list(string)
  default     = []
}

variable "prod_spoke_subnet_ids" {
  description = "Map of prod VPC ID → list of TGW-attachment subnet IDs (one /28 per AZ)."
  type        = map(list(string))
  default     = {}
}

variable "nonprod_spoke_subnet_ids" {
  description = "Map of non-prod VPC ID → list of TGW-attachment subnet IDs (one /28 per AZ)."
  type        = map(list(string))
  default     = {}
}

# ---------------------------------------------------------------------------
# Route table variables
# ---------------------------------------------------------------------------

variable "enable_shared_services_route_table" {
  description = "Create an additional TGW route table for shared-services VPCs visible to both tiers."
  type        = bool
  default     = false
}

variable "prod_blackhole_routes" {
  description = "CIDRs to blackhole in the prod route table (block inbound from non-prod super-nets)."
  type        = list(string)
  default     = []
}

variable "nonprod_blackhole_routes" {
  description = "CIDRs to blackhole in the non-prod route table (block inbound from prod super-nets)."
  type        = list(string)
  default     = []
}

# ---------------------------------------------------------------------------
# Resource Access Manager (RAM) variables
# ---------------------------------------------------------------------------

variable "enable_resource_share" {
  description = "Share the TGW across AWS accounts via Resource Access Manager."
  type        = bool
  default     = false
}

variable "ram_allow_external_principals" {
  description = "Allow external AWS accounts (outside the Organization) to attach to this TGW."
  type        = bool
  default     = false
}

variable "ram_principal_arns" {
  description = "List of AWS account IDs or Organization/OU ARNs that may attach spokes."
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
