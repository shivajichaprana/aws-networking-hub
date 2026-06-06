# ──────────────────────────────────────────────────────────────────────────────
# Module: privatelink
#
# Provisions VPC endpoints (Gateway and Interface) so that workloads in private
# subnets can reach core AWS services without traversing a NAT Gateway.
#
# Gateway endpoints (free):
#   S3, DynamoDB
#
# Interface endpoints (PrivateLink, ~$7.30/endpoint-AZ/month):
#   ECR API, ECR DKR, STS, KMS, Secrets Manager, SSM, SSM Messages,
#   EC2 Messages, CloudWatch Logs, CloudWatch Monitoring (optional),
#   S3 Interface (optional, for Object Lambda / PrivateLink-only patterns)
#
# Prerequisites:
#   - VPC must have enableDnsHostnames = true and enableDnsSupport = true
#   - Private subnets must be provided for interface-endpoint ENI placement
#   - Private route tables must be provided for gateway-endpoint routes
# ──────────────────────────────────────────────────────────────────────────────

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

# ── Locals ────────────────────────────────────────────────────────────────────
locals {
  account_id = data.aws_caller_identity.current.account_id
  partition  = data.aws_partition.current.partition
}
