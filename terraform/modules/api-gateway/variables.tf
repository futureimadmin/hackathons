# Variables for API Gateway Module

variable "api_name" {
  description = "Name of the API Gateway"
  type        = string
  default     = "ecommerce-platform-api"
}

variable "stage_name" {
  description = "API Gateway stage name"
  type        = string
  default     = "prod"
}

variable "auth_lambda_function_name" {
  description = "Name of the authentication Lambda function"
  type        = string
}

variable "auth_lambda_invoke_arn" {
  description = "Invoke ARN of the authentication Lambda function"
  type        = string
}

variable "analytics_lambda_function_name" {
  description = "Name of the analytics Lambda function"
  type        = string
  default     = ""
}

variable "analytics_lambda_invoke_arn" {
  description = "Invoke ARN of the analytics Lambda function"
  type        = string
  default     = ""
}

variable "market_intelligence_lambda_function_name" {
  description = "Name of the Market Intelligence Hub Lambda function"
  type        = string
  default     = ""
}

variable "market_intelligence_lambda_invoke_arn" {
  description = "Invoke ARN of the Market Intelligence Hub Lambda function"
  type        = string
  default     = ""
}

variable "jwt_secret_name" {
  description = "Name of the JWT secret in Secrets Manager"
  type        = string
  default     = "ecommerce-jwt-secret"
}

variable "kms_key_arn" {
  description = "ARN of KMS key for encryption"
  type        = string
}

variable "cors_allowed_origin" {
  description = "Allowed origin for CORS"
  type        = string
  default     = "*"
}

variable "throttling_burst_limit" {
  description = "API Gateway throttling burst limit"
  type        = number
  default     = 5000
}

variable "throttling_rate_limit" {
  description = "API Gateway throttling rate limit (requests per second)"
  type        = number
  default     = 10000
}

variable "quota_limit" {
  description = "Daily quota limit for API requests"
  type        = number
  default     = 1000000
}

variable "enable_xray_tracing" {
  description = "Enable X-Ray tracing for API Gateway"
  type        = bool
  default     = true
}

variable "enable_data_trace" {
  description = "Enable data trace logging (includes request/response bodies)"
  type        = bool
  default     = false
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 30
}

variable "error_threshold_4xx" {
  description = "Threshold for 4XX error alarm"
  type        = number
  default     = 100
}

variable "error_threshold_5xx" {
  description = "Threshold for 5XX error alarm"
  type        = number
  default     = 10
}

variable "latency_threshold_ms" {
  description = "Threshold for latency alarm in milliseconds"
  type        = number
  default     = 1000
}

variable "alarm_actions" {
  description = "List of ARNs to notify when alarms trigger"
  type        = list(string)
  default     = []
}

variable "enable_waf" {
  description = "Enable AWS WAF for API Gateway"
  type        = bool
  default     = true
}

variable "waf_rate_limit" {
  description = "WAF rate limit (requests per 5 minutes from single IP)"
  type        = number
  default     = 2000
}

variable "waf_blocked_countries" {
  description = "List of country codes to block (ISO 3166-1 alpha-2)"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "demand_insights_lambda_function_name" {
  description = "Name of the Demand Insights Engine Lambda function"
  type        = string
  default     = ""
}

variable "demand_insights_lambda_invoke_arn" {
  description = "Invoke ARN of the Demand Insights Engine Lambda function"
  type        = string
  default     = ""
}

variable "compliance_guardian_lambda_function_name" {
  description = "Name of the Compliance Guardian Lambda function"
  type        = string
  default     = ""
}

variable "compliance_guardian_lambda_invoke_arn" {
  description = "Invoke ARN of the Compliance Guardian Lambda function"
  type        = string
  default     = ""
}

variable "retail_copilot_lambda_function_name" {
  description = "Name of the Retail Copilot Lambda function"
  type        = string
  default     = ""
}

variable "retail_copilot_lambda_invoke_arn" {
  description = "Invoke ARN of the Retail Copilot Lambda function"
  type        = string
  default     = ""
}

variable "global_market_pulse_lambda_function_name" {
  description = "Name of the Global Market Pulse Lambda function"
  type        = string
  default     = ""
}

variable "global_market_pulse_lambda_invoke_arn" {
  description = "Invoke ARN of the Global Market Pulse Lambda function"
  type        = string
  default     = ""
}
