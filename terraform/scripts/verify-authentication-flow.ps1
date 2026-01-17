# Comprehensive Authentication Flow Verification Script
# Tests all authentication components end-to-end

param(
    [Parameter(Mandatory=$false)]
    [string]$ApiUrl,
    
    [Parameter(Mandatory=$false)]
    [string]$Region = "us-east-1",
    
    [Parameter(Mandatory=$false)]
    [switch]$SkipInfrastructureCheck,
    
    [Parameter(Mandatory=$false)]
    [switch]$Verbose
)

$ErrorActionPreference = "Stop"

Write-Host "╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║     Authentication Flow End-to-End Verification Script        ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# Test counters
$totalTests = 0
$passedTests = 0
$failedTests = 0
$warnings = 0

function Write-TestHeader {
    param([string]$Title)
    Write-Host ""
    Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host " $Title" -ForegroundColor Cyan
    Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
}

function Write-TestResult {
    param(
        [string]$TestName,
        [bool]$Passed,
        [string]$Message = "",
        [bool]$IsWarning = $false
    )
    
    $script:totalTests++
    
    if ($IsWarning) {
        Write-Host "⚠ " -NoNewline -ForegroundColor Yellow
        Write-Host "$TestName" -ForegroundColor Yellow
        if ($Message) { Write-Host "  $Message" -ForegroundColor Gray }
        $script:warnings++
    }
    elseif ($Passed) {
        Write-Host "✓ " -NoNewline -ForegroundColor Green
        Write-Host "$TestName" -ForegroundColor Green
        if ($Message) { Write-Host "  $Message" -ForegroundColor Gray }
        $script:passedTests++
    }
    else {
        Write-Host "✗ " -NoNewline -ForegroundColor Red
        Write-Host "$TestName" -ForegroundColor Red
        if ($Message) { Write-Host "  $Message" -ForegroundColor Gray }
        $script:failedTests++
    }
}

# ============================================================================
# PHASE 1: Infrastructure Verification
# ============================================================================

if (-not $SkipInfrastructureCheck) {
    Write-TestHeader "Phase 1: Infrastructure Verification"
    
    # Test 1: Check AWS CLI
    try {
        $awsVersion = aws --version 2>&1
        Write-TestResult "AWS CLI installed" $true $awsVersion
    } catch {
        Write-TestResult "AWS CLI installed" $false "AWS CLI not found"
        exit 1
    }
    
    # Test 2: Check AWS credentials
    try {
        $identity = aws sts get-caller-identity --output json | ConvertFrom-Json
        Write-TestResult "AWS credentials configured" $true "Account: $($identity.Account)"
    } catch {
        Write-TestResult "AWS credentials configured" $false "Failed to get AWS identity"
        exit 1
    }
    
    # Test 3: Check DynamoDB table exists
    try {
        $table = aws dynamodb describe-table --table-name ecommerce-users --region $Region --output json 2>&1 | ConvertFrom-Json
        Write-TestResult "DynamoDB table exists" $true "Status: $($table.Table.TableStatus)"
    } catch {
        Write-TestResult "DynamoDB table exists" $false "Table not found or not accessible"
    }
    
    # Test 4: Check JWT secret exists
    try {
        $secret = aws secretsmanager describe-secret --secret-id ecommerce-jwt-secret --region $Region --output json 2>&1 | ConvertFrom-Json
        Write-TestResult "JWT secret exists" $true "ARN: $($secret.ARN)"
    } catch {
        Write-TestResult "JWT secret exists" $false "Secret not found"
    }
    
    # Test 5: Check Auth Lambda exists
    try {
        $lambda = aws lambda get-function --function-name ecommerce-auth-service --region $Region --output json 2>&1 | ConvertFrom-Json
        Write-TestResult "Auth Lambda function exists" $true "Runtime: $($lambda.Configuration.Runtime)"
    } catch {
        Write-TestResult "Auth Lambda function exists" $false "Function not found"
    }
    
    # Test 6: Check Authorizer Lambda exists
    try {
        $authorizerLambda = aws lambda get-function --function-name ecommerce-platform-api-authorizer --region $Region --output json 2>&1 | ConvertFrom-Json
        Write-TestResult "Authorizer Lambda exists" $true "Runtime: $($authorizerLambda.Configuration.Runtime)"
    } catch {
        Write-TestResult "Authorizer Lambda exists" $false "Function not found"
    }
    
    # Test 7: Check API Gateway exists
    try {
        $apis = aws apigateway get-rest-apis --region $Region --output json | ConvertFrom-Json
        $api = $apis.items | Where-Object { $_.name -eq "ecommerce-platform-api" }
        if ($api) {
            Write-TestResult "API Gateway exists" $true "ID: $($api.id)"
            if (-not $ApiUrl) {
                $ApiUrl = "https://$($api.id).execute-api.$Region.amazonaws.com/prod"
            }
        } else {
            Write-TestResult "API Gateway exists" $false "API not found"
        }
    } catch {
        Write-TestResult "API Gateway exists" $false "Failed to list APIs"
    }
    
    # Test 8: Check WAF Web ACL exists
    try {
        $wafAcls = aws wafv2 list-web-acls --scope REGIONAL --region $Region --output json 2>&1 | ConvertFrom-Json
        $waf = $wafAcls.WebACLs | Where-Object { $_.Name -like "*ecommerce-platform-api*" }
        if ($waf) {
            Write-TestResult "WAF Web ACL exists" $true "Name: $($waf.Name)"
        } else {
            Write-TestResult "WAF Web ACL exists" $false "WAF not found" $true
        }
    } catch {
        Write-TestResult "WAF Web ACL exists" $false "Failed to list WAF ACLs" $true
    }
}

