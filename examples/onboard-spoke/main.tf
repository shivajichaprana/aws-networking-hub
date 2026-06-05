# ---------------------------------------------------------------------------
# Example: Onboard a New Spoke VPC
#
# This example shows the minimal configuration to attach a new spoke VPC to
# an existing aws-networking-hub Transit Gateway. Copy and customise this
# block for each new workload VPC that needs hub connectivity.
#
# Prerequisites:
#   - The aws-networking-hub TGW module has already been deployed.
#   - You have the TGW ID and the appropriate TGW route table ID
#     (prod or nonprod) from the hub Terraform outputs.
# ---------------------------------------------------------------------------

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Replace with your remote state backend configuration.
  backend "s3" {
    bucket         = "<your-tfstate-bucket-name>"
    key            = "networking/spokes/example-workload/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "<your-tfstate-lock-table>"
    encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "aws-networking-hub"
      ManagedBy   = "terraform"
      Environment = var.environment
    }
  }
}

# ---------------------------------------------------------------------------
# Read TGW outputs from the hub's remote state
#
# Swap this data source for hard-coded IDs if you prefer an explicit,
# decoupled approach (avoids remote-state coupling at the cost of manual IDs).
# ---------------------------------------------------------------------------

data "terraform_remote_state" "hub" {
  backend = "s3"

  config = {
    bucket = "<your-tfstate-bucket-name>"
    key    = "networking/hub/terraform.tfstate"
    region = "us-east-1"
  }
}

locals {
  # Resolve the correct TGW route table based on environment tier.
  # prod environments associate with the prod table; everything else with nonprod.
  tgw_route_table_id = var.environment == "prod" ? (
    data.terraform_remote_state.hub.outputs.prod_route_table_id
  ) : (
    data.terraform_remote_state.hub.outputs.nonprod_route_table_id
  )
}

# ---------------------------------------------------------------------------
# Spoke VPC Module
#
# One module block is all you need to provision a fully-connected spoke.
# ---------------------------------------------------------------------------

module "spoke" {
  source = "../../terraform/modules/vpc-spoke"

  # ── Identity ──────────────────────────────────────────────────────────────
  name = "${var.environment}-${var.workload_name}"

  # ── Networking ────────────────────────────────────────────────────────────
  vpc_cidr           = var.vpc_cidr
  availability_zones = var.availability_zones

  # Public subnets + NAT Gateways are only needed for internet-facing workloads.
  # Set both to false for fully-private (intranet-only) spokes.
  public_subnets_enabled = var.public_subnets_enabled
  public_subnet_cidrs    = var.public_subnet_cidrs
  nat_gateway_enabled    = var.nat_gateway_enabled

  # Private workload subnets.
  private_subnet_cidrs = var.private_subnet_cidrs

  # Dedicated /28 subnets that TGW attachment ENIs will be placed into.
  tgw_subnet_cidrs = var.tgw_subnet_cidrs

  # ── Transit Gateway ───────────────────────────────────────────────────────
  # Attach to the existing hub TGW.
  transit_gateway_id = data.terraform_remote_state.hub.outputs.transit_gateway_id

  # Route table that determines which other spokes this VPC can reach.
  tgw_route_table_id = local.tgw_route_table_id

  # Propagate this VPC's CIDR into the shared-services route table so that
  # central services (DNS, monitoring) can reach all spokes.
  tgw_route_table_ids_to_propagate = [
    data.terraform_remote_state.hub.outputs.shared_route_table_id,
  ]

  # ── Routing ───────────────────────────────────────────────────────────────
  # Send RFC-1918 traffic from private subnets via the TGW.
  # Adjust if your organisation uses a narrower super-net.
  inter_vpc_cidrs = ["10.0.0.0/8"]

  # ── Observability ─────────────────────────────────────────────────────────
  enable_flow_logs         = true
  flow_logs_retention_days = 30

  # ── Tags ──────────────────────────────────────────────────────────────────
  tags = {
    Workload    = var.workload_name
    CostCenter  = var.cost_center
    Environment = var.environment
  }
}

# ---------------------------------------------------------------------------
# Outputs — expose key IDs for dependent stacks
# ---------------------------------------------------------------------------

output "vpc_id" {
  description = "ID of the newly provisioned spoke VPC."
  value       = module.spoke.vpc_id
}

output "vpc_cidr" {
  description = "CIDR block of the spoke VPC."
  value       = module.spoke.vpc_cidr
}

output "private_subnet_ids" {
  description = "IDs of the private workload subnets."
  value       = module.spoke.private_subnet_ids
}

output "tgw_attachment_id" {
  description = "TGW attachment ID — useful for adding static TGW routes from the hub."
  value       = module.spoke.tgw_attachment_id
}
