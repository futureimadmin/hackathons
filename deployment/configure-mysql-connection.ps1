#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Configure MySQL connection parameters in AWS SSM Parameter Store

.DESCRIPTION
    This script stores MySQL connection details and JWT secrets in AWS Systems Manager Parameter Store
    for both dev and prod environments.

.EXAMPLE
    .\configure-mysql-connection.ps1
#>

$PROJECT_NAME = "futureim-ecommerce-ai-platform"
$AWS_REGION = if ($env:AWS_DEFAULT_REGION) { $env:AWS_DEFAULT_REGION } else { "us-east-2" }

$COLOR_GREEN = "Green"
$COLOR_RED = "Red"
$COLOR_YELLOW = "Yellow"
$COLOR_CYAN = "Cyan"

function Write-ColorOutput {
    param([string]$Message, [string]$Color = "White")
    Write-Host $Message -ForegroundColor $Color
}

Write-ColorOutput @"
============================================================
   MySQL Connection & JWT Configuration
============================================================
"@ $COLOR_CYAN

# Check prerequisites
Write-ColorOutput "`nChecking prerequisites..." $COLOR_CYAN

try {
    aws --version | Out-Null
    Write-ColorOutput "[OK] AWS CLI installed" $COLOR_GREEN
} catch {
    Write-ColorOutput "[X] AWS CLI not found. Please install AWS CLI first." $COLOR_RED
    exit 1
}

try {
    $identity = aws sts get-caller-identity 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "Not authenticated"
    }
    Write-ColorOutput "[OK] AWS credentials configured" $COLOR_GREEN
} catch {
    Write-ColorOutput "[X] AWS credentials not configured. Run 'aws configure' first." $COLOR_RED
    exit 1
}

# Generate non-expiring JWT secret
Write-ColorOutput "`nGenerating JWT secrets..." $COLOR_CYAN

function Generate-JWTSecret {
    $bytes = New-Object byte[] 64  # 64 bytes = 512 bits for extra security
    $rng = [Security.Cryptography.RNGCryptoServiceProvider]::Create()
    $rng.GetBytes($bytes)
    return [Convert]::ToBase64String($bytes)
}

$devJwtSecret = Generate-JWTSecret
$prodJwtSecret = Generate-JWTSecret

Write-ColorOutput "[OK] JWT secrets generated (64-byte cryptographically random)" $COLOR_GREEN

# DEV Environment Configuration
Write-ColorOutput "`n============================================================" $COLOR_CYAN
Write-ColorOutput "   DEV Environment Configuration" $COLOR_CYAN
Write-ColorOutput "============================================================" $COLOR_CYAN

Write-ColorOutput "`nConfiguring DEV environment with local MySQL..." $COLOR_YELLOW

# Local MySQL credentials (for direct access)
$devMysqlHost = "172.20.10.4"
$devMysqlPort = "3306"
$devMysqlUser = "dms_remote"
$devMysqlPassword = "Srikar@123"
$devMysqlDatabase = "ecommerce"

# DMS Remote User (for AWS DMS replication)
$dmsMysqlUser = "dms_remote"
$dmsMysqlPassword = "SaiesaShanmukha@123"

Write-ColorOutput "`nDEV MySQL Configuration:" $COLOR_CYAN
Write-ColorOutput "  Host: $devMysqlHost" $COLOR_CYAN
Write-ColorOutput "  Port: $devMysqlPort" $COLOR_CYAN
Write-ColorOutput "  User: $devMysqlUser" $COLOR_CYAN
Write-ColorOutput "  Database: $devMysqlDatabase" $COLOR_CYAN
Write-ColorOutput "  Password: ********" $COLOR_CYAN
Write-ColorOutput "`nDMS User Configuration:" $COLOR_CYAN
Write-ColorOutput "  DMS User: $dmsMysqlUser" $COLOR_CYAN
Write-ColorOutput "  DMS Password: ********" $COLOR_CYAN

