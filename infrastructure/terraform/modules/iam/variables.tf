variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment (dev, prod)"
  type        = string
}

variable "images_bucket_arn" {
  description = "ARN of S3 bucket for images"
  type        = string
}

variable "knowledge_base_arn" {
  description = "ARN of Bedrock Knowledge Base"
  type        = string
  default     = null
}
