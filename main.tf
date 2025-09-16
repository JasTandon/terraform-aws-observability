locals {
  # Use explicitly provided defaults, else (optionally) the module-managed SNS topic
  default_alarm_action_arns = (
    length(var.default_alarm_action_arns) > 0 ? var.default_alarm_action_arns : (
      var.create_sns_topic ? [aws_sns_topic.this[0].arn] : []
    )
  )
}

resource "random_id" "suffix" {
  count       = var.create_sns_topic && var.sns_topic_name == null ? 1 : 0
  byte_length = 4
}

resource "aws_sns_topic" "this" {
  count             = var.create_sns_topic ? 1 : 0
  name              = coalesce(var.sns_topic_name, "cw-alarms-${random_id.suffix[0].hex}")
  kms_master_key_id = var.sns_topic_kms_key_id
  tags              = var.tags
}

resource "aws_cloudwatch_metric_alarm" "this" {
  for_each = { for a in var.metric_alarms : a.name => a }

  alarm_name          = each.value.name
  comparison_operator = each.value.comparison_operator
  evaluation_periods  = each.value.evaluation_periods
  metric_name         = each.value.metric_name
  namespace           = each.value.namespace
  period              = each.value.period
  statistic           = try(each.value.statistic, null)
  extended_statistic  = try(each.value.extended_statistic, null)
  threshold           = each.value.threshold
  actions_enabled     = try(each.value.actions_enabled, true)
  treat_missing_data  = try(each.value.treat_missing_data, null)
  datapoints_to_alarm = try(each.value.datapoints_to_alarm, null)
  unit                = try(each.value.unit, null)
  alarm_description   = try(each.value.alarm_description, null)
  dimensions          = try(each.value.dimensions, null)

  alarm_actions             = try(each.value.alarm_actions, null) != null ? each.value.alarm_actions : local.default_alarm_action_arns
  ok_actions                = try(each.value.ok_actions, null)
  insufficient_data_actions = try(each.value.insufficient_data_actions, null)

  tags = merge(var.tags, try(each.value.tags, {}))
}

resource "aws_cloudwatch_composite_alarm" "this" {
  for_each = { for a in var.composite_alarms : a.name => a }

  alarm_name        = each.value.name
  alarm_rule        = each.value.alarm_rule
  alarm_description = try(each.value.alarm_description, null)
  actions_enabled   = try(each.value.actions_enabled, true)

  alarm_actions             = try(each.value.alarm_actions, null) != null ? each.value.alarm_actions : local.default_alarm_action_arns
  ok_actions                = try(each.value.ok_actions, null)
  insufficient_data_actions = try(each.value.insufficient_data_actions, null)

  tags = merge(var.tags, try(each.value.tags, {}))
}

############################################
# CloudWatch Dashboards
############################################
resource "aws_cloudwatch_dashboard" "this" {
  for_each       = var.cw_dashboards
  dashboard_name = each.key
  dashboard_body = each.value.body
}

############################################
# Alarm State Change → CloudWatch Logs
############################################
locals {
  _log_group_arn = (
    var.enable_alarm_state_change_capture
    ? (
      var.create_alarm_state_change_log_group
      ? try(aws_cloudwatch_log_group.alarm_state_changes[0].arn, null)
      : var.alarm_state_change_log_group_arn
    )
    : null
  )
}

# (optional) create log group
resource "aws_cloudwatch_log_group" "alarm_state_changes" {
  count             = var.enable_alarm_state_change_capture && var.create_alarm_state_change_log_group ? 1 : 0
  name              = var.alarm_state_change_log_group_name
  retention_in_days = var.alarm_state_change_log_retention_days
}

# EventBridge rule for Alarm State Change events
resource "aws_cloudwatch_event_rule" "alarm_state_change" {
  count       = var.enable_alarm_state_change_capture ? 1 : 0
  name        = "alarm-state-change-to-logs"
  description = "Capture all CloudWatch Alarm State Change events"
  event_pattern = jsonencode({
    "source" : ["aws.cloudwatch"],
    "detail-type" : ["CloudWatch Alarm State Change"]
  })
}

# EventBridge target to the log group (requires IAM role ARN)
resource "aws_cloudwatch_event_target" "to_logs" {
  count     = var.enable_alarm_state_change_capture ? 1 : 0
  rule      = aws_cloudwatch_event_rule.alarm_state_change[0].name
  target_id = "to-logs"
  arn       = local._log_group_arn
  role_arn  = var.eventbridge_to_logs_role_arn
}
