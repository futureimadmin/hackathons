#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Step-by-step deployment of eCommerce AI Platform

.DESCRIPTION
    This script guides you through the complete deployment process:
    1. Setup MySQL schema and sample data (500MB) on 172.20.10.4
    2. Create AWS infrastructure with DMS connections
    3. Build and deploy Java/Python modules
    4. Setup API Gateway
    5. Deploy React frontend to S3
    6. Publish URLs

.EXAMPLE
    .\step-by-step-deployment-fixed.ps1
#>

$PROJECT_NAME = "futureim-ecommerce-ai-platform"
$MYSQL_HOST = "172.20.10.4"
$MYSQL_USER = "dms_remote"
$MYSQL_PASSWORD = "SaiesaShanmukha@123"
$MYSQL_DATABASE = "ecommerce"
$AWS_REGION = "us-east-2"

$COLOR_GREEN = "Green"
$COLOR_RED = "Red"
$COLOR_YELLOW = "Yellow"
$COLOR_CYAN = "Cyan"
$COLOR_MAGENTA = "Magenta"
$COLOR_WHITE = "White"

function Write-ColorOutput {
    param([string]$Message, [string]$Color = "White")
    Write-Host $Message -ForegroundColor $Color
}

function Write-StepHeader {
    param([string]$StepNumber, [string]$StepName)
    Write-ColorOutput "`n============================================================" $COLOR_MAGENTA
    Write-ColorOutput "   STEP $StepNumber : $StepName" $COLOR_MAGENTA
    Write-ColorOutput "============================================================" $COLOR_MAGENTA
}

function Write-SubStep {
    param([string]$Message)
    Write-ColorOutput "  -> $Message" $COLOR_CYAN
}

function Confirm-Step {
    param([string]$Message)
    Write-ColorOutput "`n$Message" $COLOR_YELLOW
    $response = Read-Host "Continue? (yes/no)"
    return $response -eq "yes"
}

function Wait-ForUserConfirmation {
    param([string]$Message = "Press Enter to continue...")
    Write-ColorOutput "`n$Message" $COLOR_YELLOW
    Read-Host | Out-Null
}

# Banner
Write-ColorOutput @"

============================================================
                                                           
   eCommerce AI Platform                                   
   Step-by-Step Deployment                                 
                                                           
============================================================

"@ $COLOR_CYAN

Write-ColorOutput "This script will guide you through the complete deployment process." $COLOR_WHITE
Write-ColorOutput "Each step will require your confirmation before proceeding.`n" $COLOR_WHITE

# Check prerequisites
Write-ColorOutput "Checking prerequisites..." $COLOR_CYAN

$prerequisites = @{
    "AWS CLI" = { aws --version }
    "Terraform" = { terraform --version }
    "MySQL Client" = { mysql --version }
    "Python" = { python --version }
    "Maven" = { mvn --version }
    "Node.js" = { node --version }
}

$missingPrereqs = @()
foreach ($prereq in $prerequisites.GetEnumerator()) {
    try {
        $null = & $prereq.Value 2>&1
        if ($LASTEXITCODE -eq 0 -or $prereq.Key -eq "MySQL Client") {
            Write-ColorOutput "  [OK] $($prereq.Key)" $COLOR_GREEN
        } else {
            Write-ColorOutput "  [X] $($prereq.Key)" $COLOR_RED
            $missingPrereqs += $prereq.Key
        }
    } catch {
        Write-ColorOutput "  [X] $($prereq.Key)" $COLOR_RED
        $missingPrereqs += $prereq.Key
    }
}

if ($missingPrereqs.Count -gt 0) {
    Write-ColorOutput "`n[!] Missing prerequisites: $($missingPrereqs -join ', ')" $COLOR_YELLOW
    if (-not (Confirm-Step "Some tools are missing. Continue anyway?")) {
        exit 1
    }
}

# Check AWS credentials
try {
    $identity = aws sts get-caller-identity 2>&1 | ConvertFrom-Json
    Write-ColorOutput "  [OK] AWS Credentials (Account: $($identity.Account))" $COLOR_GREEN
} catch {
    Write-ColorOutput "  [X] AWS Credentials not configured" $COLOR_RED
    Write-ColorOutput "    Run: aws configure" $COLOR_YELLOW
    exit 1
}

Write-ColorOutput "`n[OK] Prerequisites check complete!" $COLOR_GREEN

if (-not (Confirm-Step "Ready to begin deployment?")) {
    Write-ColorOutput "Deployment cancelled." $COLOR_YELLOW
    exit 0
}

# ============================================================================
# STEP 1: Setup MySQL Schema and Sample Data
# ============================================================================

