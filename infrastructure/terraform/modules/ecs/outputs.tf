output "cluster_id" {
  description = "ID of the ECS cluster"
  value       = aws_ecs_cluster.main.id
}

output "cluster_name" {
  description = "Name of the ECS cluster"
  value       = aws_ecs_cluster.main.name
}

output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = aws_lb.main.dns_name
}

output "alb_arn" {
  description = "ARN of the Application Load Balancer"
  value       = aws_lb.main.arn
}

output "target_group_arn" {
  description = "ARN of the target group"
  value       = aws_lb_target_group.main.arn
}

output "ecs_task_execution_role_arn" {
  description = "ARN of ECS task execution role"
  value       = aws_iam_role.ecs_task_execution.arn
}

output "ecs_task_role_arn" {
  description = "ARN of ECS task role"
  value       = aws_iam_role.ecs_task.arn
}

output "ecs_security_group_id" {
  description = "Security group ID for ECS tasks"
  value       = aws_security_group.ecs_tasks.id
}

output "log_group_name" {
  description = "Name of CloudWatch log group"
  value       = aws_cloudwatch_log_group.ecs.name
}

output "service_name" {
  description = "Name of the ECS service"
  value       = aws_ecs_service.backend.name
}

output "service_id" {
  description = "ID of the ECS service"
  value       = aws_ecs_service.backend.id
}

output "task_definition_arn" {
  description = "ARN of the task definition"
  value       = aws_ecs_task_definition.backend.arn
}

output "autoscaling_target_id" {
  description = "ID of the autoscaling target"
  value       = aws_appautoscaling_target.ecs.id
}

output "acm_certificate_arn" {
  description = "ARN of the ACM certificate for ALB"
  value       = local.certificate_arn != "" ? local.certificate_arn : "Not configured"
}

output "acm_certificate_status" {
  description = "Status of the ACM certificate"
  value       = var.domain_name != "" && var.existing_certificate_arn == "" ? aws_acm_certificate.alb_cert[0].status : (var.existing_certificate_arn != "" ? "Imported (self-signed)" : "Not configured")
}

output "https_listener_arn" {
  description = "ARN of the HTTPS listener"
  value       = local.https_enabled ? aws_lb_listener.https[0].arn : "Not configured"
}

output "https_enabled" {
  description = "Whether HTTPS is enabled"
  value       = local.https_enabled
}

output "http_listener_arn" {
  description = "ARN of the HTTP listener"
  value       = aws_lb_listener.http.arn
}

output "custom_domain" {
  description = "Custom domain name (if configured)"
  value       = var.domain_name != "" ? var.domain_name : "Not configured"
}

output "route53_record_name" {
  description = "Route 53 record name (if configured)"
  value       = var.domain_name != "" ? aws_route53_record.alb[0].name : "Not configured"
}

output "hosted_zone_id" {
  description = "Route 53 hosted zone ID"
  value       = var.root_domain_name != "" ? aws_route53_zone.main[0].zone_id : (var.hosted_zone_id != "" ? var.hosted_zone_id : "Not configured")
}

output "hosted_zone_name_servers" {
  description = "Name servers for the hosted zone (for GoDaddy configuration)"
  value       = var.root_domain_name != "" ? aws_route53_zone.main[0].name_servers : []
}

output "root_domain_name" {
  description = "Root domain name"
  value       = var.root_domain_name != "" ? var.root_domain_name : "Not configured"
}

output "api_endpoint" {
  description = "API endpoint URL"
  value       = var.domain_name != "" ? "https://${var.domain_name}" : "https://${aws_lb.main.dns_name}"
}