# ============================================================================
# PHASE 2: API Endpoint Verification
# ============================================================================

Write-TestHeader "Phase 2: API Endpoint Verification"

if (-not $ApiUrl) {
    Write-Host "Error: API URL not provided and could not be determined" -ForegroundColor Red
    Write-Host "Please provide API URL with -ApiUrl parameter" -ForegroundColor Yellow
    exit 1
}

Write-Host "API URL: $ApiUrl" -ForegroundColor White
Write-Host ""

# Generate test data
$testEmail = "test-$(Get-Random -Minimum 10000 -Maximum 99999)@example.com"
$testPassword = "SecurePass123!"
$testName = "Test User $(Get-Random -Minimum 100 -Maximum 999)"

Write-Host "Test User:" -ForegroundColor White
Write-Host "  Email: $testEmail" -ForegroundColor Gray
Write-Host "  Password: $testPassword" -ForegroundColor Gray
Write-Host "  Name: $testName" -ForegroundColor Gray
Write-Host ""

# Test 9: Check API Gateway is accessible
try {
    $response = Invoke-WebRequest -Uri $ApiUrl -Method GET -ErrorAction SilentlyContinue
    Write-TestResult "API Gateway accessible" $true "Status: $($response.StatusCode)"
} catch {
    if ($_.Exception.Response.StatusCode -eq 403) {
        Write-TestResult "API Gateway accessible" $true "Returns 403 (expected for root path)"
    } else {
        Write-TestResult "API Gateway accessible" $false "Error: $($_.Exception.Message)"
    }
}

# ============================================================================
# PHASE 3: User Registration Flow
# ============================================================================

Write-TestHeader "Phase 3: User Registration Flow"

$userId = $null

# Test 10: Register new user
try {
    $registerBody = @{
        email = $testEmail
        password = $testPassword
        name = $testName
    } | ConvertTo-Json

    $registerResponse = Invoke-RestMethod `
        -Uri "$ApiUrl/auth/register" `
        -Method POST `
        -Body $registerBody `
        -ContentType "application/json" `
        -ErrorAction Stop

    if ($registerResponse.userId) {
        $userId = $registerResponse.userId
        Write-TestResult "User registration successful" $true "User ID: $userId"
    } else {
        Write-TestResult "User registration successful" $false "No userId returned"
    }
} catch {
    $errorMessage = $_.Exception.Message
    if ($_.ErrorDetails.Message) {
        $errorDetails = $_.ErrorDetails.Message | ConvertFrom-Json
        $errorMessage = $errorDetails.message
    }
    Write-TestResult "User registration successful" $false "Error: $errorMessage"
}

# Test 11: Verify user in DynamoDB
if ($userId) {
    try {
        $dbUser = aws dynamodb get-item `
            --table-name ecommerce-users `
            --key "{\"userId\": {\"S\": \"$userId\"}}" `
            --region $Region `
            --output json | ConvertFrom-Json
        
        if ($dbUser.Item) {
            Write-TestResult "User stored in DynamoDB" $true "Email: $($dbUser.Item.email.S)"
        } else {
            Write-TestResult "User stored in DynamoDB" $false "User not found in database"
        }
    } catch {
        Write-TestResult "User stored in DynamoDB" $false "Error querying DynamoDB"
    }
}

# Test 12: Attempt duplicate registration (should fail)
try {
    $duplicateBody = @{
        email = $testEmail
        password = $testPassword
        name = $testName
    } | ConvertTo-Json

    $duplicateResponse = Invoke-RestMethod `
        -Uri "$ApiUrl/auth/register" `
        -Method POST `
        -Body $duplicateBody `
        -ContentType "application/json" `
        -ErrorAction Stop

    Write-TestResult "Duplicate registration rejected" $false "Should have returned error"
} catch {
    if ($_.Exception.Response.StatusCode -eq 400) {
        Write-TestResult "Duplicate registration rejected" $true "Returns 400 (expected)"
    } else {
        Write-TestResult "Duplicate registration rejected" $false "Unexpected error: $($_.Exception.Message)"
    }
}

