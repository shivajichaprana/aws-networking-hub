# ---------------------------------------------------------------------------
# Example: Onboard a New Spoke VPC — variables.tf
# ---------------------------------------------------------------------------

variable "aws_region" {
  description = "AWS region to deploy the spoke VPC into."
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Deployment tier: 'prod' routes to the prod TGW route table; all other values use nonprod."
  type        = string

  validation {
    condition     = contains(["prod", "staging", "dev", "sandbox"], var.environment)
    error_message = "environment must be one of: prod, staging, dev, sandbox."
  }
}

variable "workload_name" {
  description = "Short identifier for the workload (e.g. 'payments', 'data-platform'). Combined with environment to form the spoke name."
  type        = string
}

variable "vpc_cidr" {
  description = "Primary CIDR block for the spoke VPC. Must not overlap with other spokes or the hub."
  type        = string
  default     = "10.1.0.0/16"

  validation {
    condition     = can(cidrnetmask(var.vpc_cidr))
    error_message = "vpc_cidr must be a valid CIDR block."
  }
}

variable "availability_zones" {
  description = "Availability Zones to deploy subnets into."
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

variable "public_subnets_enabled" {
  description = "Create public subnets. Disable for fully-private spokes."
  type        = bool
  default     = true
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets — one per AZ."
  type        = list(string)
  default     = ["10.1.0.0/24", "10.1.1.0/24", "10.1.2.0/24"]
}

variable "nat_gateway_enabled" {
  description = "Deploy NAT Gateways for private subnet internet egress."
  type        = bool
  default     = true
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private (workload) subnets — one per AZ."
  type        = list(string)
  default     = ["10.1.10.0/24", "10.1.11.0/24", "10.1.12.0/24"]
}

variable "tgw_subnet_cidrs" {
  description = "CIDR blocks for TGW attachment subnets — one /28 per AZ."
  type        = list(string)
  default     = ["10.1.20.0/28", "10.1.20.16/28", "10.1.20.32/28"]
}

variable "cost_center" {
  description = "Cost center tag value for billing allocation."
  type        = string
  default     = "platform-engineering"
}
