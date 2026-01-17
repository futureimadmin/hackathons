# Variables for Athena Module

variable "workgroup_name" {
  description = "Name of the Athena workgroup"
  type        = string
  default     = "ecommerce-analytics"
}

variable "query_results_bucket_name" {
  description = "Name of the S3 bucket for Athena query results"
  type        = string
}

variable "query_results_retention_days" {
  description = "Number of days to retain query results in S3"
  type        = number
  default     = 30
}

variable "bytes_scanned_cutoff" {
  description = "Maximum bytes scanned per query (default: 10 GB)"
  type        = number
  default     = 10737418240
}

variable "high_cost_threshold_bytes" {
  description = "Threshold for high query cost alarm (bytes scanned)"
  type        = number
  default     = 5368709120 # 5 GB
}

variable "failure_threshold" {
  description = "Threshold for query failure alarm (number of failures)"
  type        = number
  default     = 5
}

variable "log_retention_days" {
  description = "Number of days to retain CloudWatch logs"
  type        = number
  default     = 30
}

variable "sample_database_name" {
  description = "Name of a sample Glue database for named queries"
  type        = string
  default     = "market_intelligence_hub"
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
