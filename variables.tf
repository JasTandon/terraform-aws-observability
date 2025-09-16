variable "tags" {
  description = "Default tags applied to all resources"
  type        = map(string)
  default     = {}
}

variable "create_sns_topic" {
  description = "If true, create an SNS topic and use it as the default alarm action when no per-alarm actions are provided."
  type        = bool
  default     = false
}

variable "sns_topic_name" {
  description = "Optional name for the SNS topic (if create_sns_topic = true). If not set, a random suffix will be appended."
  type        = string
  default     = null
}

variable "sns_topic_kms_key_id" {
  description = "Optional KMS key ID/ARN for encrypting the SNS topic."
  type        = string
  default     = null
}

variable "default_alarm_action_arns" {
  description = "Default actions for alarms (e.g., SNS topic ARNs). Used when an alarm does not specify its own actions."
  type        = list(string)
  default     = []
}

variable "metric_alarms" {
  description = <<EOT
List of CloudWatch metric alarms. Either `statistic` or `extended_statistic` should be set for each alarm.

Schema:
- name (string) — unique alarm name
- namespace (string)
- metric_name (string)
- dimensions (map(string))
- statistic (string) OR extended_statistic (string)
- period (number)
- evaluation_periods (number)
- threshold (number)
- comparison_operator (string)
- treat_missing_data (string) — e.g., notBreaching, missing, ignore, breaching
- datapoints_to_alarm (number)
- unit (string)
- alarm_description (string)
- actions_enabled (bool)
- alarm_actions / ok_actions / insufficient_data_actions (list(string))
- tags (map(string))
EOT
  type = list(object({
    name                      = string
    namespace                 = string
    metric_name               = string
    dimensions                = optional(map(string), {})
    statistic                 = optional(string)
    extended_statistic        = optional(string)
    period                    = number
    evaluation_periods        = number
    threshold                 = number
    comparison_operator       = string
    treat_missing_data        = optional(string)
    datapoints_to_alarm       = optional(number)
    unit                      = optional(string)
    alarm_description         = optional(string)
    actions_enabled           = optional(bool, true)
    alarm_actions             = optional(list(string))
    ok_actions                = optional(list(string))
    insufficient_data_actions = optional(list(string))
    tags                      = optional(map(string), {})
  }))
  default = []
}

variable "composite_alarms" {
  description = <<EOT
List of CloudWatch composite alarms.
Schema:
- name (string)
- alarm_rule (string) — e.g. "ALARM(alarmA) OR ALARM(alarmB)"
- alarm_description (string)
- actions_enabled (bool)
- alarm_actions / ok_actions / insufficient_data_actions (list(string))
- tags (map(string))
EOT
  type = list(object({
    name                      = string
    alarm_rule                = string
    alarm_description         = optional(string)
    actions_enabled           = optional(bool, true)
    alarm_actions             = optional(list(string))
    ok_actions                = optional(list(string))
    insufficient_data_actions = optional(list(string))
    tags                      = optional(map(string), {})
  }))
  default = []
}

# ---------------- CloudWatch Dashboards ----------------
variable "cw_dashboards" {
  description = <<EOT
Map of CloudWatch dashboards to create.
Key = dashboard name, Value.body = JSON string for dashboard_body.
Example:
cw_dashboards = {
  "my-dash" = { body = jsonencode({ widgets = [...] }) }
}
EOT
  type = map(object({
    body = string
  }))
  default = {}
}

# ---------------- Alarm State Change → Logs (EventBridge) ----------------
variable "enable_alarm_state_change_capture" {
  description = "If true, create EventBridge rule/target to ship CloudWatch Alarm State Change events to CloudWatch Logs."
  type        = bool
  default     = false
}

variable "eventbridge_to_logs_role_arn" {
  description = "IAM role ARN that EventBridge assumes to write into the destination log group (created by JasTandon/iam/aws). Required when enable_alarm_state_change_capture = true."
  type        = string
  default     = null
}

variable "create_alarm_state_change_log_group" {
  description = "If true, create the destination CloudWatch Log Group here. If false, provide alarm_state_change_log_group_arn."
  type        = bool
  default     = true
}

variable "alarm_state_change_log_group_name" {
  description = "Name of the CloudWatch Log Group to store alarm state change events (used when create_alarm_state_change_log_group = true)."
  type        = string
  default     = "/aws/events/cloudwatch-alarm-state-changes"
}

variable "alarm_state_change_log_retention_days" {
  description = "Retention in days for the created log group."
  type        = number
  default     = 30
}

variable "alarm_state_change_log_group_arn" {
  description = "If create_alarm_state_change_log_group = false, supply the target log group ARN here."
  type        = string
  default     = null
}
