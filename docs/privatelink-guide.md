# PrivateLink & VPC Endpoints Guide

## Overview

VPC endpoints let resources in private subnets reach AWS services **without
leaving the Amazon network** — no NAT Gateway, no Internet Gateway, no public
IP address required. This module provisions two types:

| Type | Services | Cost |
|------|----------|------|
| **Gateway** | S3, DynamoDB | Free |
| **Interface** (PrivateLink) | ECR, STS, KMS, Secrets Manager, SSM, CloudWatch … | ~$7.30/endpoint-AZ/month + $0.01/GB |

---

## Cost Analysis: Interface Endpoints vs NAT Gateway

### NAT Gateway pricing (us-east-1, 2024)

| Item | Price |
|------|-------|
| Hourly charge (per NAT GW) | $0.045/hr → **~$32.40/month** |
| Data processed | $0.045/GB |

A highly-available setup with one NAT Gateway per AZ (3 AZs) costs
**~$97/month in fixed charges alone**, before data.

### Interface endpoint pricing (us-east-1, 2024)

| Item | Price |
|------|-------|
| Hourly charge (per endpoint-AZ) | $0.01/hr → **~$7.30/month** |
| Data processed | $0.01/GB |

Deploying this module with all defaults enabled (9 interface endpoints × 3 AZs)
costs roughly **$197/month in endpoint charges** — but those endpoints replace
NAT for all AWS-service traffic. If AWS-service calls represent ≥ 25 % of your
NAT egress, endpoints pay for themselves.

### When to use endpoints vs NAT

```
Use Gateway endpoints (S3 + DynamoDB):  ALWAYS — they are free.

Use Interface endpoints when:
  ✓ You have strict data-residency or compliance requirements
  ✓ Traffic to a given service is high (> ~1 TB/month of NAT processing)
  ✓ You want to eliminate public-internet routing for API calls
  ✓ Operating in an air-gapped / no-internet VPC

Keep NAT Gateway for:
  ✓ Access to third-party SaaS / arbitrary internet endpoints
  ✓ Outbound internet calls (package downloads, webhook deliveries, etc.)
```

### Recommended baseline (minimal cost)

Enable gateway endpoints (S3 + DynamoDB) plus the services most traffic
touches: `ecr_api`, `ecr_dkr`, `sts`, `secretsmanager`, `ssm`, `ssmmessages`,
`ec2messages`, `logs`. Disable `monitoring` and `s3_interface` unless you have
specific needs for them.

---

## Prerequisites

The VPC must have these settings enabled (both are true by default in
`aws_vpc`, but explicit is safer):

```hcl
resource "aws_vpc" "main" {
  enable_dns_hostnames = true  # required for private DNS resolution
  enable_dns_support   = true  # required for private DNS resolution
  ...
}
```

---

## Module Usage

```hcl
module "privatelink" {
  source = "../../modules/privatelink"

  vpc_id                  = module.vpc_spoke.vpc_id
  region                  = var.region
  private_subnet_ids      = module.vpc_spoke.private_subnet_ids
  private_route_table_ids = module.vpc_spoke.private_route_table_ids

  allowed_cidr_blocks = ["10.0.0.0/8"]

  # Gateway endpoints — always keep enabled (free)
  enable_s3_gateway       = true
  enable_dynamodb_gateway = true

  # Interface endpoints — enable based on workload
  enable_ecr_api        = true
  enable_ecr_dkr        = true
  enable_sts            = true
  enable_kms            = true
  enable_secretsmanager = true
  enable_ssm            = true
  enable_ssmmessages    = true
  enable_ec2messages    = true
  enable_logs           = true
  enable_monitoring     = false  # enable if workload sends custom CloudWatch metrics
  enable_s3_interface   = false  # enable for S3 Object Lambda or PrivateLink-only access

  tags = {
    Environment = "production"
    ManagedBy   = "terraform"
  }
}
```

---

## How Private DNS Works

When `private_dns_enabled = true` (the default for all interface endpoints),
Route 53 Resolver returns the **private IP of the endpoint ENI** for the
standard service hostname (e.g., `ecr.api.us-east-1.amazonaws.com`). No code
changes are required in your application — it resolves the same hostname but
the traffic stays inside the VPC.

```
Application → resolve ecr.api.us-east-1.amazonaws.com
            ← R53 returns 10.x.x.x  (endpoint ENI IP, not public IP)
Application → HTTPS to 10.x.x.x  (never leaves VPC)
```

---

## Troubleshooting

### Endpoint not reachable from private subnet

1. Confirm `enableDnsHostnames` and `enableDnsSupport` are `true` on the VPC.
2. Check the endpoint security group allows TCP/443 from the caller's subnet CIDR.
3. Verify the subnet ID is listed in `private_subnet_ids`.
4. Run `aws ec2 describe-vpc-endpoints --filter Name=vpc-id,Values=<vpc-id>` and check `State = available`.

### `unable to resolve host` inside container

ECR image pulls require **both** `ecr.api` and `ecr.dkr` endpoints. Enabling
only one will fail — `ecr.api` handles `GetAuthorizationToken` and
`BatchGetImage`, while `ecr.dkr` handles the actual Docker pull.

### S3 access still going via NAT

Gateway endpoints route traffic for S3 **prefix lists** in the route table.
Confirm the route `pl-xxxxxxxx → vpce-xxxxxxxx` appears in the private route
table. If you also enabled `enable_s3_interface`, S3 hostnames resolve to the
interface endpoint IP instead — mixing both types for S3 is uncommon but
supported.

---

## Security Considerations

- **Endpoint policies**: the default policies in this module allow all actions.
  Tighten them in production to specific IAM principals and S3 bucket ARNs.
- **Security group**: the `vpc-endpoints-sg` security group restricts endpoint
  ENI access to `allowed_cidr_blocks`. For a shared-services hub, set this to
  the TGW attached spoke CIDRs.
- **Cross-account access**: endpoints are VPC-scoped. For cross-account shared
  services, consider a centralised PrivateLink endpoint service
  (`aws_vpc_endpoint_service`) published from a shared-services VPC.

---

## References

- [AWS VPC Endpoints documentation](https://docs.aws.amazon.com/vpc/latest/privatelink/vpc-endpoints.html)
- [AWS PrivateLink pricing](https://aws.amazon.com/privatelink/pricing/)
- [Gateway vs Interface endpoints comparison](https://docs.aws.amazon.com/vpc/latest/privatelink/vpce-gateway.html)