$confirm = Read-Host "`nProceed with DEV configuration? (yes/no)"
if ($confirm -ne "yes") {
    Write-ColorOutput "Configuration cancelled." $COLOR_YELLOW
    exit 0
}

Write-ColorOutput "`nStoring DEV parameters in SSM Parameter Store..." $COLOR_CYAN

try {
    # Standard MySQL connection parameters
    aws ssm put-parameter --name "/${PROJECT_NAME}/dev/mysql/host" --value $devMysqlHost --type String --overwrite --region $AWS_REGION | Out-Null
    aws ssm put-parameter --name "/${PROJECT_NAME}/dev/mysql/port" --value $devMysqlPort --type String --overwrite --region $AWS_REGION | Out-Null
    aws ssm put-parameter --name "/${PROJECT_NAME}/dev/mysql/user" --value $devMysqlUser --type String --overwrite --region $AWS_REGION | Out-Null
    aws ssm put-parameter --name "/${PROJECT_NAME}/dev/mysql/password" --value $devMysqlPassword --type SecureString --overwrite --region $AWS_REGION | Out-Null
    aws ssm put-parameter --name "/${PROJECT_NAME}/dev/mysql/database" --value $devMysqlDatabase --type String --overwrite --region $AWS_REGION | Out-Null
    
    # DMS-specific MySQL connection parameters
    aws ssm put-parameter --name "/${PROJECT_NAME}/dev/dms/mysql/user" --value $dmsMysqlUser --type String --overwrite --region $AWS_REGION | Out-Null
    aws ssm put-parameter --name "/${PROJECT_NAME}/dev/dms/mysql/password" --value $dmsMysqlPassword --type SecureString --overwrite --region $AWS_REGION | Out-Null
    
    # JWT secret
    aws ssm put-parameter --name "/${PROJECT_NAME}/dev/jwt/secret" --value $devJwtSecret --type SecureString --overwrite --region $AWS_REGION | Out-Null
    
    Write-ColorOutput "[OK] DEV parameters stored successfully" $COLOR_GREEN
    Write-ColorOutput "  - Standard MySQL credentials" $COLOR_GREEN
    Write-ColorOutput "  - DMS MySQL credentials" $COLOR_GREEN
    Write-ColorOutput "  - JWT secret" $COLOR_GREEN
} catch {
    Write-ColorOutput "[X] Failed to store DEV parameters: $_" $COLOR_RED
    exit 1
}

# PROD Environment Configuration
Write-ColorOutput "`n============================================================" $COLOR_CYAN
Write-ColorOutput "   PROD Environment Configuration" $COLOR_CYAN
Write-ColorOutput "============================================================" $COLOR_CYAN

Write-ColorOutput "`nFor PROD, you should use different MySQL credentials." $COLOR_YELLOW
Write-ColorOutput "Using the same local MySQL for PROD (not recommended for production)." $COLOR_YELLOW

$useSameForProd = Read-Host "`nUse same MySQL server for PROD? (yes/no)"

if ($useSameForProd -eq "yes") {
    $prodMysqlHost = $devMysqlHost
    $prodMysqlPort = $devMysqlPort
    $prodMysqlUser = $devMysqlUser
    $prodMysqlPassword = $devMysqlPassword
    $prodMysqlDatabase = $devMysqlDatabase
    $prodDmsMysqlUser = $dmsMysqlUser
    $prodDmsMysqlPassword = $dmsMysqlPassword
} else {
    Write-ColorOutput "`nEnter PROD MySQL configuration:" $COLOR_YELLOW
    $prodMysqlHost = Read-Host "MySQL Host"
    $prodMysqlPort = Read-Host "MySQL Port (default: 3306)"
    if ([string]::IsNullOrWhiteSpace($prodMysqlPort)) { $prodMysqlPort = "3306" }
    $prodMysqlUser = Read-Host "MySQL User"
    $prodMysqlPassword = Read-Host "MySQL Password" -AsSecureString
    $prodMysqlPasswordPlain = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($prodMysqlPassword))
    $prodMysqlDatabase = Read-Host "MySQL Database (default: ecommerce)"
    if ([string]::IsNullOrWhiteSpace($prodMysqlDatabase)) { $prodMysqlDatabase = "ecommerce" }
    $prodMysqlPassword = $prodMysqlPasswordPlain
    
    # DMS credentials for PROD
    $prodDmsMysqlUser = Read-Host "DMS MySQL User (default: dms_remote)"
    if ([string]::IsNullOrWhiteSpace($prodDmsMysqlUser)) { $prodDmsMysqlUser = "dms_remote" }
    $prodDmsMysqlPassword = Read-Host "DMS MySQL Password" -AsSecureString
    $prodDmsMysqlPasswordPlain = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($prodDmsMysqlPassword))
    $prodDmsMysqlPassword = $prodDmsMysqlPasswordPlain
}