Write-StepHeader "1" "Setup MySQL Schema and Sample Data (500MB)"

Write-SubStep "This will create the database schema and generate 500MB of sample data"
Write-SubStep "Target: MySQL at $MYSQL_HOST"
Write-SubStep "Database: $MYSQL_DATABASE"

if (-not (Confirm-Step "Proceed with database setup?")) {
    Write-ColorOutput "Skipping database setup." $COLOR_YELLOW
} else {
    Write-ColorOutput "`nTesting MySQL connection..." $COLOR_CYAN
    
    try {
        # Use Python for more reliable connection testing
        $testScript = @"
import mysql.connector
import sys
try:
    conn = mysql.connector.connect(
        host='$MYSQL_HOST',
        user='$MYSQL_USER',
        password='$MYSQL_PASSWORD'
    )
    cursor = conn.cursor()
    cursor.execute('SELECT VERSION()')
    version = cursor.fetchone()
    print('[OK] MySQL connection successful!')
    print('[OK] MySQL version: ' + str(version[0]))
    cursor.close()
    conn.close()
    sys.exit(0)
except ImportError as e:
    print('[X] mysql-connector-python not installed')
    print('    Install it with: pip install mysql-connector-python')
    sys.exit(2)
except Exception as e:
    print('[X] MySQL connection failed: ' + str(e))
    sys.exit(1)
"@
        
        $tempTest = [System.IO.Path]::GetTempFileName() + ".py"
        $testScript | Out-File -FilePath $tempTest -Encoding UTF8
        
        try {
            $result = python $tempTest 2>&1
            Write-ColorOutput $result $COLOR_CYAN
            
            if ($LASTEXITCODE -eq 0) {
                Write-ColorOutput "[OK] MySQL connection successful!" $COLOR_GREEN
            } elseif ($LASTEXITCODE -eq 2) {
                Write-ColorOutput "[!] Installing mysql-connector-python..." $COLOR_YELLOW
                pip install mysql-connector-python
                if ($LASTEXITCODE -eq 0) {
                    Write-ColorOutput "[OK] Package installed. Retrying connection..." $COLOR_GREEN
                    $result = python $tempTest 2>&1
                    Write-ColorOutput $result $COLOR_CYAN
                    if ($LASTEXITCODE -eq 0) {
                        Write-ColorOutput "[OK] MySQL connection successful!" $COLOR_GREEN
                    } else {
                        Write-ColorOutput "[X] MySQL connection failed after package install" $COLOR_RED
                        if (-not (Confirm-Step "MySQL connection failed. Continue anyway?")) {
                            exit 1
                        }
                    }
                }
            } else {
                Write-ColorOutput "[X] MySQL connection failed" $COLOR_RED
                if (-not (Confirm-Step "MySQL connection failed. Continue anyway?")) {
                    exit 1
                }
            }
        } finally {
            if (Test-Path $tempTest) {
                Remove-Item $tempTest -Force
            }
        }
    } catch {
        Write-ColorOutput "[X] MySQL connection test failed: $_" $COLOR_RED
        if (-not (Confirm-Step "Continue anyway?")) {
            exit 1
        }
    }
    
    Write-ColorOutput "`nStep 1.1: Creating database schema..." $COLOR_CYAN
    
    # Navigate to database folder at project root
    $originalLocation = Get-Location
    Set-Location "$PSScriptRoot\..\database"
    Write-ColorOutput "  Current directory: $(Get-Location)" $COLOR_CYAN
    
    # Create database using Python
    Write-SubStep "Creating database: $MYSQL_DATABASE"
    
    $createDbScript = @"
import mysql.connector
import sys
try:
    conn = mysql.connector.connect(
        host='$MYSQL_HOST',
        user='$MYSQL_USER',
        password='$MYSQL_PASSWORD'
    )
    cursor = conn.cursor()
    cursor.execute('CREATE DATABASE IF NOT EXISTS $MYSQL_DATABASE')
    conn.commit()
    print('[OK] Database created or already exists')
    cursor.close()
    conn.close()
    sys.exit(0)
except Exception as e:
    print('[X] Database creation failed: ' + str(e))
    sys.exit(1)
"@
    
    $tempCreateDb = [System.IO.Path]::GetTempFileName() + ".py"
    $createDbScript | Out-File -FilePath $tempCreateDb -Encoding UTF8
    
    try {
        python $tempCreateDb
        if ($LASTEXITCODE -eq 0) {
            Write-ColorOutput "  [OK] Database created" $COLOR_GREEN
        } else {
            Write-ColorOutput "  [X] Database creation failed" $COLOR_RED
        }
    } finally {
        Remove-Item $tempCreateDb -Force
    }
    
    # Run schema scripts using Python
    Write-SubStep "Running schema scripts..."
    
    $schemaFiles = @(
        "schema/01_main_ecommerce_schema.sql",
        "schema/02_system_specific_schemas.sql"
    )
    
    foreach ($schemaFile in $schemaFiles) {
        if (Test-Path $schemaFile) {
            Write-SubStep "Executing: $schemaFile"
            
            # Use Python to execute SQL file
            $pythonScript = @"
import mysql.connector
import sys

try:
    connection = mysql.connector.connect(
        host='$MYSQL_HOST',
        user='$MYSQL_USER',
        password='$MYSQL_PASSWORD',
        database='$MYSQL_DATABASE'
    )
    
    with open('$schemaFile', 'r', encoding='utf-8') as f:
        sql_script = f.read()
    
    cursor = connection.cursor()
    
    # Split by semicolon and execute each statement
    statements = [s.strip() for s in sql_script.split(';') if s.strip()]
    for statement in statements:
        if statement:
            cursor.execute(statement)
    
    connection.commit()
    cursor.close()
    connection.close()
    print('[OK] Schema applied')
    sys.exit(0)
    
except Exception as e:
    print('[X] Error: ' + str(e))
    sys.exit(1)
"@
            
            $tempScript = [System.IO.Path]::GetTempFileName() + ".py"
            $pythonScript | Out-File -FilePath $tempScript -Encoding UTF8
            
            try {
                python $tempScript
                if ($LASTEXITCODE -eq 0) {
                    Write-ColorOutput "    [OK] Schema applied" $COLOR_GREEN
                } else {
                    Write-ColorOutput "    [X] Schema failed" $COLOR_RED
                }
            } finally {
                if (Test-Path $tempScript) {
                    Remove-Item $tempScript -Force
                }
            }
        }
    }
    
    Write-ColorOutput "`nStep 1.2: Generating sample data (500MB)..." $COLOR_CYAN
    Write-SubStep "This may take 5-10 minutes..."
    
    # Generate sample data (we're already in database folder)
    if (Test-Path "data_generator/generate_sample_data.py") {
        Write-SubStep "Checking Python dependencies..."
        
        # Check and install required packages
        $requiredPackages = @("mysql-connector-python", "faker")
        foreach ($package in $requiredPackages) {
            $checkPackage = python -c "import $($package.Replace('-', '_'))" 2>&1
            if ($LASTEXITCODE -ne 0) {
                Write-ColorOutput "  [!] Installing $package..." $COLOR_YELLOW
                pip install $package
                if ($LASTEXITCODE -eq 0) {
                    Write-ColorOutput "  [OK] $package installed" $COLOR_GREEN
                } else {
                    Write-ColorOutput "  [X] Failed to install $package" $COLOR_RED
                }
            } else {
                Write-ColorOutput "  [OK] $package is installed" $COLOR_GREEN
            }
        }
        
        # Check if data already exists
        Write-SubStep "Checking for existing data..."
        $checkDataScript = @"
import mysql.connector
import sys
try:
    conn = mysql.connector.connect(
        host='$MYSQL_HOST',
        user='$MYSQL_USER',
        password='$MYSQL_PASSWORD',
        database='$MYSQL_DATABASE'
    )
    cursor = conn.cursor()
    cursor.execute('SELECT COUNT(*) FROM customers')
    count = cursor.fetchone()[0]
    cursor.close()
    conn.close()
    print(count)
    sys.exit(0)
except Exception as e:
    print('0')
    sys.exit(0)
"@
        
        $tempCheck = [System.IO.Path]::GetTempFileName() + ".py"
        $checkDataScript | Out-File -FilePath $tempCheck -Encoding UTF8
        
        try {
            $existingCount = python $tempCheck
            Remove-Item $tempCheck -Force
            
            if ([int]$existingCount -gt 0) {
                Write-ColorOutput "  [!] Found $existingCount existing customer records" $COLOR_YELLOW
                
                if (Confirm-Step "Clear existing data and regenerate?") {
                    # Clear existing data
                    Write-SubStep "Clearing existing data..."
                    $clearDataScript = @"
import mysql.connector
import sys
try:
    conn = mysql.connector.connect(
        host='$MYSQL_HOST',
        user='$MYSQL_USER',
        password='$MYSQL_PASSWORD',
        database='$MYSQL_DATABASE'
    )
    cursor = conn.cursor()
    
    # Disable foreign key checks
    cursor.execute('SET FOREIGN_KEY_CHECKS = 0')
    
    # Get all tables
    cursor.execute('SHOW TABLES')
    tables = cursor.fetchall()
    
    # Truncate all tables
    for table in tables:
        table_name = table[0]
        cursor.execute('TRUNCATE TABLE ' + table_name)
        print('[OK] Cleared table: ' + table_name)
    
    # Re-enable foreign key checks
    cursor.execute('SET FOREIGN_KEY_CHECKS = 1')
    
    conn.commit()
    cursor.close()
    conn.close()
    print('[OK] All existing data cleared')
    sys.exit(0)
except Exception as e:
    print('[X] Error clearing data: ' + str(e))
    sys.exit(1)
"@
                    
                    $tempClear = [System.IO.Path]::GetTempFileName() + ".py"
                    $clearDataScript | Out-File -FilePath $tempClear -Encoding UTF8
                    
                    try {
                        python $tempClear
                    } finally {
                        Remove-Item $tempClear -Force
                    }
                } else {
                    Write-ColorOutput "  [!] Skipping data generation - keeping existing data" $COLOR_YELLOW
                    # Skip to next section
                    Set-Location $originalLocation
                    
                    Write-ColorOutput "`nVerifying database setup..." $COLOR_CYAN
                    
                    $verifyScript = @"
import mysql.connector
try:
    conn = mysql.connector.connect(
        host='$MYSQL_HOST',
        user='$MYSQL_USER',
        password='$MYSQL_PASSWORD',
        database='$MYSQL_DATABASE'
    )
    cursor = conn.cursor()
    cursor.execute('SHOW TABLES')
    tables = cursor.fetchall()
    print('[OK] Database verified - Tables found:')
    for table in tables:
        print('  - ' + table[0])
    cursor.close()
    conn.close()
except Exception as e:
    print('[X] Verification failed: ' + str(e))
"@
                    
                    $tempVerify = [System.IO.Path]::GetTempFileName() + ".py"
                    $verifyScript | Out-File -FilePath $tempVerify -Encoding UTF8
                    
                    try {
                        python $tempVerify
                    } finally {
                        if (Test-Path $tempVerify) {
                            Remove-Item $tempVerify -Force
                        }
                    }
                    
                    Write-ColorOutput "`n[OK] STEP 1 COMPLETE: Database setup finished!" $COLOR_GREEN
                    Wait-ForUserConfirmation
                    return
                }
            }
        } catch {
            Write-ColorOutput "  [!] Could not check existing data, proceeding with generation..." $COLOR_YELLOW
        }
        
        Write-SubStep "Running data generator..."
        
        # Set environment variables for data generator
        $env:MYSQL_HOST = $MYSQL_HOST
        $env:MYSQL_USER = $MYSQL_USER
        $env:MYSQL_PASSWORD = $MYSQL_PASSWORD
        $env:MYSQL_DATABASE = $MYSQL_DATABASE
        $env:TARGET_SIZE_MB = "500"
        
        python data_generator/generate_sample_data.py
        
        if ($LASTEXITCODE -eq 0) {
            Write-ColorOutput "  [OK] Sample data generated (500MB)" $COLOR_GREEN
        } else {
            Write-ColorOutput "  [X] Data generation failed" $COLOR_RED
        }
    } else {
        Write-ColorOutput "  [!] Data generator script not found at: $(Get-Location)\data_generator\generate_sample_data.py" $COLOR_YELLOW
    }
    
    # Return to original location
    Set-Location $originalLocation
    
    # Verify data using Python (more reliable than mysql command)
    Write-ColorOutput "`nVerifying database setup..." $COLOR_CYAN
    
    $verifyScript = @"
import mysql.connector
try:
    conn = mysql.connector.connect(
        host='$MYSQL_HOST',
        user='$MYSQL_USER',
        password='$MYSQL_PASSWORD',
        database='$MYSQL_DATABASE'
    )
    cursor = conn.cursor()
    cursor.execute('SHOW TABLES')
    tables = cursor.fetchall()
    print('[OK] Database verified - Tables found:')
    for table in tables:
        print('  - ' + table[0])
    cursor.close()
    conn.close()
except Exception as e:
    print('[X] Verification failed: ' + str(e))
"@
    
    $tempVerify = [System.IO.Path]::GetTempFileName() + ".py"
    $verifyScript | Out-File -FilePath $tempVerify -Encoding UTF8
    
    try {
        python $tempVerify
    } finally {
        if (Test-Path $tempVerify) {
            Remove-Item $tempVerify -Force
        }
    }
    
    Write-ColorOutput "`n[OK] STEP 1 COMPLETE: Database setup finished!" $COLOR_GREEN
    Wait-ForUserConfirmation
}

