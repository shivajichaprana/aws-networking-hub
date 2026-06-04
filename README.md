# aws-networking-hub

Transit Gateway hub-and-spoke networking with PrivateLink, hybrid DNS, and egress firewall.

## Architecture

```
                          ┌──────────────────────────────────────────────┐
                          │            Transit Gateway (hub)             │
                          │                                              │
                          │  ┌──────────────┐  ┌──────────────────────┐ │
                          │  │  Prod Route  │  │  Non-Prod Route      │ │
                          │  │    Table     │  │    Table             │ │
                          │  └──────────────┘  └──────────────────────┘ │
                          └──────────┬───────────────────────┬───────────┘
                                     │                       │
                          ┌──────────┘                       └──────────────┐
                          │                                                 │
              ┌───────────▼──────────┐                         ┌───────────▼──────────┐
              │   Production VPC     │                         │   Non-Prod VPC       │
              │   (spoke)            │                         │   (spoke)            │
              │                      │                         │                      │
              │  ┌────────────────┐  │                         │  ┌────────────────┐  │
              │  │  Private Subnets│ │                         │  │  Private Subnets│ │
              │  │  + TGW Subnet  │  │                         │  │  + TGW Subnet  │  │
              │  └────────────────┘  │                         │  └────────────────┘  │
              └──────────────────────┘                         └──────────────────────┘

              ┌──────────────────────────────────────────────────────────────────────┐
              │  AWS PrivateLink Endpoints (S3, ECR, SSM, Secrets Manager, KMS...)   │
              └──────────────────────────────────────────────────────────────────────┘

              ┌──────────────────────────────────────────────────────────────────────┐
              │  Network Firewall  (TLS SNI allow-list + malicious domain block)     │
              └──────────────────────────────────────────────────────────────────────┘

              ┌──────────────────────────────────────────────────────────────────────┐
              │  Route 53 Resolver  (inbound/outbound endpoints + corp.internal DNS) │
              └──────────────────────────────────────────────────────────────────────┘
```

## Modules

| Module | Purpose |
|--------|---------|
| `tgw` | Transit Gateway with prod/non-prod route table isolation |
| `vpc-spoke` | Spoke VPC with TGW attachment and routing |
| `privatelink` | VPC Interface + Gateway endpoints for AWS services |
| `dns-hybrid` | Route 53 Resolver for hybrid DNS with on-prem |
| `network-firewall` | AWS Network Firewall for egress filtering |

## Quick Start

```hcl
module "tgw" {
  source = "./terraform/modules/tgw"

  name            = "hub"
  amazon_side_asn = 64512
  environment_tags = {
    prod    = ["vpc-xxxxxxxxxxxxxxxxx"]
    nonprod = ["vpc-yyyyyyyyyyyyyyyyy"]
  }
}
```

## Prerequisites

- Terraform >= 1.5
- AWS provider >= 5.0
- Spoke VPCs already provisioned (or use the `vpc-spoke` module)

## Repository Layout

```
terraform/
  modules/
    tgw/                 # Transit Gateway hub
    vpc-spoke/           # Spoke VPC template
    privatelink/         # VPC endpoints
    dns-hybrid/          # Route 53 Resolver
    network-firewall/    # Egress filtering
examples/
  onboard-spoke/         # How to attach a new spoke
docs/                    # Architecture notes
.github/workflows/       # CI pipelines
```

## Contributing

Open a Discussion or comment on a PR — contributions welcome.

## License

MIT — see [LICENSE](LICENSE).