Write-ColorOutput "`nStoring PROD parameters in SSM Parameter Store..." $COLOR_CYAN

try {
    # Standard MySQL connection parameters
    aws ssm put-parameter --name "/${PROJECT_NAME}/prod/mysql/host" --value $prodMysqlHost --type String --overwrite --region $AWS_REGION | Out-Null
    aws ssm put-parameter --name "/${PROJECT_NAME}/prod/mysql/port" --value $prodMysqlPort --type String --overwrite --region $AWS_REGION | Out-Null
    aws ssm put-parameter --name "/${PROJECT_NAME}/prod/mysql/user" --value $prodMysqlUser --type String --overwrite --region $AWS_REGION | Out-Null
    aws ssm put-parameter --name "/${PROJECT_NAME}/prod/mysql/password" --value $prodMysqlPassword --type SecureString --overwrite --region $AWS_REGION | Out-Null
    aws ssm put-parameter --name "/${PROJECT_NAME}/prod/mysql/database" --value $prodMysqlDatabase --type String --overwrite --region $AWS_REGION | Out-Null
    
    # DMS-specific MySQL connection parameters
    aws ssm put-parameter --name "/${PROJECT_NAME}/prod/dms/mysql/user" --value $prodDmsMysqlUser --type String --overwrite --region $AWS_REGION | Out-Null
    aws ssm put-parameter --name "/${PROJECT_NAME}/prod/dms/mysql/password" --value $prodDmsMysqlPassword --type SecureString --overwrite --region $AWS_REGION | Out-Null
    
    # JWT secret
    aws ssm put-parameter --name "/${PROJECT_NAME}/prod/jwt/secret" --value $prodJwtSecret --type SecureString --overwrite --region $AWS_REGION | Out-Null
    
    Write-ColorOutput "[OK] PROD parameters stored successfully" $COLOR_GREEN
    Write-ColorOutput "  - Standard MySQL credentials" $COLOR_GREEN
    Write-ColorOutput "  - DMS MySQL credentials" $COLOR_GREEN
    Write-ColorOutput "  - JWT secret" $COLOR_GREEN
} catch {
    Write-ColorOutput "[X] Failed to store PROD parameters: $_" $COLOR_RED
    exit 1
}

# Store JWT secrets locally for reference (optional)
Write-ColorOutput "`n============================================================" $COLOR_CYAN
Write-ColorOutput "   JWT Secrets (SAVE THESE SECURELY)" $COLOR_CYAN
Write-ColorOutput "============================================================" $COLOR_CYAN

$saveSecrets = Read-Host "`nSave JWT secrets to local file for backup? (yes/no)"
if ($saveSecrets -eq "yes") {
    $secretsFile = "deployment/.jwt-secrets-backup.txt"
    $secretsContent = @"
# JWT Secrets Backup
# Generated: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
# KEEP THIS FILE SECURE - DO NOT COMMIT TO GIT

DEV_JWT_SECRET=$devJwtSecret

PROD_JWT_SECRET=$prodJwtSecret

# These secrets are also stored in AWS SSM Parameter Store:
# /${PROJECT_NAME}/dev/jwt/secret
# /${PROJECT_NAME}/prod/jwt/secret
"@
    
    $secretsContent | Out-File -FilePath $secretsFile -Encoding UTF8
    Write-ColorOutput "[OK] JWT secrets saved to: $secretsFile" $COLOR_GREEN
    Write-ColorOutput "[!] IMPORTANT: Keep this file secure and do not commit to Git!" $COLOR_YELLOW
}

