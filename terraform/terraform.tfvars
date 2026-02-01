# Terraform Variables for eCommerce AI Platform
# This file contains the actual values for your deployment

# AWS Configuration
aws_region   = "us-east-2"
environment  = "dev"
project_name = "futureim-ecommerce-ai-platform"

# Network Configuration
vpc_cidr = "10.0.0.0/16"

# MySQL Configuration
# TEMPORARY DIRECT CONNECTION (NO VPN) - FOR TESTING ONLY
# Connecting directly to public IP instead of through VPN
# WARNING: This is NOT secure for production use!
mysql_server_name     = "106.192.45.56"  # Your public IP (CORRECTED)
mysql_port            = 3306
mysql_username        = "dms_remote"
mysql_database_name   = "ecommerce"
mysql_ssl_mode        = "none"

# MySQL password is stored in AWS Secrets Manager
# Update the secret with: aws secretsmanager update-secret --secret-id <arn> --secret-string '{"username":"dms_remote","password":"SaiesaShanmukha@123"}'

# JWT Configuration (stored in SSM Parameter Store)
# JWT secret is retrieved from:
# - /ecommerce-ai-platform/dev/jwt/secret
# Tokens are configured to NOT EXPIRE (TOKEN_EXPIRY_HOURS = 0)

# VPN Configuration - DISABLED for direct connection
# Re-enable this when you have VPN-capable router configured
enable_vpn              = false
customer_gateway_ip     = "106.192.45.56"  # Your public IP (CORRECTED)
customer_gateway_bgp_asn = 65000
onprem_cidr_block       = "172.20.0.0/16"
use_route_propagation   = false
