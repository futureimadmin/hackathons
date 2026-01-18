# Variables for S3 Frontend Module

variable "bucket_name" {
  description = "Name of the S3 bucket for frontend hosting"
  type        = string
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
