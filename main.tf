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

resource "aws_cloudwatch_dashboard" "this" {
  for_each       = var.dashboards
  dashboard_name = each.key
  dashboard_body = jsonencode({ widgets = each.value.widgets })
}