# Test MySQL Connection
Write-ColorOutput "`n============================================================" $COLOR_CYAN
Write-ColorOutput "   Connection Test" $COLOR_CYAN
Write-ColorOutput "============================================================" $COLOR_CYAN

$testConnection = Read-Host "`nTest MySQL connection? (requires mysql client) (yes/no)"
if ($testConnection -eq "yes") {
    Write-ColorOutput "`nTesting connection to $devMysqlHost..." $COLOR_CYAN
    
    try {
        $testCmd = "mysql -h $devMysqlHost -P $devMysqlPort -u $devMysqlUser -p'$devMysqlPassword' -e 'SELECT VERSION();'"
        $result = Invoke-Expression $testCmd 2>&1
        
        if ($LASTEXITCODE -eq 0) {
            Write-ColorOutput "[OK] MySQL connection successful!" $COLOR_GREEN
            Write-ColorOutput $result $COLOR_CYAN
        } else {
            Write-ColorOutput "[X] MySQL connection failed" $COLOR_RED
            Write-ColorOutput $result $COLOR_RED
        }
    } catch {
        Write-ColorOutput "[X] MySQL client not found or connection failed: $_" $COLOR_YELLOW
        Write-ColorOutput "You can test manually with: mysql -h $devMysqlHost -u $devMysqlUser -p" $COLOR_YELLOW
    }
}

# Summary
Write-ColorOutput "`n============================================================" $COLOR_GREEN
Write-ColorOutput "   Configuration Complete!" $COLOR_GREEN
Write-ColorOutput "============================================================" $COLOR_GREEN

Write-ColorOutput "`nStored Parameters:" $COLOR_CYAN
Write-ColorOutput "  DEV:" $COLOR_CYAN
Write-ColorOutput "    /${PROJECT_NAME}/dev/mysql/host" $COLOR_CYAN
Write-ColorOutput "    /${PROJECT_NAME}/dev/mysql/port" $COLOR_CYAN
Write-ColorOutput "    /${PROJECT_NAME}/dev/mysql/user" $COLOR_CYAN
Write-ColorOutput "    /${PROJECT_NAME}/dev/mysql/password (encrypted)" $COLOR_CYAN
Write-ColorOutput "    /${PROJECT_NAME}/dev/mysql/database" $COLOR_CYAN
Write-ColorOutput "    /${PROJECT_NAME}/dev/jwt/secret (encrypted)" $COLOR_CYAN

Write-ColorOutput "`n  PROD:" $COLOR_CYAN
Write-ColorOutput "    /${PROJECT_NAME}/prod/mysql/host" $COLOR_CYAN
Write-ColorOutput "    /${PROJECT_NAME}/prod/mysql/port" $COLOR_CYAN
Write-ColorOutput "    /${PROJECT_NAME}/prod/mysql/user" $COLOR_CYAN
Write-ColorOutput "    /${PROJECT_NAME}/prod/mysql/password (encrypted)" $COLOR_CYAN
Write-ColorOutput "    /${PROJECT_NAME}/prod/mysql/database" $COLOR_CYAN
Write-ColorOutput "    /${PROJECT_NAME}/prod/jwt/secret (encrypted)" $COLOR_CYAN

Write-ColorOutput "`nNext Steps:" $COLOR_YELLOW
Write-ColorOutput "1. Ensure network connectivity from AWS to MySQL server (VPN/Direct Connect)" $COLOR_YELLOW
Write-ColorOutput "2. Review deployment/mysql-connection-setup.md for network setup" $COLOR_YELLOW
Write-ColorOutput "3. Run Terraform to create infrastructure: cd terraform && terraform init && terraform plan" $COLOR_YELLOW
Write-ColorOutput "4. JWT tokens will be generated with NO EXPIRATION (as requested)" $COLOR_YELLOW

exit 0
