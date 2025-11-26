variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "db_master_password" {
  description = "Master password for RDS database"
  type        = string
  sensitive   = true
}

variable "root_domain_name" {
  description = "Root domain name for Route 53 hosted zone (e.g., yourdomain.com). If provided, creates a hosted zone."
  type        = string
  default     = ""
}

variable "domain_name" {
  description = "Custom domain name for ALB (e.g., api.yourdomain.com). Leave empty to use ALB DNS name."
  type        = string
  default     = ""
}

variable "hosted_zone_id" {
  description = "Route 53 hosted zone ID for the domain. If not provided and root_domain_name is set, uses the created hosted zone."
  type        = string
  default     = ""
}

variable "existing_certificate_arn" {
  description = "ARN of existing ACM certificate (e.g., self-signed). If provided, skips certificate creation."
  type        = string
  default     = ""
}

variable "enable_https" {
  description = "Enable HTTPS listener with existing certificate"
  type        = bool
  default     = false
}
