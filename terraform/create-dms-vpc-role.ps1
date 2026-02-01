# Create DMS VPC Role
# Creates the required IAM role for DMS to manage VPC resources

$ErrorActionPreference = "Stop"

Write-Host "Creating DMS VPC Role..." -ForegroundColor Green

$RoleName = "dms-vpc-role"
$PolicyArn = "arn:aws:iam::aws:policy/service-role/AmazonDMSVPCManagementRole"

# Create trust policy document
$TrustPolicy = @"
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "dms.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
"@

# Save trust policy to temp file
$TrustPolicyFile = "trust-policy-temp.json"
$TrustPolicy | Out-File -FilePath $TrustPolicyFile -Encoding ASCII

# Create IAM role
Write-Host "`nCreating IAM role: $RoleName" -ForegroundColor Yellow
try {
    aws iam create-role `
        --role-name $RoleName `
        --assume-role-policy-document file://$TrustPolicyFile `
        --description "DMS VPC Management Role"
    Write-Host "IAM role created successfully" -ForegroundColor Green
} catch {
    Write-Host "IAM role may already exist or error occurred: $_" -ForegroundColor Yellow
}

# Attach managed policy
Write-Host "`nAttaching managed policy to role..." -ForegroundColor Yellow
try {
    aws iam attach-role-policy `
        --role-name $RoleName `
        --policy-arn $PolicyArn
    Write-Host "Policy attached successfully" -ForegroundColor Green
} catch {
    Write-Host "Policy may already be attached or error occurred: $_" -ForegroundColor Yellow
}

# Clean up temp file
Remove-Item $TrustPolicyFile -Force

Write-Host "`n=== DMS VPC Role Created ===" -ForegroundColor Green
Write-Host "Role Name: $RoleName" -ForegroundColor Cyan
Write-Host "Policy: AmazonDMSVPCManagementRole" -ForegroundColor Cyan
Write-Host "`nNext Steps:" -ForegroundColor Yellow
Write-Host "1. Proceed with Terraform deployment" -ForegroundColor White
Write-Host "2. DMS will use this role to manage VPC resources" -ForegroundColor White
