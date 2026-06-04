# ---------------------------------------------------------------------------
# Root variables
# ---------------------------------------------------------------------------

variable "region" {
  description = "AWS region to deploy the networking hub in."
  type        = string
  default     = "us-east-1"
}

variable "tgw_name" {
  description = "Name tag applied to the Transit Gateway and all related resources."
  type        = string
  default     = "hub"

  validation {
    condition     = length(var.tgw_name) > 0 && length(var.tgw_name) <= 64
    error_message = "tgw_name must be between 1 and 64 characters."
  }
}

variable "amazon_side_asn" {
  description = "Private ASN for the Transit Gateway BGP sessions (64512–65534 or 4200000000–4294967294)."
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

variable "tgw_dns_support" {
  description = "Enable DNS support on the Transit Gateway."
  type        = string
  default     = "enable"

  validation {
    condition     = contains(["enable", "disable"], var.tgw_dns_support)
    error_message = "tgw_dns_support must be 'enable' or 'disable'."
  }
}

variable "tgw_vpn_ecmp_support" {
  description = "Enable Equal-Cost Multi-Path routing for VPN connections."
  type        = string
  default     = "enable"

  validation {
    condition     = contains(["enable", "disable"], var.tgw_vpn_ecmp_support)
    error_message = "tgw_vpn_ecmp_support must be 'enable' or 'disable'."
  }
}

variable "tgw_auto_accept_shared" {
  description = "Auto-accept TGW attachment sharing via Resource Access Manager."
  type        = string
  default     = "disable"

  validation {
    condition     = contains(["enable", "disable"], var.tgw_auto_accept_shared)
    error_message = "tgw_auto_accept_shared must be 'enable' or 'disable'."
  }
}

variable "prod_spoke_vpc_ids" {
  description = "List of production VPC IDs to attach to the TGW prod route table."
  type        = list(string)
  default     = []
}

variable "nonprod_spoke_vpc_ids" {
  description = "List of non-production VPC IDs to attach to the TGW non-prod route table."
  type        = list(string)
  default     = []
}

variable "prod_spoke_subnet_ids" {
  description = "Map of prod VPC ID → list of TGW attachment subnet IDs (one per AZ)."
  type        = map(list(string))
  default     = {}
}

variable "nonprod_spoke_subnet_ids" {
  description = "Map of non-prod VPC ID → list of TGW attachment subnet IDs (one per AZ)."
  type        = map(list(string))
  default     = {}
}

variable "default_tags" {
  description = "Tags applied to every resource."
  type        = map(string)
  default     = {}
}
