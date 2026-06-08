# -----------------------------------------------------------------------------
# AWS Network Firewall — logging.tf
#
# Creates the log destinations for the firewall:
#   - CloudWatch Log Groups  — real-time FLOW and ALERT log streams (7-day hot)
#   - S3 bucket              — long-term ALERT log archival (90-day, lifecycle)
#
# The actual aws_networkfirewall_logging_configuration resource lives in main.tf
# so that it can reference both the firewall ARN and the log destinations in a
# single resource block.
# -----------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# KMS key for log encryption
# ---------------------------------------------------------------------------

resource "aws_kms_key" "logs" {
  description             = "KMS key for Network Firewall log encryption (${var.name_prefix})"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EnableRootAccount"
        Effect = "Allow"
        Principal = {
          AWS = "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "AllowCloudWatchLogs"
        Effect = "Allow"
        Principal = {
          Service = "logs.${data.aws_region.current.name}.amazonaws.com"
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:Describe*",
        ]
        Resource = "*"
        Condition = {
          ArnLike = {
            "kms:EncryptionContext:aws:logs:arn" = "arn:${data.aws_partition.current.partition}:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:*"
          }
        }
      },
      {
        Sid    = "AllowS3"
        Effect = "Allow"
        Principal = {
          Service = "s3.amazonaws.com"
        }
        Action = [
          "kms:GenerateDataKey",
          "kms:Decrypt",
        ]
        Resource = "*"
      },
    ]
  })

  tags = merge(var.tags, {
    Name    = "${var.name_prefix}-nfw-logs-key"
    Module  = "network-firewall"
    ManagedBy = "terraform"
  })
}

resource "aws_kms_alias" "logs" {
  name          = "alias/${var.name_prefix}-nfw-logs"
  target_key_id = aws_kms_key.logs.key_id
}

# ---------------------------------------------------------------------------
# CloudWatch Log Groups
# ---------------------------------------------------------------------------

resource "aws_cloudwatch_log_group" "flow" {
  name              = "/aws/network-firewall/${var.name_prefix}/flow"
  retention_in_days = var.cloudwatch_retention_days
  kms_key_id        = aws_kms_key.logs.arn

  tags = merge(var.tags, {
    Name    = "${var.name_prefix}-nfw-flow-logs"
    LogType = "flow"
    Module  = "network-firewall"
    ManagedBy = "terraform"
  })
}

resource "aws_cloudwatch_log_group" "alert" {
  name              = "/aws/network-firewall/${var.name_prefix}/alert"
  retention_in_days = var.cloudwatch_retention_days
  kms_key_id        = aws_kms_key.logs.arn

  tags = merge(var.tags, {
    Name    = "${var.name_prefix}-nfw-alert-logs"
    LogType = "alert"
    Module  = "network-firewall"
    ManagedBy = "terraform"
  })
}

# CloudWatch Metric Alarm — fires when blocked connections spike (ops visibility)
resource "aws_cloudwatch_metric_alarm" "blocked_connections" {
  alarm_name          = "${var.name_prefix}-nfw-blocked-connections"
  alarm_description   = "Network Firewall dropped more than ${var.blocked_connection_threshold} connections in 5 minutes"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "DroppedPackets"
  namespace           = "AWS/NetworkFirewall"
  period              = 300
  statistic           = "Sum"
  threshold           = var.blocked_connection_threshold
  treat_missing_data  = "notBreaching"

  dimensions = {
    FirewallName = aws_networkfirewall_firewall.this.name
    AvailabilityZone = "*"
  }

  alarm_actions = var.alarm_sns_topic_arns

  tags = merge(var.tags, {
    Module    = "network-firewall"
    ManagedBy = "terraform"
  })
}

# ---------------------------------------------------------------------------
# S3 Bucket — long-term log archive
# ---------------------------------------------------------------------------

resource "aws_s3_bucket" "logs" {
  # tfsec:ignore:AVD-AWS-0089 — access logging enabled below via separate resource
  bucket        = "${var.name_prefix}-nfw-logs-${data.aws_caller_identity.current.account_id}"
  force_destroy = false

  tags = merge(var.tags, {
    Name    = "${var.name_prefix}-nfw-logs"
    Module  = "network-firewall"
    ManagedBy = "terraform"
  })
}

resource "aws_s3_bucket_versioning" "logs" {
  bucket = aws_s3_bucket.logs.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.logs.arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "logs" {
  bucket                  = aws_s3_bucket.logs.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id

  rule {
    id     = "archive-and-expire"
    status = "Enabled"

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = 60
      storage_class = "GLACIER"
    }

    expiration {
      days = var.s3_log_retention_days
    }

    noncurrent_version_expiration {
      noncurrent_days = 7
    }
  }
}

# S3 bucket policy — allow Network Firewall service to write logs
data "aws_iam_policy_document" "logs_bucket" {
  statement {
    sid    = "AllowNetworkFirewallLogs"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["delivery.logs.amazonaws.com"]
    }

    actions = [
      "s3:PutObject",
    ]

    resources = [
      "${aws_s3_bucket.logs.arn}/network-firewall/*",
    ]

    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }

  statement {
    sid    = "AllowAclCheck"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["delivery.logs.amazonaws.com"]
    }

    actions = [
      "s3:GetBucketAcl",
    ]

    resources = [aws_s3_bucket.logs.arn]

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }

  statement {
    sid    = "DenyNonTLSRequests"
    effect = "Deny"

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    actions = ["s3:*"]

    resources = [
      aws_s3_bucket.logs.arn,
      "${aws_s3_bucket.logs.arn}/*",
    ]

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "logs" {
  bucket = aws_s3_bucket.logs.id
  policy = data.aws_iam_policy_document.logs_bucket.json

  depends_on = [aws_s3_bucket_public_access_block.logs]
}