# Test 13: Weak password rejected
try {
    $weakPasswordBody = @{
        email = "weak-$(Get-Random)@example.com"
        password = "weak"
        name = "Weak User"
    } | ConvertTo-Json

    $weakResponse = Invoke-RestMethod `
        -Uri "$ApiUrl/auth/register" `
        -Method POST `
        -Body $weakPasswordBody `
        -ContentType "application/json" `
        -ErrorAction Stop

    Write-TestResult "Weak password rejected" $false "Should have returned error"
} catch {
    if ($_.Exception.Response.StatusCode -eq 400) {
        Write-TestResult "Weak password rejected" $true "Returns 400 (expected)"
    } else {
        Write-TestResult "Weak password rejected" $false "Unexpected error"
    }
}

# ============================================================================
# PHASE 4: User Login Flow
# ============================================================================

Write-TestHeader "Phase 4: User Login Flow"

$token = $null

# Test 14: Login with correct credentials
try {
    $loginBody = @{
        email = $testEmail
        password = $testPassword
    } | ConvertTo-Json

    $loginResponse = Invoke-RestMethod `
        -Uri "$ApiUrl/auth/login" `
        -Method POST `
        -Body $loginBody `
        -ContentType "application/json" `
        -ErrorAction Stop

    if ($loginResponse.token -and $loginResponse.userId) {
        $token = $loginResponse.token
        Write-TestResult "Login successful" $true "Token received (${($token.Length)} chars)"
        
        if ($Verbose) {
            Write-Host "  Token: $($token.Substring(0, [Math]::Min(50, $token.Length)))..." -ForegroundColor Gray
        }
    } else {
        Write-TestResult "Login successful" $false "Missing token or userId"
    }
} catch {
    $errorMessage = $_.Exception.Message
    if ($_.ErrorDetails.Message) {
        $errorDetails = $_.ErrorDetails.Message | ConvertFrom-Json
        $errorMessage = $errorDetails.message
    }
    Write-TestResult "Login successful" $false "Error: $errorMessage"
}

# Test 15: Login with wrong password (should fail)
try {
    $wrongPasswordBody = @{
        email = $testEmail
        password = "WrongPassword123!"
    } | ConvertTo-Json

    $wrongResponse = Invoke-RestMethod `
        -Uri "$ApiUrl/auth/login" `
        -Method POST `
        -Body $wrongPasswordBody `
        -ContentType "application/json" `
        -ErrorAction Stop

    Write-TestResult "Wrong password rejected" $false "Should have returned error"
} catch {
    if ($_.Exception.Response.StatusCode -eq 401) {
        Write-TestResult "Wrong password rejected" $true "Returns 401 (expected)"
    } else {
        Write-TestResult "Wrong password rejected" $false "Unexpected error"
    }
}

# Test 16: Login with non-existent user (should fail)
try {
    $nonExistentBody = @{
        email = "nonexistent-$(Get-Random)@example.com"
        password = $testPassword
    } | ConvertTo-Json

    $nonExistentResponse = Invoke-RestMethod `
        -Uri "$ApiUrl/auth/login" `
        -Method POST `
        -Body $nonExistentBody `
        -ContentType "application/json" `
        -ErrorAction Stop

    Write-TestResult "Non-existent user rejected" $false "Should have returned error"
} catch {
    if ($_.Exception.Response.StatusCode -eq 401) {
        Write-TestResult "Non-existent user rejected" $true "Returns 401 (expected)"
    } else {
        Write-TestResult "Non-existent user rejected" $false "Unexpected error"
    }
}

