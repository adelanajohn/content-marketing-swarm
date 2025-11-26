variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment (dev, prod)"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "log_retention_days" {
  description = "Number of days to retain logs"
  type        = number
  default     = 30
}

variable "alert_email_addresses" {
  description = "List of email addresses for alerts"
  type        = list(string)
  default     = []
}

variable "ecs_cluster_name" {
  description = "Name of ECS cluster"
  type        = string
}

variable "ecs_service_name" {
  description = "Name of ECS service"
  type        = string
}

variable "alb_arn_suffix" {
  description = "ARN suffix of Application Load Balancer"
  type        = string
}

variable "target_group_arn_suffix" {
  description = "ARN suffix of target group"
  type        = string
}

variable "rds_instance_id" {
  description = "ID of RDS instance"
  type        = string
}

variable "agent_execution_time_threshold_ms" {
  description = "Threshold for agent execution time in milliseconds"
  type        = number
  default     = 10000
}
