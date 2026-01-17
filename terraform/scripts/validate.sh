#!/bin/bash
# Script to validate Terraform configuration

set -e

echo "Validating Terraform configuration..."
echo ""

# Check if Terraform is installed
if ! command -v terraform &> /dev/null; then
    echo "❌ Terraform is not installed"
    echo "Please install Terraform: https://www.terraform.io/downloads"
    exit 1
fi

echo "✓ Terraform is installed"
terraform version
echo ""

# Check if backend.tfvars exists
if [ ! -f "backend.tfvars" ]; then
    echo "⚠ backend.tfvars not found"
    echo "Copy backend.tfvars.example to backend.tfvars and update values"
else
    echo "✓ backend.tfvars exists"
fi

# Check if terraform.tfvars exists
if [ ! -f "terraform.tfvars" ]; then
    echo "⚠ terraform.tfvars not found"
    echo "Copy terraform.tfvars.example to terraform.tfvars and update values"
else
    echo "✓ terraform.tfvars exists"
fi

echo ""

# Format check
echo "Checking Terraform formatting..."
if terraform fmt -check -recursive; then
    echo "✓ Terraform files are properly formatted"
else
    echo "⚠ Some files need formatting. Run: terraform fmt -recursive"
fi

echo ""

# Initialize if not already initialized
if [ ! -d ".terraform" ]; then
    echo "Terraform not initialized. Skipping validation."
    echo "Run: terraform init -backend-config=backend.tfvars"
    exit 0
fi

# Validate
echo "Validating Terraform configuration..."
if terraform validate; then
    echo "✓ Terraform configuration is valid"
else
    echo "❌ Terraform configuration has errors"
    exit 1
fi

echo ""
echo "✓ All checks passed!"
