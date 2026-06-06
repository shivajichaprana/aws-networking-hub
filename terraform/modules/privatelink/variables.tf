variable "vpc_id" {
  description = "ID of the VPC in which to create the endpoints."
  type        = string
}

variable "region" {
  description = "AWS region (used to construct service-name strings)."
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs used for interface-endpoint ENIs."
  type        = list(string)

  validation {
    condition     = length(var.private_subnet_ids) > 0
    error_message = "At least one private subnet ID must be supplied."
  }
}

variable "private_route_table_ids" {
  description = "Route table IDs associated with private subnets (used for gateway-endpoint routes)."
  type        = list(string)
}

variable "allowed_cidr_blocks" {
  description = "CIDR blocks allowed to communicate with interface endpoints."
  type        = list(string)
  default     = ["10.0.0.0/8"]
}

variable "tags" {
  description = "Tags to apply to all resources."
  type        = map(string)
  default     = {}
}

# ── Opt-in toggles ────────────────────────────────────────────────────────────
variable "enable_s3_gateway" {
  description = "Create an S3 gateway endpoint."
  type        = bool
  default     = true
}

variable "enable_dynamodb_gateway" {
  description = "Create a DynamoDB gateway endpoint."
  type        = bool
  default     = true
}

variable "enable_ecr_api" {
  description = "Create an interface endpoint for ECR API."
  type        = bool
  default     = true
}

variable "enable_ecr_dkr" {
  description = "Create an interface endpoint for ECR docker (image pull)."
  type        = bool
  default     = true
}

variable "enable_sts" {
  description = "Create an interface endpoint for STS."
  type        = bool
  default     = true
}

variable "enable_kms" {
  description = "Create an interface endpoint for KMS."
  type        = bool
  default     = true
}

variable "enable_secretsmanager" {
  description = "Create an interface endpoint for Secrets Manager."
  type        = bool
  default     = true
}

variable "enable_ssm" {
  description = "Create an interface endpoint for SSM."
  type        = bool
  default     = true
}

variable "enable_ssmmessages" {
  description = "Create an interface endpoint for SSM Session Manager messages."
  type        = bool
  default     = true
}

variable "enable_ec2messages" {
  description = "Create an interface endpoint for EC2 messages (SSM agent)."
  type        = bool
  default     = true
}

variable "enable_logs" {
  description = "Create an interface endpoint for CloudWatch Logs."
  type        = bool
  default     = true
}

variable "enable_monitoring" {
  description = "Create an interface endpoint for CloudWatch monitoring."
  type        = bool
  default     = false
}

variable "enable_s3_interface" {
  description = "Create an S3 interface endpoint (for S3 Object Lambda / PrivateLink-only access). Usually the gateway endpoint is sufficient."
  type        = bool
  default     = false
}
