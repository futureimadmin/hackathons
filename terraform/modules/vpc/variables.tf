# VPC module variables

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "project_name" {
  description = "Project name"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
}

variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)
}

variable "kms_key_id" {
  description = "KMS key ARN for encryption (CloudWatch Logs requires ARN format)"
  type        = string
}

# VPN Configuration Variables
variable "enable_vpn" {
  description = "Enable VPN Gateway for on-premises connectivity"
  type        = bool
  default     = false
}

variable "customer_gateway_ip" {
  description = "Public IP address of your on-premises VPN device"
  type        = string
  default     = ""
}

variable "customer_gateway_bgp_asn" {
  description = "BGP ASN for customer gateway"
  type        = number
  default     = 65000
}

variable "onprem_cidr_block" {
  description = "CIDR block of your on-premises network (e.g., 172.20.0.0/16)"
  type        = string
  default     = "172.20.0.0/16"
}

variable "use_route_propagation" {
  description = "Use VPN route propagation instead of static routes"
  type        = bool
  default     = true
}

# MySQL Configuration for DMS Security Group
variable "mysql_server_ip" {
  description = "MySQL server IP address for DMS security group rule (can be private IP or public IP)"
  type        = string
  default     = "172.20.10.2"
}
