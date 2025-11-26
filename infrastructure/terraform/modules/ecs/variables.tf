variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment (dev, prod)"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "public_subnet_ids" {
  description = "List of public subnet IDs"
  type        = list(string)
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs"
  type        = list(string)
}

variable "container_port" {
  description = "Port exposed by the container"
  type        = number
  default     = 8000
}

variable "health_check_path" {
  description = "Health check path"
  type        = string
  default     = "/health"
}

variable "enable_deletion_protection" {
  description = "Enable deletion protection for ALB"
  type        = bool
  default     = false
}

variable "s3_bucket_arn" {
  description = "ARN of S3 bucket for generated images"
  type        = string
}

variable "task_cpu" {
  description = "CPU units for the task (256, 512, 1024, 2048, 4096)"
  type        = number
  default     = 1024
}

variable "task_memory" {
  description = "Memory for the task in MB"
  type        = number
  default     = 2048
}

variable "backend_image" {
  description = "Docker image for backend"
  type        = string
}

variable "database_host" {
  description = "Database host"
  type        = string
}

variable "database_port" {
  description = "Database port"
  type        = number
  default     = 5432
}

variable "database_name" {
  description = "Database name"
  type        = string
}

variable "database_password_secret_arn" {
  description = "ARN of secret containing database password"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "desired_count" {
  description = "Desired number of tasks"
  type        = number
  default     = 2
}

variable "min_capacity" {
  description = "Minimum number of tasks"
  type        = number
  default     = 2
}

variable "max_capacity" {
  description = "Maximum number of tasks"
  type        = number
  default     = 10
}

variable "cpu_target_value" {
  description = "Target CPU utilization percentage for auto-scaling"
  type        = number
  default     = 70
}

variable "memory_target_value" {
  description = "Target memory utilization percentage for auto-scaling"
  type        = number
  default     = 80
}

variable "request_count_target_value" {
  description = "Target request count per target for auto-scaling"
  type        = number
  default     = 1000
}

variable "enable_ecs_exec" {
  description = "Enable ECS Exec for debugging"
  type        = bool
  default     = false
}

variable "root_domain_name" {
  description = "Root domain name for Route 53 hosted zone (e.g., yourdomain.com). If provided, creates a hosted zone."
  type        = string
  default     = ""
}

variable "domain_name" {
  description = "Custom domain name for ALB (e.g., api.yourdomain.com). If not provided, uses ALB DNS name."
  type        = string
  default     = ""
}

variable "hosted_zone_id" {
  description = "Route 53 hosted zone ID for the domain. If not provided and root_domain_name is set, uses the created hosted zone."
  type        = string
  default     = ""
}

variable "existing_certificate_arn" {
  description = "ARN of existing ACM certificate to use. If provided, skips certificate creation."
  type        = string
  default     = ""
}

variable "enable_https" {
  description = "Enable HTTPS listener. Requires either domain_name or existing_certificate_arn."
  type        = bool
  default     = false
}


variable "database_username" {
  description = "Database username"
  type        = string
  default     = "postgres"
}

variable "s3_bucket_name" {
  description = "S3 bucket name for images"
  type        = string
}
