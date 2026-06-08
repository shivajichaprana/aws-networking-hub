# -----------------------------------------------------------------------------
# AWS Network Firewall — outputs.tf
# -----------------------------------------------------------------------------

output "firewall_id" {
  description = "ID of the Network Firewall resource."
  value       = aws_networkfirewall_firewall.this.id
}

output "firewall_arn" {
  description = "ARN of the Network Firewall resource."
  value       = aws_networkfirewall_firewall.this.arn
}

output "firewall_status" {
  description = "Sync state of the Network Firewall endpoints (maps AZ to endpoint ID). Use this to configure route tables to steer traffic through the correct endpoint in each AZ."
  value       = aws_networkfirewall_firewall.this.firewall_status
}

output "firewall_endpoint_ids" {
  description = "Map of subnet_id → vpc_endpoint_id for the firewall endpoints. Route table entries should use these IDs as the next-hop."
  value = {
    for sync in aws_networkfirewall_firewall.this.firewall_status[0].sync_states :
    sync.availability_zone => sync.attachment[0].endpoint_id
  }
}

output "policy_arn" {
  description = "ARN of the firewall policy."
  value       = aws_networkfirewall_firewall_policy.this.arn
}

output "domain_blocklist_arn" {
  description = "ARN of the malicious-domain block-list rule group."
  value       = aws_networkfirewall_rule_group.domain_blocklist.arn
}

output "tls_sni_allowlist_arn" {
  description = "ARN of the TLS SNI allow-list rule group."
  value       = aws_networkfirewall_rule_group.tls_sni_allowlist.arn
}

output "flow_log_group_name" {
  description = "Name of the CloudWatch log group receiving FLOW logs."
  value       = aws_cloudwatch_log_group.flow.name
}

output "alert_log_group_name" {
  description = "Name of the CloudWatch log group receiving ALERT logs."
  value       = aws_cloudwatch_log_group.alert.name
}

output "log_bucket_name" {
  description = "Name of the S3 bucket used for long-term alert log archival."
  value       = aws_s3_bucket.logs.bucket
}

output "log_bucket_arn" {
  description = "ARN of the S3 bucket used for long-term alert log archival."
  value       = aws_s3_bucket.logs.arn
}

output "kms_key_arn" {
  description = "ARN of the KMS key used to encrypt all log data."
  value       = aws_kms_key.logs.arn
}
