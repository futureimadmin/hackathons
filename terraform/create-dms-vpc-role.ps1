# Create DMS VPC Role
# AWS DMS requires a specific IAM role named "dms-vpc-role" to manage VPC resources

Write-Host "Creating DMS VPC Role..." -ForegroundColor Cyan

# Check if role already exists
$roleExists = aws iam get-role --role-name dms-vpc-role 2>&1

if ($LASTEXITCODE -eq 0) {
    Write-Host "dms-vpc-role already exists!" -ForegroundColor Green
} else {
    Write-Host "Creating dms-vpc-role..." -ForegroundColor Yellow
    
    # Create the trust policy JSON file directly
    $policyJson = @'
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
'@
    [System.IO.File]::WriteAllText("$PWD\trust-policy.json", $policyJson)
    
    # Create the role
    aws iam create-role --role-name dms-vpc-role --assume-role-policy-document file://trust-policy.json --description "DMS VPC management role"
    
    # Clean up temp file
    Remove-Item "trust-policy.json" -ErrorAction SilentlyContinue
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Role created successfully!" -ForegroundColor Green
    } else {
        Write-Host "Failed to create role" -ForegroundColor Red
        exit 1
    }
}

# Attach the AWS managed policy
Write-Host "Attaching AmazonDMSVPCManagementRole policy..." -ForegroundColor Yellow

aws iam attach-role-policy --role-name dms-vpc-role --policy-arn arn:aws:iam::aws:policy/service-role/AmazonDMSVPCManagementRole

if ($LASTEXITCODE -eq 0) {
    Write-Host "Policy attached successfully!" -ForegroundColor Green
} else {
    Write-Host "Failed to attach policy (may already be attached)" -ForegroundColor Yellow
}

Write-Host "DMS VPC Role is ready!" -ForegroundColor Green
Write-Host "You can now run: terraform apply -var-file=terraform.dev.tfvars" -ForegroundColor Cyan
