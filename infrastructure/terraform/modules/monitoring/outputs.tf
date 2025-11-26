output "sns_topic_arn" {
  description = "ARN of SNS topic for alerts"
  value       = aws_sns_topic.alerts.arn
}

output "ecs_log_group_name" {
  description = "Name of ECS CloudWatch log group"
  value       = aws_cloudwatch_log_group.ecs_backend.name
}

output "lambda_log_group_name" {
  description = "Name of Lambda CloudWatch log group"
  value       = aws_cloudwatch_log_group.lambda.name
}

output "application_log_group_name" {
  description = "Name of application CloudWatch log group"
  value       = aws_cloudwatch_log_group.application.name
}

output "dashboard_name" {
  description = "Name of CloudWatch dashboard"
  value       = aws_cloudwatch_dashboard.main.dashboard_name
}

output "dashboard_arn" {
  description = "ARN of CloudWatch dashboard"
  value       = aws_cloudwatch_dashboard.main.dashboard_arn
}
