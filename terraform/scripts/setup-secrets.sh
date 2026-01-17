#!/bin/bash

# Script to set up AWS Secrets Manager secrets for eCommerce AI Platform
# This script creates the necessary secrets for DMS and other services

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    print_error "AWS CLI is not installed. Please install it first."
    exit 1
fi

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    print_warning "jq is not installed. Some features may not work properly."
fi

# Get AWS region
AWS_REGION=${AWS_REGION:-us-east-1}
print_info "Using AWS region: $AWS_REGION"

# Function to create or update secret
create_or_update_secret() {
    local secret_name=$1
    local secret_value=$2
    local description=$3
    
    print_info "Checking if secret '$secret_name' exists..."
    
    if aws secretsmanager describe-secret --secret-id "$secret_name" --region "$AWS_REGION" &> /dev/null; then
        print_warning "Secret '$secret_name' already exists. Updating..."
        aws secretsmanager put-secret-value \
            --secret-id "$secret_name" \
            --secret-string "$secret_value" \
            --region "$AWS_REGION" > /dev/null
        print_info "Secret '$secret_name' updated successfully"
    else
        print_info "Creating secret '$secret_name'..."
        aws secretsmanager create-secret \
            --name "$secret_name" \
            --description "$description" \
            --secret-string "$secret_value" \
            --region "$AWS_REGION" > /dev/null
        print_info "Secret '$secret_name' created successfully"
    fi
}

# Function to generate random string
generate_random_string() {
    local length=${1:-32}
    openssl rand -base64 $length | tr -d "=+/" | cut -c1-$length
}

print_info "========================================="
print_info "eCommerce AI Platform - Secrets Setup"
print_info "========================================="
echo ""

# 1. On-Premise MySQL Password
print_info "Setting up on-premise MySQL password..."
MYSQL_PASSWORD=${MYSQL_PASSWORD:-"Srikar@123"}
create_or_update_secret \
    "ecommerce/onprem-mysql-password" \
    "{\"password\":\"$MYSQL_PASSWORD\"}" \
    "On-premise MySQL root password for DMS replication"

# 2. JWT Secret
print_info "Setting up JWT secret..."
JWT_SECRET=${JWT_SECRET:-$(generate_random_string 64)}
create_or_update_secret \
    "ecommerce/jwt-secret" \
    "{\"secret\":\"$JWT_SECRET\"}" \
    "JWT signing secret for authentication service"

# 3. Encryption Key
print_info "Setting up application encryption key..."
ENCRYPTION_KEY=${ENCRYPTION_KEY:-$(generate_random_string 32)}
create_or_update_secret \
    "ecommerce/encryption-key" \
    "{\"key\":\"$ENCRYPTION_KEY\"}" \
    "Application-level encryption key"

# 4. Database Encryption Key (for future use)
print_info "Setting up database encryption key..."
DB_ENCRYPTION_KEY=${DB_ENCRYPTION_KEY:-$(generate_random_string 32)}
create_or_update_secret \
    "ecommerce/db-encryption-key" \
    "{\"key\":\"$DB_ENCRYPTION_KEY\"}" \
    "Database encryption key"

echo ""
print_info "========================================="
print_info "All secrets created/updated successfully!"
print_info "========================================="
echo ""

# Display secret ARNs
print_info "Secret ARNs:"
echo ""

for secret_name in \
    "ecommerce/onprem-mysql-password" \
    "ecommerce/jwt-secret" \
    "ecommerce/encryption-key" \
    "ecommerce/db-encryption-key"; do
    
    SECRET_ARN=$(aws secretsmanager describe-secret \
        --secret-id "$secret_name" \
        --region "$AWS_REGION" \
        --query 'ARN' \
        --output text 2>/dev/null || echo "Not found")
    
    echo "  $secret_name: $SECRET_ARN"
done

echo ""
print_info "You can retrieve secrets using:"
print_info "  aws secretsmanager get-secret-value --secret-id <secret-name> --region $AWS_REGION"
echo ""

# Optional: Test secret retrieval
print_info "Testing secret retrieval..."
if aws secretsmanager get-secret-value \
    --secret-id "ecommerce/onprem-mysql-password" \
    --region "$AWS_REGION" \
    --query 'SecretString' \
    --output text &> /dev/null; then
    print_info "✓ Secrets are accessible"
else
    print_error "✗ Failed to retrieve secrets. Check IAM permissions."
    exit 1
fi

echo ""
print_info "Setup complete!"