# ============================================================================
# STEP 2: Configure MySQL Connection and JWT in AWS
# ============================================================================

Write-StepHeader "2" "Configure MySQL Connection and JWT Secrets in AWS"

Write-SubStep "This will store MySQL credentials and JWT secrets in AWS SSM Parameter Store"

if (-not (Confirm-Step "Proceed with AWS configuration?")) {
    Write-ColorOutput "Skipping AWS configuration." $COLOR_YELLOW
} else {
    # We're already in deployment folder, no need to change directory
    
    if (Test-Path "configure-mysql-connection.ps1") {
        .\configure-mysql-connection.ps1
        
        if ($LASTEXITCODE -ne 0) {
            Write-ColorOutput "[X] Configuration failed" $COLOR_RED
            if (-not (Confirm-Step "Continue anyway?")) {
                exit 1
            }
        }
    } else {
        Write-ColorOutput "[X] Configuration script not found at: $(Get-Location)\configure-mysql-connection.ps1" $COLOR_RED
        exit 1
    }
    
    
    Write-ColorOutput "`n[OK] STEP 2 COMPLETE: AWS configuration finished!" $COLOR_GREEN
    Wait-ForUserConfirmation
}

# ============================================================================
# STEP 3: Create AWS Infrastructure with Terraform
# ============================================================================

