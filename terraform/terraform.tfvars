# Terraform Variables for eCommerce AI Platform
# This file contains the actual values for your deployment

# AWS Configuration
aws_region   = "us-east-2"
environment  = "dev"
project_name = "futureim-ecommerce-ai-platform"

# Network Configuration
vpc_cidr = "10.0.0.0/16"

# MySQL Configuration (stored in SSM Parameter Store)
# These values are retrieved from:
# - /ecommerce-ai-platform/dev/mysql/host
# - /ecommerce-ai-platform/dev/mysql/user
# - /ecommerce-ai-platform/dev/mysql/password
# - /ecommerce-ai-platform/dev/mysql/database
# Run: .\deployment\configure-mysql-connection.ps1 to set these values

# JWT Configuration (stored in SSM Parameter Store)
# JWT secret is retrieved from:
# - /ecommerce-ai-platform/dev/jwt/secret
# Tokens are configured to NOT EXPIRE (TOKEN_EXPIRY_HOURS = 0)
