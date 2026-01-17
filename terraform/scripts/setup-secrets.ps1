# PowerShell script to set up AWS Secrets Manager secrets for eCommerce AI Platform
# This script creates the necessary secrets for DMS and other services

param(
    [string]$Region = "us-east-1",
    [string]$MySQLPassword = "Srikar@123"
)

# Function to print colored output
function Write-Info {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Green
}

function Write-Warning {
    param([string]$Message)
    Write-Host "[WARNING] $Message" -ForegroundColor Yellow
}

function Write-ErrorMsg {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

# Check if AWS CLI is installed
try {
    $null = aws --version
} catch {
    Write-ErrorMsg "AWS CLI is not installed. Please install it first."
    exit 1
}

Write-Info "========================================="
Write-Info "eCommerce AI Platform - Secrets Setup"
Write-Info "========================================="
Write-Host ""

Write-Info "Using AWS region: $Region"

# Function to create or update secret
function Set-Secret {
    param(
        [string]$SecretName,
        [string]$SecretValue,
        [string]$Description
    )
    
    Write-Info "Checking if secret '$SecretName' exists..."
    
    try {
        $null = aws secretsmanager describe-secret --secret-id $SecretName --region $Region 2>&1
        Write-Warning "Secret '$SecretName' already exists. Updating..."
        aws secretsmanager put-secret-value `
            --secret-id $SecretName `
            --secret-string $SecretValue `
            --region $Region | Out-Null
        Write-Info "Secret '$SecretName' updated successfully"
    } catch {
        Write-Info "Creating secret '$SecretName'..."
        aws secretsmanager create-secret `
            --name $SecretName `
            --description $Description `
            --secret-string $SecretValue `
            --region $Region | Out-Null
        Write-Info "Secret '$SecretName' created successfully"
    }
}

# Function to generate random string
function New-RandomString {
    param([int]$Length = 32)
    
    $bytes = New-Object byte[] $Length
    $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    $rng.GetBytes($bytes)
    $base64 = [Convert]::ToBase64String($bytes)
    return $base64.Substring(0, $Length) -replace '[+/=]', ''
}

# 1. On-Premise MySQL Password
Write-Info "Setting up on-premise MySQL password..."
$mysqlPasswordJson = @{
    password = $MySQLPassword
} | ConvertTo-Json -Compress

Set-Secret `
    -SecretName "ecommerce/onprem-mysql-password" `
    -SecretValue $mysqlPasswordJson `
    -Description "On-premise MySQL root password for DMS replication"

# 2. JWT Secret
Write-Info "Setting up JWT secret..."
$jwtSecret = New-RandomString -Length 64
$jwtSecretJson = @{
    secret = $jwtSecret
} | ConvertTo-Json -Compress

Set-Secret `
    -SecretName "ecommerce/jwt-secret" `
    -SecretValue $jwtSecretJson `
    -Description "JWT signing secret for authentication service"

# 3. Encryption Key
Write-Info "Setting up application encryption key..."
$encryptionKey = New-RandomString -Length 32
$encryptionKeyJson = @{
    key = $encryptionKey
} | ConvertTo-Json -Compress

Set-Secret `
    -SecretName "ecommerce/encryption-key" `
    -SecretValue $encryptionKeyJson `
    -Description "Application-level encryption key"

# 4. Database Encryption Key
Write-Info "Setting up database encryption key..."
$dbEncryptionKey = New-RandomString -Length 32
$dbEncryptionKeyJson = @{
    key = $dbEncryptionKey
} | ConvertTo-Json -Compress

Set-Secret `
    -SecretName "ecommerce/db-encryption-key" `
    -SecretValue $dbEncryptionKeyJson `
    -Description "Database encryption key"

Write-Host ""
Write-Info "========================================="
Write-Info "All secrets created/updated successfully!"
Write-Info "========================================="
Write-Host ""

# Display secret ARNs
Write-Info "Secret ARNs:"
Write-Host ""

$secretNames = @(
    "ecommerce/onprem-mysql-password",
    "ecommerce/jwt-secret",
    "ecommerce/encryption-key",
    "ecommerce/db-encryption-key"
)

foreach ($secretName in $secretNames) {
    try {
        $secretArn = aws secretsmanager describe-secret `
            --secret-id $secretName `
            --region $Region `
            --query 'ARN' `
            --output text 2>$null
        Write-Host "  $secretName : $secretArn"
    } catch {
        Write-Host "  $secretName : Not found" -ForegroundColor Red
    }
}

Write-Host ""
Write-Info "You can retrieve secrets using:"
Write-Info "  aws secretsmanager get-secret-value --secret-id <secret-name> --region $Region"
Write-Host ""

# Test secret retrieval
Write-Info "Testing secret retrieval..."
try {
    $null = aws secretsmanager get-secret-value `
        --secret-id "ecommerce/onprem-mysql-password" `
        --region $Region `
        --query 'SecretString' `
        --output text 2>&1
    Write-Info "✓ Secrets are accessible"
} catch {
    Write-ErrorMsg "✗ Failed to retrieve secrets. Check IAM permissions."
    exit 1
}

Write-Host ""
Write-Info "Setup complete!"