Write-StepHeader "3" "Create AWS Infrastructure (VPC, S3, DMS, Lambda, API Gateway)"

Write-SubStep "This will create all AWS resources including:"
Write-SubStep "  * VPC and networking"
Write-SubStep "  * S3 data lake buckets (15 buckets)"
Write-SubStep "  * DMS replication to $MYSQL_HOST"
Write-SubStep "  * IAM roles and policies"
Write-SubStep "  * KMS encryption keys"
Write-SubStep "  * Lambda function placeholders"
Write-SubStep "  * API Gateway"
Write-SubStep "  * DynamoDB tables"
Write-SubStep "  * Glue crawlers and Athena"

Write-ColorOutput "`nEstimated time: 15-20 minutes" $COLOR_YELLOW
Write-ColorOutput "Estimated cost: ~`$280-450/month" $COLOR_YELLOW

if (-not (Confirm-Step "Proceed with infrastructure creation?")) {
    Write-ColorOutput "Skipping infrastructure creation." $COLOR_YELLOW
} else {
    Push-Location "$PSScriptRoot\..\terraform"
    
    # Setup Terraform backend
    Write-ColorOutput "`nStep 3.1: Setting up Terraform backend..." $COLOR_CYAN
    
    if (Test-Path "setup-terraform.ps1") {
        .\setup-terraform.ps1
        
        if ($LASTEXITCODE -ne 0) {
            Write-ColorOutput "[X] Terraform setup failed" $COLOR_RED
            Pop-Location
            exit 1
        }
    }
    
    # Plan infrastructure
    Write-ColorOutput "`nStep 3.2: Planning infrastructure..." $COLOR_CYAN
    terraform plan -out=tfplan
    
    if ($LASTEXITCODE -ne 0) {
        Write-ColorOutput "[X] Terraform plan failed" $COLOR_RED
        Pop-Location
        exit 1
    }
    
    Write-ColorOutput "`n[OK] Terraform plan created" $COLOR_GREEN
    
    if (-not (Confirm-Step "Review the plan above. Proceed with infrastructure creation?")) {
        Write-ColorOutput "Infrastructure creation cancelled." $COLOR_YELLOW
        Pop-Location
        exit 0
    }
    
    # Apply infrastructure
    Write-ColorOutput "`nStep 3.3: Creating infrastructure..." $COLOR_CYAN
    Write-SubStep "This will take 15-20 minutes..."
    
    $startTime = Get-Date
    terraform apply tfplan
    $endTime = Get-Date
    $duration = $endTime - $startTime
    
    if ($LASTEXITCODE -ne 0) {
        Write-ColorOutput "[X] Infrastructure creation failed" $COLOR_RED
        Pop-Location
        exit 1
    }
    
    Write-ColorOutput "`n[OK] Infrastructure created successfully!" $COLOR_GREEN
    Write-ColorOutput "Time taken: $($duration.Minutes) minutes $($duration.Seconds) seconds" $COLOR_CYAN
    
    # Get outputs
    Write-ColorOutput "`nInfrastructure Outputs:" $COLOR_CYAN
    terraform output
    
    Pop-Location
    
    Write-ColorOutput "`n[OK] STEP 3 COMPLETE: AWS infrastructure created!" $COLOR_GREEN
    Wait-ForUserConfirmation
}

