output "metric_alarm_arns" {
  description = "Map of metric alarm ARNs keyed by alarm name"
  value       = { for k, a in aws_cloudwatch_metric_alarm.this : k => a.arn }
}

output "composite_alarm_arns" {
  description = "Map of composite alarm ARNs keyed by alarm name"
  value       = { for k, a in aws_cloudwatch_composite_alarm.this : k => a.arn }
}

output "dashboard_names" {
  description = "List of dashboard names created"
  value       = keys(aws_cloudwatch_dashboard.this)
}

output "sns_topic_arn" {
  description = "SNS topic ARN if created, else null"
  value       = var.create_sns_topic ? aws_sns_topic.this[0].arn : null
}
