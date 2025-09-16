output "metric_alarm_arns" {
  description = "Map of metric alarm ARNs keyed by alarm name"
  value       = { for k, a in aws_cloudwatch_metric_alarm.this : k => a.arn }
}

output "composite_alarm_arns" {
  description = "Map of composite alarm ARNs keyed by alarm name"
  value       = { for k, a in aws_cloudwatch_composite_alarm.this : k => a.arn }
}

output "sns_topic_arn" {
  description = "SNS topic ARN if created, else null"
  value       = var.create_sns_topic ? aws_sns_topic.this[0].arn : null
}

output "dashboard_names" {
  description = "Names of created dashboards."
  value       = [for k, _ in aws_cloudwatch_dashboard.this : k]
}

output "alarm_events_log_group_arn" {
  description = "Log group ARN receiving Alarm State Change events (null if disabled)."
  value       = local._log_group_arn
}

output "alarm_state_change_rule_arn" {
  description = "EventBridge rule ARN (null if disabled)."
  value       = try(aws_cloudwatch_event_rule.alarm_state_change[0].arn, null)
}