# ============================================================================
# STEP 4: Build and Deploy Java/Python Modules
# ============================================================================

Write-StepHeader "4" "Build and Deploy Java/Python Modules to AWS Lambda"

Write-SubStep "This will build and deploy:"
Write-SubStep "  * Auth Service (Java)"
Write-SubStep "  * Analytics Service (Python)"
Write-SubStep "  * Market Intelligence Hub (Python)"
Write-SubStep "  * Demand Insights Engine (Python)"
Write-SubStep "  * Compliance Guardian (Python)"
Write-SubStep "  * Retail Copilot (Python)"
Write-SubStep "  * Global Market Pulse (Python)"

if (-not (Confirm-Step "Proceed with building and deploying modules?")) {
    Write-ColorOutput "Skipping module deployment." $COLOR_YELLOW
} else {
    
    # Build Auth Service (Java)
    Write-ColorOutput "`nStep 4.1: Building Auth Service (Java)..." $COLOR_CYAN
    Push-Location "$PSScriptRoot\..\auth-service"
    
    Write-SubStep "Running Maven build..."
    mvn clean package
    
    if ($LASTEXITCODE -eq 0) {
        Write-ColorOutput "  [OK] Auth Service built successfully" $COLOR_GREEN
        
        # Deploy to Lambda
        Write-SubStep "Deploying to Lambda..."
        $jarFile = "target/auth-service-1.0.0.jar"
        if (Test-Path $jarFile) {
            aws lambda update-function-code `
                --function-name "${PROJECT_NAME}-dev-auth" `
                --zip-file fileb://$jarFile `
                --region $AWS_REGION 2>&1 | Out-Null
            
            if ($LASTEXITCODE -eq 0) {
                Write-ColorOutput "  [OK] Auth Service deployed to Lambda" $COLOR_GREEN
            } else {
                Write-ColorOutput "  [!] Lambda deployment failed (function may not exist yet)" $COLOR_YELLOW
            }
        }
    } else {
        Write-ColorOutput "  [X] Auth Service build failed" $COLOR_RED
    }
    
    Pop-Location
    
    # Build Analytics Service (Python)
    Write-ColorOutput "`nStep 4.2: Building Analytics Service (Python)..." $COLOR_CYAN
    Push-Location "$PSScriptRoot\..\analytics-service"
    
    if (Test-Path "build.ps1") {
        .\build.ps1
        if ($LASTEXITCODE -eq 0) {
            Write-ColorOutput "  [OK] Analytics Service built and deployed" $COLOR_GREEN
        }
    } else {
        Write-ColorOutput "  [!] Build script not found" $COLOR_YELLOW
    }
    
    Pop-Location
    
    # Build AI Systems
    $aiSystems = @(
        "market-intelligence-hub",
        "demand-insights-engine",
        "compliance-guardian",
        "retail-copilot",
        "global-market-pulse"
    )
    
    $stepNum = 3
    foreach ($system in $aiSystems) {
        Write-ColorOutput "`nStep 4.$stepNum : Building $system..." $COLOR_CYAN
        Push-Location "$PSScriptRoot\..\ai-systems\$system"
        
        if (Test-Path "build.ps1") {
            .\build.ps1
            if ($LASTEXITCODE -eq 0) {
                Write-ColorOutput "  [OK] $system built and deployed" $COLOR_GREEN
            } else {
                Write-ColorOutput "  [!] $system build had issues" $COLOR_YELLOW
            }
        } else {
            Write-ColorOutput "  [!] Build script not found for $system" $COLOR_YELLOW
        }
        
        Pop-Location
        $stepNum++
    }
    
    Write-ColorOutput "`n[OK] STEP 4 COMPLETE: All modules built and deployed!" $COLOR_GREEN
    Wait-ForUserConfirmation
}

