# -----------------------------------------------------------------------------
# AWS Network Firewall — variables.tf
# -----------------------------------------------------------------------------

variable "name_prefix" {
  description = "Prefix applied to all resource names (e.g. 'hub-prod')."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.name_prefix))
    error_message = "name_prefix must contain only lowercase letters, digits, and hyphens."
  }
}

variable "inspection_vpc_id" {
  description = "ID of the VPC where the Network Firewall endpoints will be deployed."
  type        = string

  validation {
    condition     = can(regex("^vpc-[a-f0-9]{8,}$", var.inspection_vpc_id))
    error_message = "inspection_vpc_id must be a valid VPC ID (e.g. vpc-0abc12345678def90)."
  }
}

variable "firewall_subnet_ids" {
  description = "List of subnet IDs (one per AZ) for the firewall endpoints. Each subnet must be in the inspection VPC and should be dedicated to the firewall."
  type        = list(string)

  validation {
    condition     = length(var.firewall_subnet_ids) >= 1
    error_message = "At least one firewall subnet must be provided."
  }
}

variable "additional_allowed_domains" {
  description = "Extra domains to add to the TLS SNI allow-list beyond the built-in AWS/common defaults."
  type        = list(string)
  default     = []
}

variable "enable_change_protection" {
  description = "Enables firewall-policy-change and subnet-change protection. Set to true in production to prevent accidental deletions."
  type        = bool
  default     = true
}

variable "cloudwatch_retention_days" {
  description = "Retention period (days) for CloudWatch log groups (FLOW and ALERT)."
  type        = number
  default     = 7

  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653], var.cloudwatch_retention_days)
    error_message = "cloudwatch_retention_days must be a valid CloudWatch retention period."
  }
}

variable "s3_log_retention_days" {
  description = "Total retention period (days) for alert logs stored in S3 before expiry."
  type        = number
  default     = 90

  validation {
    condition     = var.s3_log_retention_days >= 30
    error_message = "s3_log_retention_days must be at least 30 days."
  }
}

variable "blocked_connection_threshold" {
  description = "Number of dropped packets in a 5-minute window that triggers the CloudWatch alarm."
  type        = number
  default     = 1000
}

variable "alarm_sns_topic_arns" {
  description = "List of SNS topic ARNs to notify when the blocked-connections alarm fires."
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Map of tags to apply to all resources in this module."
  type        = map(string)
  default     = {}
}
