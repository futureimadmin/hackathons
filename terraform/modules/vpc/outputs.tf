# VPC module outputs

output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "vpc_cidr" {
  description = "VPC CIDR block"
  value       = aws_vpc.main.cidr_block
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = aws_subnet.private[*].id
}

output "nat_gateway_ids" {
  description = "NAT Gateway IDs"
  value       = aws_nat_gateway.main[*].id
}

output "internet_gateway_id" {
  description = "Internet Gateway ID"
  value       = aws_internet_gateway.main.id
}

output "lambda_security_group_id" {
  description = "Lambda security group ID"
  value       = aws_security_group.lambda.id
}

output "dms_security_group_id" {
  description = "DMS security group ID"
  value       = aws_security_group.dms.id
}

output "batch_security_group_id" {
  description = "Batch security group ID"
  value       = aws_security_group.batch.id
}

output "vpc_endpoints_security_group_id" {
  description = "VPC endpoints security group ID"
  value       = aws_security_group.vpc_endpoints.id
}

output "api_gateway_security_group_id" {
  description = "API Gateway security group ID"
  value       = aws_security_group.api_gateway.id
}

# VPN Outputs
output "vpn_gateway_id" {
  description = "VPN Gateway ID"
  value       = var.enable_vpn ? aws_vpn_gateway.main[0].id : null
}

output "vpn_connection_id" {
  description = "VPN Connection ID"
  value       = var.enable_vpn && var.customer_gateway_ip != "" ? aws_vpn_connection.main[0].id : null
}

output "customer_gateway_id" {
  description = "Customer Gateway ID"
  value       = var.enable_vpn && var.customer_gateway_ip != "" ? aws_customer_gateway.main[0].id : null
}

output "vpn_connection_tunnel1_address" {
  description = "VPN Connection Tunnel 1 Address"
  value       = var.enable_vpn && var.customer_gateway_ip != "" ? aws_vpn_connection.main[0].tunnel1_address : null
}

output "vpn_connection_tunnel2_address" {
  description = "VPN Connection Tunnel 2 Address"
  value       = var.enable_vpn && var.customer_gateway_ip != "" ? aws_vpn_connection.main[0].tunnel2_address : null
}

output "vpn_connection_tunnel1_preshared_key" {
  description = "VPN Connection Tunnel 1 Pre-Shared Key"
  value       = var.enable_vpn && var.customer_gateway_ip != "" ? aws_vpn_connection.main[0].tunnel1_preshared_key : null
  sensitive   = true
}

output "vpn_connection_tunnel2_preshared_key" {
  description = "VPN Connection Tunnel 2 Pre-Shared Key"
  value       = var.enable_vpn && var.customer_gateway_ip != "" ? aws_vpn_connection.main[0].tunnel2_preshared_key : null
  sensitive   = true
}