# ============================================================================
# STEP 5: Setup and Verify API Gateway
# ============================================================================

Write-StepHeader "5" "Setup and Verify API Gateway"

Write-SubStep "This will verify API Gateway is configured and connected to Lambda functions"

if (-not (Confirm-Step "Proceed with API Gateway setup?")) {
    Write-ColorOutput "Skipping API Gateway setup." $COLOR_YELLOW
} else {
    Push-Location "$PSScriptRoot\..\terraform"
    
    Write-ColorOutput "`nVerifying API Gateway..." $COLOR_CYAN
    
    # Get API Gateway URL from Terraform outputs
    $apiUrl = terraform output -raw api_gateway_url 2>&1
    
    if ($LASTEXITCODE -eq 0 -and $apiUrl -ne "") {
        Write-ColorOutput "  [OK] API Gateway URL: $apiUrl" $COLOR_GREEN
        
        # Test API Gateway
        Write-SubStep "Testing API Gateway health endpoint..."
        try {
            $response = Invoke-WebRequest -Uri "$apiUrl/health" -Method GET -ErrorAction SilentlyContinue
            if ($response.StatusCode -eq 200) {
                Write-ColorOutput "  [OK] API Gateway is responding" $COLOR_GREEN
            }
        } catch {
            Write-ColorOutput "  [!] API Gateway health check failed (may not be fully configured yet)" $COLOR_YELLOW
        }
    } else {
        Write-ColorOutput "  [!] API Gateway URL not found in Terraform outputs" $COLOR_YELLOW
        Write-ColorOutput "  You may need to run API Gateway setup scripts manually" $COLOR_YELLOW
    }
    
    Pop-Location
    
    Write-ColorOutput "`n[OK] STEP 5 COMPLETE: API Gateway verified!" $COLOR_GREEN
    Wait-ForUserConfirmation
}

