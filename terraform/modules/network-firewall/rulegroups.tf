# -----------------------------------------------------------------------------
# AWS Network Firewall — rulegroups.tf
#
# Two stateful rule groups:
#   1. domain_blocklist  — blocks known-bad domains (Suricata domain-keyword rules)
#   2. tls_sni_allowlist — permits only explicitly approved TLS destinations; all
#                          other HTTPS egress is dropped (zero-trust egress model)
#
# Rule ordering: domain_blocklist runs first (lower priority value = evaluated first
# in STRICT_ORDER mode). This ensures malicious domains are blocked before the
# allow-list is consulted.
# -----------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# Rule Group 1 — Malicious Domain Block-list
# ---------------------------------------------------------------------------

resource "aws_networkfirewall_rule_group" "domain_blocklist" {
  name     = "${var.name_prefix}-domain-blocklist"
  type     = "STATEFUL"
  capacity = 1000 # Maximum number of rule entries; can be raised but not lowered

  rule_group {
    rules_source {
      # Suricata-compatible rules — drop traffic to known-malicious domains.
      # In production, populate this from a threat-intel feed or AWS-managed list.
      # Using a representative sample set here; expand as required.
      rules_string = <<-SURICATA
        # Cryptocurrency mining pools (common in compromised environments)
        drop dns $HOME_NET any -> any 53 (msg:"ET DROP Crypto mining domain xmrpool.eu"; dns.query; content:"xmrpool.eu"; nocase; endswith; sid:9000001; rev:1;)
        drop dns $HOME_NET any -> any 53 (msg:"ET DROP Crypto mining domain pool.minexmr.com"; dns.query; content:"pool.minexmr.com"; nocase; endswith; sid:9000002; rev:1;)
        drop dns $HOME_NET any -> any 53 (msg:"ET DROP Crypto mining domain moneropool.com"; dns.query; content:"moneropool.com"; nocase; endswith; sid:9000003; rev:1;)

        # Known C2 / malware distribution infrastructure (illustrative)
        drop dns $HOME_NET any -> any 53 (msg:"ET DROP Known-bad C2 domain example-c2.evil"; dns.query; content:"example-c2.evil"; nocase; endswith; sid:9000100; rev:1;)
        drop dns $HOME_NET any -> any 53 (msg:"ET DROP Known-bad domain malware-drop.example"; dns.query; content:"malware-drop.example"; nocase; endswith; sid:9000101; rev:1;)

        # Data exfiltration via DNS tunnelling patterns
        drop dns $HOME_NET any -> any 53 (msg:"ET DROP DNS tunnel tool iodine"; dns.query; content:".iodine."; nocase; sid:9000200; rev:1;)
        drop dns $HOME_NET any -> any 53 (msg:"ET DROP DNS tunnel tool dnscat"; dns.query; content:".dnscat."; nocase; sid:9000201; rev:1;)

        # Direct-IP HTTP/HTTPS (no hostname resolution — suspicious egress)
        drop http $HOME_NET any -> $EXTERNAL_NET 80 (msg:"ET DROP Direct-IP HTTP egress (no Host header)"; http.request; content:"Host|3a 20|"; nocase; pcre:"/Host:\s+\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}/i"; sid:9000300; rev:1;)
      SURICATA
    }

    stateful_rule_options {
      rule_order = "STRICT_ORDER"
    }
  }

  tags = merge(var.tags, {
    Name      = "${var.name_prefix}-domain-blocklist"
    RuleType  = "blocklist"
    Module    = "network-firewall"
    ManagedBy = "terraform"
  })
}

# ---------------------------------------------------------------------------
# Rule Group 2 — TLS SNI Allow-list
# ---------------------------------------------------------------------------

resource "aws_networkfirewall_rule_group" "tls_sni_allowlist" {
  name     = "${var.name_prefix}-tls-sni-allowlist"
  type     = "STATEFUL"
  capacity = 2000

  rule_group {
    rules_source {
      rules_source_list {
        # Traffic direction: ALLOWLIST means only listed domains are permitted
        generated_rules_type = "ALLOWLIST"

        # Protocols to apply the allow-list to (TLS inspection via SNI)
        target_types = ["TLS_SNI", "HTTP_HOST"]

        # ---------------------------------------------------------------------------
        # Approved egress destinations
        # Add any domain the workloads legitimately need to reach.
        # Wildcards (*) match any subdomain prefix.
        # ---------------------------------------------------------------------------
        targets = concat(
          # AWS service endpoints (prefer VPC endpoints where possible)
          [
            ".amazonaws.com",
            ".aws.amazon.com",
            ".cloudfront.net",
          ],
          # Package registries
          [
            "pypi.org",
            ".pypi.org",
            "files.pythonhosted.org",
            "registry.npmjs.org",
            ".npmjs.org",
            "registry-1.docker.io",
            "auth.docker.io",
            "index.docker.io",
            "production.cloudflare.docker.com",
            ".ecr.aws",
          ],
          # Source control / CI tooling
          [
            "github.com",
            ".github.com",
            "api.github.com",
            "objects.githubusercontent.com",
            ".githubusercontent.com",
            "codeload.github.com",
          ],
          # OS package mirrors
          [
            "packages.debian.org",
            ".debian.org",
            ".ubuntu.com",
            "dl-ssl.google.com",
            "dl.google.com",
            ".centos.org",
            ".redhat.com",
            ".fedoraproject.org",
            ".almalinux.org",
          ],
          # Monitoring / observability SaaS (optional — remove if not used)
          [
            ".datadoghq.com",
            ".datadog.com",
            "intake.opsgenie.com",
            ".pagerduty.com",
            ".newrelic.com",
            ".splunkcloud.com",
          ],
          # Customer-defined additional destinations
          var.additional_allowed_domains,
        )
      }
    }

    stateful_rule_options {
      rule_order = "STRICT_ORDER"
    }
  }

  tags = merge(var.tags, {
    Name      = "${var.name_prefix}-tls-sni-allowlist"
    RuleType  = "allowlist"
    Module    = "network-firewall"
    ManagedBy = "terraform"
  })
}
