output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = module.ecs.alb_dns_name
}

output "db_endpoint" {
  description = "RDS database endpoint"
  value       = module.rds.db_instance_endpoint
  sensitive   = true
}

output "images_bucket_name" {
  description = "Name of the images S3 bucket"
  value       = module.s3.images_bucket_name
}

output "cloudfront_domain_name" {
  description = "CloudFront distribution domain name"
  value       = module.s3.cloudfront_domain_name
}

output "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  value       = module.ecs.cluster_name
}

output "acm_certificate_arn" {
  description = "ARN of the ACM certificate for ALB"
  value       = module.ecs.acm_certificate_arn
}

output "acm_certificate_status" {
  description = "Status of the ACM certificate"
  value       = module.ecs.acm_certificate_status
}

output "api_endpoint" {
  description = "API endpoint URL (custom domain if configured, otherwise ALB DNS)"
  value       = var.domain_name != "" ? "https://${var.domain_name}" : "http://${module.ecs.alb_dns_name}"
}

output "custom_domain" {
  description = "Custom domain name (if configured)"
  value       = var.domain_name != "" ? var.domain_name : "Not configured"
}

output "hosted_zone_id" {
  description = "Route 53 hosted zone ID"
  value       = module.ecs.hosted_zone_id
}

output "hosted_zone_name_servers" {
  description = "Name servers for the hosted zone (for GoDaddy configuration)"
  value       = module.ecs.hosted_zone_name_servers
}

output "root_domain_name" {
  description = "Root domain name"
  value       = module.ecs.root_domain_name
}