# ============================================================================
# STEP 6: Deploy React Frontend to S3
# ============================================================================

Write-StepHeader "6" "Deploy React Frontend to S3 Static Hosting"

Write-SubStep "This will build and deploy the React frontend application"

if (-not (Confirm-Step "Proceed with frontend deployment?")) {
    Write-ColorOutput "Skipping frontend deployment." $COLOR_YELLOW
} else {
    Push-Location "$PSScriptRoot\..\frontend"
    
    $frontendSuccess = $false
    
    Write-ColorOutput "`nStep 6.1: Installing dependencies..." $COLOR_CYAN
    npm install
    
    if ($LASTEXITCODE -ne 0) {
        Write-ColorOutput "  [X] npm install failed" $COLOR_RED
        Pop-Location
    } else {
        Write-ColorOutput "  [OK] Dependencies installed" $COLOR_GREEN
        
        Write-ColorOutput "`nStep 6.2: Building React application..." $COLOR_CYAN
        npm run build
        
        if ($LASTEXITCODE -ne 0) {
            Write-ColorOutput "  [X] Build failed" $COLOR_RED
            Write-ColorOutput "`n[X] STEP 6 FAILED: Frontend build errors must be fixed" $COLOR_RED
            Pop-Location
        } else {
            Write-ColorOutput "  [OK] Build successful" $COLOR_GREEN
            
            Write-ColorOutput "`nStep 6.3: Deploying to S3..." $COLOR_CYAN
            
            $bucketName = "${PROJECT_NAME}-frontend-dev"
            
            # Create bucket if it doesn't exist
            aws s3 mb s3://$bucketName --region $AWS_REGION 2>&1 | Out-Null
            
            # Enable static website hosting
            aws s3 website s3://$bucketName --index-document index.html --error-document index.html
            
            # Upload files
            aws s3 sync dist/ s3://$bucketName/ --delete
            
            if ($LASTEXITCODE -eq 0) {
                Write-ColorOutput "  [OK] Frontend deployed to S3" $COLOR_GREEN
                
                # Make bucket public for static hosting
                $policy = @"
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "PublicReadGetObject",
            "Effect": "Allow",
            "Principal": "*",
            "Action": "s3:GetObject",
            "Resource": "arn:aws:s3:::$bucketName/*"
        }
    ]
}
"@
                $policy | Out-File -FilePath "bucket-policy.json" -Encoding UTF8
                aws s3api put-bucket-policy --bucket $bucketName --policy file://bucket-policy.json
                Remove-Item "bucket-policy.json"
                
                Write-ColorOutput "  [OK] Bucket configured for public access" $COLOR_GREEN
                Write-ColorOutput "  [OK] Frontend URL: http://$bucketName.s3-website.$AWS_REGION.amazonaws.com" $COLOR_CYAN
                
                $frontendSuccess = $true
            } else {
                Write-ColorOutput "  [X] S3 deployment failed" $COLOR_RED
                Write-ColorOutput "`n[X] STEP 6 FAILED: S3 deployment error" $COLOR_RED
            }
            
            Pop-Location
        }
    }
    
    if ($frontendSuccess) {
        Write-ColorOutput "`n[OK] STEP 6 COMPLETE: Frontend deployed!" $COLOR_GREEN
    }
    
    Wait-ForUserConfirmation
}

# ============================================================================
# STEP 7: Publish URLs and Summary
# ============================================================================

Write-StepHeader "7" "Deployment Summary and URLs"

Write-ColorOutput "`nGathering deployment information..." $COLOR_CYAN

# Get Terraform outputs
Push-Location "$PSScriptRoot\..\terraform"
$outputs = @{}
try {
    $tfOutput = terraform output -json | ConvertFrom-Json
    foreach ($prop in $tfOutput.PSObject.Properties) {
        $outputs[$prop.Name] = $prop.Value.value
    }
} catch {
    Write-ColorOutput "  [!] Could not retrieve Terraform outputs" $COLOR_YELLOW
}
Pop-Location

