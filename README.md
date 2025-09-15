# terraform-aws-observability

CloudWatch **metric alarms**, **composite alarms**, and **dashboards** in one module.

- Define alarms with a consistent schema (with optional default SNS actions)
- Compose alarms via CloudWatch `ALARM`/`OK`/`INSUFFICIENT_DATA` rules
- Build dashboards by passing raw widget JSON (module `jsonencode`s for you)

## Usage

```hcl
provider "aws" {
  region = "us-east-1"
}

module "observability" {
  source  = "JasTandon/observability/aws"
  version = "0.1.0"

  # Optional: create a default SNS topic for all alarms
  create_sns_topic           = true
  sns_topic_name             = "demo-cw-alarms"
  default_alarm_action_arns  = [] # if empty and create_sns_topic=true, module uses the created SNS topic.

  tags = {
    Project = "demo"
    Env     = "dev"
  }

  metric_alarms = [
    {
      name                 = "asg-cpu-high"
      namespace            = "AWS/EC2"
      metric_name          = "CPUUtilization"
      dimensions           = { AutoScalingGroupName = "my-asg" }
      statistic            = "Average"
      period               = 300
      evaluation_periods   = 2
      threshold            = 80
      comparison_operator  = "GreaterThanOrEqualToThreshold"
      treat_missing_data   = "notBreaching"
      alarm_description    = "ASG CPU >= 80% for 10m"
      tags                 = { Service = "web" }
    }
  ]

  composite_alarms = [
    {
      name                 = "fleet-unhealthy"
      alarm_rule           = "ALARM(asg-cpu-high) OR ALARM(alb-5xx-high)"
      alarm_description    = "Any major signal red"
      actions_enabled      = true
    }
  ]

  dashboards = {
    "demo-observability" = {
      widgets = [
        {
          "type" : "metric",
          "x" : 0, "y" : 0, "width" : 12, "height" : 6,
          "properties" : {
            "metrics" : [["AWS/EC2", "CPUUtilization", "AutoScalingGroupName", "my-asg"]],
            "stat" : "Average",
            "period" : 300,
            "region" : "us-east-1",
            "title" : "ASG CPU"
          }
        }
      ]
    }
  }
}
