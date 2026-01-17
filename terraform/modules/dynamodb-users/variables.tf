# Variables for DynamoDB Users Table Module

variable "table_name" {
  description = "Name of the DynamoDB table"
  type        = string
  default     = "ecommerce-users"
}

variable "billing_mode" {
  description = "Billing mode for DynamoDB table (PROVISIONED or PAY_PER_REQUEST)"
  type        = string
  default     = "PAY_PER_REQUEST"
  
  validation {
    condition     = contains(["PROVISIONED", "PAY_PER_REQUEST"], var.billing_mode)
    error_message = "Billing mode must be either PROVISIONED or PAY_PER_REQUEST."
  }
}

variable "read_capacity" {
  description = "Read capacity units (only for PROVISIONED billing mode)"
  type        = number
  default     = 5
}

variable "write_capacity" {
  description = "Write capacity units (only for PROVISIONED billing mode)"
  type        = number
  default     = 5
}

variable "gsi_read_capacity" {
  description = "Read capacity units for GSI (only for PROVISIONED billing mode)"
  type        = number
  default     = 5
}

variable "gsi_write_capacity" {
  description = "Write capacity units for GSI (only for PROVISIONED billing mode)"
  type        = number
  default     = 5
}

variable "enable_point_in_time_recovery" {
  description = "Enable point-in-time recovery for the table"
  type        = bool
  default     = true
}

variable "kms_key_arn" {
  description = "ARN of KMS key for encryption (optional)"
  type        = string
  default     = null
}

variable "enable_streams" {
  description = "Enable DynamoDB streams for audit logging"
  type        = bool
  default     = false
}

variable "alarm_actions" {
  description = "List of ARNs to notify when alarms trigger"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