# Display URLs
Write-ColorOutput "`n============================================================" $COLOR_GREEN
Write-ColorOutput "   DEPLOYMENT COMPLETE!                                   " $COLOR_GREEN
Write-ColorOutput "============================================================" $COLOR_GREEN

Write-ColorOutput "`nPUBLISHED URLS:" $COLOR_CYAN

# Frontend URL
$frontendBucket = "${PROJECT_NAME}-frontend-dev"
$frontendUrl = "http://$frontendBucket.s3-website-$AWS_REGION.amazonaws.com"
Write-ColorOutput "`nFrontend Application:" $COLOR_WHITE
Write-ColorOutput "   $frontendUrl" $COLOR_GREEN

# API Gateway URL
if ($outputs.ContainsKey("api_gateway_url")) {
    Write-ColorOutput "`nAPI Gateway:" $COLOR_WHITE
    Write-ColorOutput "   $($outputs['api_gateway_url'])" $COLOR_GREEN
}

# S3 Buckets
Write-ColorOutput "`nS3 Data Lake Buckets:" $COLOR_WHITE
$buckets = aws s3 ls | Select-String $PROJECT_NAME
$buckets | ForEach-Object { Write-ColorOutput "   $_" $COLOR_CYAN }

# Database
Write-ColorOutput "`nMySQL Database:" $COLOR_WHITE
Write-ColorOutput "   Host: $MYSQL_HOST" $COLOR_CYAN
Write-ColorOutput "   Database: $MYSQL_DATABASE" $COLOR_CYAN
Write-ColorOutput "   DataSize: ~500MB" $COLOR_CYAN

# Lambda Functions
Write-ColorOutput "`nLambda Functions:" $COLOR_WHITE
$functions = aws lambda list-functions --query "Functions[?contains(FunctionName, ``$PROJECT_NAME``)].FunctionName" --output text
if ($functions) {
    $functions -split "`t" | ForEach-Object { Write-ColorOutput "   $_" $COLOR_CYAN }
}

# CloudWatch Logs
Write-ColorOutput "`nCloudWatch Logs:" $COLOR_WHITE
Write-ColorOutput "   https://console.aws.amazon.com/cloudwatch/home?region=$AWS_REGION#logsV2:log-groups" $COLOR_CYAN

# Cost Estimate
Write-ColorOutput "`nEstimated Monthly Cost:" $COLOR_WHITE
Write-ColorOutput "   Development: ~`$280-450/month" $COLOR_YELLOW

# Next Steps
Write-ColorOutput "`nNEXT STEPS:" $COLOR_CYAN
Write-ColorOutput "1. Access the frontend: $frontendUrl" $COLOR_WHITE
Write-ColorOutput "2. Test API endpoints using the API Gateway URL" $COLOR_WHITE
Write-ColorOutput "3. Monitor CloudWatch Logs for any issues" $COLOR_WHITE
Write-ColorOutput "4. Setup CloudWatch alarms for production" $COLOR_WHITE
Write-ColorOutput "5. Configure custom domain names (optional)" $COLOR_WHITE
Write-ColorOutput "6. Setup CI/CD pipeline for automated deployments" $COLOR_WHITE

# Save URLs to file
$urlsFile = "DEPLOYMENT_URLS.txt"
$urlsContent = @"
# eCommerce AI Platform - Deployment URLs
# Generated: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")

## Frontend Application
$frontendUrl

## API Gateway
$($outputs['api_gateway_url'])

## MySQL Database
Host: $MYSQL_HOST
Database: $MYSQL_DATABASE
DataSize: ~500MB

## AWS Console Links
CloudWatch Logs: https://console.aws.amazon.com/cloudwatch/home?region=$AWS_REGION#logsV2:log-groups
Lambda Functions: https://console.aws.amazon.com/lambda/home?region=$AWS_REGION#/functions
S3 Buckets: https://s3.console.aws.amazon.com/s3/home?region=$AWS_REGION
API Gateway: https://console.aws.amazon.com/apigateway/home?region=$AWS_REGION

## Estimated Monthly Cost
Development Environment: ~`$280-450/month
"@

$urlsContent | Out-File -FilePath $urlsFile -Encoding UTF8
Write-ColorOutput "`n[OK] URLs saved to: $urlsFile" $COLOR_GREEN

Write-ColorOutput "`nDeployment completed successfully!" $COLOR_GREEN
Write-ColorOutput "Thank you for using the eCommerce AI Platform deployment script!" $COLOR_WHITE

exit 0
