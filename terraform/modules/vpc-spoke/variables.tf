# ---------------------------------------------------------------------------
# VPC Spoke Module — variables.tf
# ---------------------------------------------------------------------------

variable "name" {
  description = "Name prefix applied to the VPC and all child resources."
  type        = string

  validation {
    condition     = length(var.name) > 0 && length(var.name) <= 64
    error_message = "name must be between 1 and 64 characters."
  }
}

variable "vpc_cidr" {
  description = "Primary CIDR block for the spoke VPC (e.g. '10.1.0.0/16')."
  type        = string

  validation {
    condition     = can(cidrnetmask(var.vpc_cidr))
    error_message = "vpc_cidr must be a valid CIDR block."
  }
}

variable "availability_zones" {
  description = "Ordered list of Availability Zone names to deploy subnets into (e.g. ['eu-west-1a','eu-west-1b'])."
  type        = list(string)

  validation {
    condition     = length(var.availability_zones) >= 2
    error_message = "At least 2 Availability Zones are required for high availability."
  }
}

# ---------------------------------------------------------------------------
# Public subnet settings
# ---------------------------------------------------------------------------

variable "public_subnets_enabled" {
  description = "Create public subnets and an Internet Gateway. Set to false for fully-private spokes."
  type        = bool
  default     = true
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets — one per AZ. Must be within vpc_cidr."
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for c in var.public_subnet_cidrs : can(cidrnetmask(c))])
    error_message = "Each public_subnet_cidr must be a valid CIDR block."
  }
}

variable "nat_gateway_enabled" {
  description = "Deploy a NAT Gateway in each public subnet AZ for private subnet egress."
  type        = bool
  default     = true
}

# ---------------------------------------------------------------------------
# Private subnet settings
# ---------------------------------------------------------------------------

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private (workload) subnets — one per AZ. Must be within vpc_cidr."
  type        = list(string)

  validation {
    condition     = length(var.private_subnet_cidrs) >= 2
    error_message = "At least 2 private subnet CIDRs are required (one per AZ)."
  }
}

# ---------------------------------------------------------------------------
# TGW attachment subnet settings
# ---------------------------------------------------------------------------

variable "tgw_subnet_cidrs" {
  description = "CIDR blocks for Transit Gateway attachment subnets — one /28 per AZ. Must be within vpc_cidr."
  type        = list(string)

  validation {
    condition     = length(var.tgw_subnet_cidrs) >= 2
    error_message = "At least 2 TGW subnet CIDRs are required (one per AZ)."
  }
}

# ---------------------------------------------------------------------------
# Transit Gateway attachment settings
# ---------------------------------------------------------------------------

variable "transit_gateway_id" {
  description = "ID of the Transit Gateway to attach this spoke VPC to."
  type        = string

  validation {
    condition     = can(regex("^tgw-[0-9a-f]{17}$", var.transit_gateway_id))
    error_message = "transit_gateway_id must match the pattern 'tgw-<17 hex chars>'."
  }
}

variable "tgw_route_table_id" {
  description = "TGW route table ID to associate this spoke attachment with (prod or nonprod)."
  type        = string

  validation {
    condition     = can(regex("^tgw-rtb-[0-9a-f]{17}$", var.tgw_route_table_id))
    error_message = "tgw_route_table_id must match the pattern 'tgw-rtb-<17 hex chars>'."
  }
}

variable "tgw_route_table_ids_to_propagate" {
  description = "Additional TGW route table IDs this attachment should propagate its CIDR into (e.g. shared-services table)."
  type        = list(string)
  default     = []
}

variable "tgw_appliance_mode_support" {
  description = "Enable appliance mode for traffic symmetry when routing through stateful appliances."
  type        = string
  default     = "disable"

  validation {
    condition     = contains(["enable", "disable"], var.tgw_appliance_mode_support)
    error_message = "tgw_appliance_mode_support must be 'enable' or 'disable'."
  }
}

# ---------------------------------------------------------------------------
# Routing
# ---------------------------------------------------------------------------

variable "inter_vpc_cidrs" {
  description = "CIDR blocks to route from private subnets via the TGW (e.g. '10.0.0.0/8'). Leave empty to skip TGW routes."
  type        = list(string)
  default     = ["10.0.0.0/8"]

  validation {
    condition     = alltrue([for c in var.inter_vpc_cidrs : can(cidrnetmask(c))])
    error_message = "Each inter_vpc_cidr must be a valid CIDR block."
  }
}

# ---------------------------------------------------------------------------
# Flow Logs
# ---------------------------------------------------------------------------

variable "enable_flow_logs" {
  description = "Enable VPC Flow Logs delivered to CloudWatch Logs."
  type        = bool
  default     = true
}

variable "flow_logs_retention_days" {
  description = "Number of days to retain VPC Flow Log data in CloudWatch Logs."
  type        = number
  default     = 30

  validation {
    condition     = contains([0, 1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653], var.flow_logs_retention_days)
    error_message = "flow_logs_retention_days must be a valid CloudWatch Logs retention period."
  }
}

# ---------------------------------------------------------------------------
# Tagging
# ---------------------------------------------------------------------------

variable "tags" {
  description = "Tags merged onto every resource created by this module."
  type        = map(string)
  default     = {}
}