# ============================================================================
# PHASE 5: JWT Token Verification
# ============================================================================

Write-TestHeader "Phase 5: JWT Token Verification"

# Test 17: Verify valid token
if ($token) {
    try {
        $verifyBody = @{
            token = $token
        } | ConvertTo-Json

        $verifyResponse = Invoke-RestMethod `
            -Uri "$ApiUrl/auth/verify" `
            -Method POST `
            -Headers @{ Authorization = "Bearer $token" } `
            -Body $verifyBody `
            -ContentType "application/json" `
            -ErrorAction Stop

        if ($verifyResponse.valid -eq $true) {
            Write-TestResult "Token verification successful" $true "User ID: $($verifyResponse.userId)"
        } else {
            Write-TestResult "Token verification successful" $false "Token marked as invalid"
        }
    } catch {
        Write-TestResult "Token verification successful" $false "Error: $($_.Exception.Message)"
    }
} else {
    Write-TestResult "Token verification successful" $false "No token available to verify"
}

# Test 18: Verify without Authorization header (should fail)
if ($token) {
    try {
        $verifyBody = @{
            token = $token
        } | ConvertTo-Json

        $noAuthResponse = Invoke-RestMethod `
            -Uri "$ApiUrl/auth/verify" `
            -Method POST `
            -Body $verifyBody `
            -ContentType "application/json" `
            -ErrorAction Stop

        Write-TestResult "Missing Authorization header rejected" $false "Should have returned error"
    } catch {
        if ($_.Exception.Response.StatusCode -eq 401) {
            Write-TestResult "Missing Authorization header rejected" $true "Returns 401 (expected)"
        } else {
            Write-TestResult "Missing Authorization header rejected" $false "Unexpected error"
        }
    }
}

# Test 19: Verify with invalid token (should fail)
try {
    $invalidToken = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c"
    
    $invalidVerifyBody = @{
        token = $invalidToken
    } | ConvertTo-Json

    $invalidResponse = Invoke-RestMethod `
        -Uri "$ApiUrl/auth/verify" `
        -Method POST `
        -Headers @{ Authorization = "Bearer $invalidToken" } `
        -Body $invalidVerifyBody `
        -ContentType "application/json" `
        -ErrorAction Stop

    Write-TestResult "Invalid token rejected" $false "Should have returned error"
} catch {
    if ($_.Exception.Response.StatusCode -eq 401) {
        Write-TestResult "Invalid token rejected" $true "Returns 401 (expected)"
    } else {
        Write-TestResult "Invalid token rejected" $false "Unexpected error"
    }
}

# ============================================================================
# PHASE 6: Password Reset Flow
# ============================================================================

Write-TestHeader "Phase 6: Password Reset Flow"

# Test 20: Request password reset
try {
    $forgotBody = @{
        email = $testEmail
    } | ConvertTo-Json

    $forgotResponse = Invoke-RestMethod `
        -Uri "$ApiUrl/auth/forgot-password" `
        -Method POST `
        -Body $forgotBody `
        -ContentType "application/json" `
        -ErrorAction Stop

    if ($forgotResponse.message) {
        Write-TestResult "Password reset requested" $true "Message: $($forgotResponse.message)"
    } else {
        Write-TestResult "Password reset requested" $false "No message returned"
    }
} catch {
    Write-TestResult "Password reset requested" $false "Error: $($_.Exception.Message)"
}

# Test 21: Verify reset token in DynamoDB
if ($userId) {
    try {
        Start-Sleep -Seconds 2  # Wait for DynamoDB update
        
        $dbUser = aws dynamodb get-item `
            --table-name ecommerce-users `
            --key "{\"userId\": {\"S\": \"$userId\"}}" `
            --region $Region `
            --output json | ConvertFrom-Json
        
        if ($dbUser.Item.resetToken) {
            Write-TestResult "Reset token stored in DynamoDB" $true "Token exists"
        } else {
            Write-TestResult "Reset token stored in DynamoDB" $false "No reset token found"
        }
    } catch {
        Write-TestResult "Reset token stored in DynamoDB" $false "Error querying DynamoDB"
    }
}

# Test 22: Request reset for non-existent user (should still return success for security)
try {
    $nonExistentForgotBody = @{
        email = "nonexistent-$(Get-Random)@example.com"
    } | ConvertTo-Json

    $nonExistentForgotResponse = Invoke-RestMethod `
        -Uri "$ApiUrl/auth/forgot-password" `
        -Method POST `
        -Body $nonExistentForgotBody `
        -ContentType "application/json" `
        -ErrorAction Stop

    Write-TestResult "Non-existent user reset handled" $true "Returns success (security best practice)"
} catch {
    Write-TestResult "Non-existent user reset handled" $false "Should return success"
}

# ============================================================================
# PHASE 7: CloudWatch Logs Verification
# ============================================================================

Write-TestHeader "Phase 7: CloudWatch Logs Verification"

# Test 23: Check API Gateway logs
try {
    $apiLogGroup = "/aws/apigateway/ecommerce-platform-api"
    $apiLogs = aws logs describe-log-streams `
        --log-group-name $apiLogGroup `
        --region $Region `
        --max-items 1 `
        --output json 2>&1 | ConvertFrom-Json
    
    if ($apiLogs.logStreams) {
        Write-TestResult "API Gateway logs exist" $true "Log group: $apiLogGroup"
    } else {
        Write-TestResult "API Gateway logs exist" $false "No log streams found" $true
    }
} catch {
    Write-TestResult "API Gateway logs exist" $false "Log group not found" $true
}

# Test 24: Check Auth Lambda logs
try {
    $authLogGroup = "/aws/lambda/ecommerce-auth-service"
    $authLogs = aws logs describe-log-streams `
        --log-group-name $authLogGroup `
        --region $Region `
        --max-items 1 `
        --output json 2>&1 | ConvertFrom-Json
    
    if ($authLogs.logStreams) {
        Write-TestResult "Auth Lambda logs exist" $true "Log group: $authLogGroup"
    } else {
        Write-TestResult "Auth Lambda logs exist" $false "No log streams found" $true
    }
} catch {
    Write-TestResult "Auth Lambda logs exist" $false "Log group not found" $true
}

# Test 25: Check Authorizer Lambda logs
try {
    $authorizerLogGroup = "/aws/lambda/ecommerce-platform-api-authorizer"
    $authorizerLogs = aws logs describe-log-streams `
        --log-group-name $authorizerLogGroup `
        --region $Region `
        --max-items 1 `
        --output json 2>&1 | ConvertFrom-Json
    
    if ($authorizerLogs.logStreams) {
        Write-TestResult "Authorizer Lambda logs exist" $true "Log group: $authorizerLogGroup"
    } else {
        Write-TestResult "Authorizer Lambda logs exist" $false "No log streams found" $true
    }
} catch {
    Write-TestResult "Authorizer Lambda logs exist" $false "Log group not found" $true
}

# ============================================================================
# FINAL SUMMARY
# ============================================================================

Write-Host ""
Write-Host "╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║                      Verification Summary                      ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

Write-Host "Total Tests:   $totalTests" -ForegroundColor White
Write-Host "Passed:        " -NoNewline
Write-Host "$passedTests" -ForegroundColor Green
Write-Host "Failed:        " -NoNewline
Write-Host "$failedTests" -ForegroundColor Red
Write-Host "Warnings:      " -NoNewline
Write-Host "$warnings" -ForegroundColor Yellow
Write-Host ""

$successRate = if ($totalTests -gt 0) { [math]::Round(($passedTests / $totalTests) * 100, 1) } else { 0 }
Write-Host "Success Rate:  $successRate%" -ForegroundColor $(if ($successRate -ge 90) { "Green" } elseif ($successRate -ge 70) { "Yellow" } else { "Red" })
Write-Host ""

if ($failedTests -eq 0) {
    Write-Host "✓ All critical tests passed! Authentication flow is working correctly." -ForegroundColor Green
    if ($warnings -gt 0) {
        Write-Host "⚠ Some warnings were detected. Review them above." -ForegroundColor Yellow
    }
    exit 0
} else {
    Write-Host "✗ Some tests failed. Please review the errors above and fix the issues." -ForegroundColor Red
    Write-Host ""
    Write-Host "Common issues:" -ForegroundColor Yellow
    Write-Host "  1. Infrastructure not deployed - run 'terraform apply'" -ForegroundColor Gray
    Write-Host "  2. Lambda functions not built - build auth service JAR and authorizer ZIP" -ForegroundColor Gray
    Write-Host "  3. JWT secret not created - run setup-secrets.ps1" -ForegroundColor Gray
    Write-Host "  4. SES email not verified - verify sender email in SES console" -ForegroundColor Gray
    exit 1
}
