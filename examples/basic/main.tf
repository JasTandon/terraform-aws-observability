terraform {
  required_version = ">= 1.4.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

provider "aws" {
  region = var.region
}

variable "region" {
  type    = string
  default = "us-east-1"
}

module "observability" {
  source = "../.." # local test; Need to switch to the GitHub source + tag after publishing

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

  dashboards = {
    "example-observability" = {
      widgets = [
        {
          "type" : "metric",
          "x" : 0, "y" : 0, "width" : 12, "height" : 6,
          "properties" : {
            "metrics" : [["AWS/EC2", "CPUUtilization", "AutoScalingGroupName", "my-asg"]],
            "stat" : "Average",
            "period" : 300,
            "region" : var.region,
            "title" : "ASG CPU"
          }
        },
        {
          "type" : "metric",
          "x" : 12, "y" : 0, "width" : 12, "height" : 6,
          "properties" : {
            "metrics" : [["AWS/ApplicationELB", "HTTPCode_ELB_5XX_Count", "LoadBalancer", "app/my-alb/1234567890abcdef"]],
            "stat" : "Sum",
            "period" : 300,
            "region" : var.region,
            "title" : "ALB 5XX"
          }
        }
      ]
    }
  }
}
