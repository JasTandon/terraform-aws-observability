# ---------------- Inputs for the example ----------------
variable "region" {
  type    = string
  default = "us-east-1"
}

# The log group that will receive CloudWatch Alarm State Change events
variable "alarm_events_log_group_name" {
  type    = string
  default = "/aws/events/cloudwatch-alarm-state-changes"
}