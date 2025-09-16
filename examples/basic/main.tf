locals {
  account_id = data.aws_caller_identity.current.account_id
  aws_region = data.aws_region.current.name

  # Name for the EventBridge->Logs role we create via the IAM module
  events_to_logs_role_name = "${terraform.workspace}-cw-events-to-logs"
}

# ===================================================================
# IAM role + inline policy for EventBridge to write into CloudWatch Logs
# (Created via your IAM module)
# ===================================================================
module "iam_events_to_logs" {
  source  = "JasTandon/iam/aws"
  version = ">= 0.1.0"

  roles = [
    {
      name = local.events_to_logs_role_name

      # EventBridge service principal
      trust = {
        service_principals = ["events.amazonaws.com"]
      }

      # Allow CreateLogStream on the log group, and PutLogEvents on its streams
      inline_policies = {
        "write-to-cwl" = jsonencode({
          Version = "2012-10-17"
          Statement = [
            {
              Effect   = "Allow"
              Action   = ["logs:CreateLogStream"]
              Resource = "arn:aws:logs:${local.aws_region}:${local.account_id}:log-group:${var.alarm_events_log_group_name}"
            },
            {
              Effect   = "Allow"
              Action   = ["logs:PutLogEvents"]
              Resource = "arn:aws:logs:${local.aws_region}:${local.account_id}:log-group:${var.alarm_events_log_group_name}:*"
            }
          ]
        })
      }
    }
  ]
}

# ===================================================================
# Observability module under test (local source for the example)
# - Alarms/SNS examples (as you had)
# - Dashboard (updated to 'body = jsonencode({...})')
# - EventBridge Alarm State Change -> Logs pipeline enabled
# ===================================================================
module "observability" {
  source = "../.." # local test;

  # ----- Example: SNS + metric/composite alarms -----
  create_sns_topic = true
  sns_topic_name   = "example-cw-alarms"

  tags = {
    Project = "example"
    Env     = "dev"
  }

  metric_alarms = [
    {
      name                = "asg-cpu-high"
      namespace           = "AWS/EC2"
      metric_name         = "CPUUtilization"
      dimensions          = { AutoScalingGroupName = "my-asg" }
      statistic           = "Average"
      period              = 300
      evaluation_periods  = 2
      threshold           = 80
      comparison_operator = "GreaterThanOrEqualToThreshold"
      treat_missing_data  = "notBreaching"
      alarm_description   = "ASG CPU >= 80% for 10m"
      tags                = { Service = "web" }
    },
    {
      name                = "alb-5xx-high"
      namespace           = "AWS/ApplicationELB"
      metric_name         = "HTTPCode_ELB_5XX_Count"
      dimensions          = { LoadBalancer = "app/my-alb/1234567890abcdef" }
      statistic           = "Sum"
      period              = 300
      evaluation_periods  = 1
      threshold           = 50
      comparison_operator = "GreaterThanOrEqualToThreshold"
      treat_missing_data  = "notBreaching"
      alarm_description   = "ALB 5XX >= 50 in 5m"
    }
  ]

  composite_alarms = [
    {
      name              = "fleet-unhealthy"
      alarm_rule        = "ALARM(asg-cpu-high) OR ALARM(alb-5xx-high)"
      alarm_description = "Any major signal red"
    }
  ]

  # ----- CloudWatch dashboard (updated shape: body=jsonencode({...})) -----
  cw_dashboards = {
    "example-observability" = {
      body = jsonencode({
        widgets = [
          {
            "type" : "metric",
            "x" : 0, "y" : 0, "width" : 12, "height" : 6,
            "properties" : {
              "metrics" : [["AWS/EC2", "CPUUtilization", "AutoScalingGroupName", "my-asg"]],
              "stat"    : "Average",
              "period"  : 300,
              "region"  : var.region,
              "title"   : "ASG CPU"
            }
          },
          {
            "type" : "metric",
            "x" : 12, "y" : 0, "width" : 12, "height" : 6,
            "properties" : {
              "metrics" : [["AWS/ApplicationELB", "HTTPCode_ELB_5XX_Count", "LoadBalancer", "app/my-alb/1234567890abcdef"]],
              "stat"    : "Sum",
              "period"  : 300,
              "region"  : var.region,
              "title"   : "ALB 5XX"
            }
          }
        ]
      })
    }
  }

  # ----- Enable Alarm State Change -> Logs pipeline (provided by module) -----
  enable_alarm_state_change_capture   = true
  create_alarm_state_change_log_group = true
  alarm_state_change_log_group_name   = var.alarm_events_log_group_name

  # Use the role created above via the IAM module
  eventbridge_to_logs_role_arn = module.iam_events_to_logs.role_arns[local.events_to_logs_role_name]
}