# Test API Gateway Endpoints
# Verifies all authentication endpoints are working correctly

param(
    [Parameter(Mandatory=$false)]
    [string]$ApiUrl,
    
    [Parameter(Mandatory=$false)]
    [string]$TestEmail = "test-$(Get-Random)@example.com",
    
    [Parameter(Mandatory=$false)]
    [string]$TestPassword = "SecurePass123!",
    
    [Parameter(Mandatory=$false)]
    [string]$TestName = "Test User"
)

Write-Host "=== API Gateway Test Script ===" -ForegroundColor Cyan
Write-Host ""

# Get API URL from Terraform output if not provided
if (-not $ApiUrl) {
    Write-Host "Getting API URL from Terraform..." -ForegroundColor Yellow
    try {
        $ApiUrl = terraform output -raw api_endpoint
        Write-Host "✓ API URL: $ApiUrl" -ForegroundColor Green
    } catch {
        Write-Host "✗ Failed to get API URL from Terraform" -ForegroundColor Red
        Write-Host "Please provide API URL with -ApiUrl parameter" -ForegroundColor Yellow
        exit 1
    }
}

Write-Host ""
Write-Host "Test Configuration:" -ForegroundColor Cyan
Write-Host "  API URL: $ApiUrl"
Write-Host "  Email: $TestEmail"
Write-Host "  Password: $TestPassword"
Write-Host "  Name: $TestName"
Write-Host ""

$testsPassed = 0
$testsFailed = 0

# Test 1: Register User
Write-Host "[Test 1/5] Testing user registration..." -ForegroundColor Cyan
try {
    $registerBody = @{
        email = $TestEmail
        password = $TestPassword
        name = $TestName
    } | ConvertTo-Json

    $registerResponse = Invoke-RestMethod `
        -Uri "$ApiUrl/auth/register" `
        -Method POST `
        -Body $registerBody `
        -ContentType "application/json" `
        -ErrorAction Stop

    if ($registerResponse.userId) {
        Write-Host "✓ Registration successful" -ForegroundColor Green
        Write-Host "  User ID: $($registerResponse.userId)" -ForegroundColor Gray
        $testsPassed++
    } else {
        Write-Host "✗ Registration failed: No userId returned" -ForegroundColor Red
        $testsFailed++
    }
} catch {
    Write-Host "✗ Registration failed: $($_.Exception.Message)" -ForegroundColor Red
    $testsFailed++
}

Write-Host ""

# Test 2: Login
Write-Host "[Test 2/5] Testing user login..." -ForegroundColor Cyan
try {
    $loginBody = @{
        email = $TestEmail
        password = $TestPassword
    } | ConvertTo-Json

    $loginResponse = Invoke-RestMethod `
        -Uri "$ApiUrl/auth/login" `
        -Method POST `
        -Body $loginBody `
        -ContentType "application/json" `
        -ErrorAction Stop

    if ($loginResponse.token -and $loginResponse.userId) {
        Write-Host "✓ Login successful" -ForegroundColor Green
        Write-Host "  User ID: $($loginResponse.userId)" -ForegroundColor Gray
        Write-Host "  Token: $($loginResponse.token.Substring(0, 20))..." -ForegroundColor Gray
        $token = $loginResponse.token
        $testsPassed++
    } else {
        Write-Host "✗ Login failed: Missing token or userId" -ForegroundColor Red
        $testsFailed++
    }
} catch {
    Write-Host "✗ Login failed: $($_.Exception.Message)" -ForegroundColor Red
    $testsFailed++
}

Write-Host ""

# Test 3: Verify Token (Protected Endpoint)
if ($token) {
    Write-Host "[Test 3/5] Testing token verification (protected endpoint)..." -ForegroundColor Cyan
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
            Write-Host "✓ Token verification successful" -ForegroundColor Green
            Write-Host "  Valid: $($verifyResponse.valid)" -ForegroundColor Gray
            Write-Host "  User ID: $($verifyResponse.userId)" -ForegroundColor Gray
            $testsPassed++
        } else {
            Write-Host "✗ Token verification failed: Token not valid" -ForegroundColor Red
            $testsFailed++
        }
    } catch {
        Write-Host "✗ Token verification failed: $($_.Exception.Message)" -ForegroundColor Red
        $testsFailed++
    }
} else {
    Write-Host "[Test 3/5] Skipping token verification (no token available)" -ForegroundColor Yellow
    $testsFailed++
}

Write-Host ""

# Test 4: Forgot Password
Write-Host "[Test 4/5] Testing forgot password..." -ForegroundColor Cyan
try {
    $forgotBody = @{
        email = $TestEmail
    } | ConvertTo-Json

    $forgotResponse = Invoke-RestMethod `
        -Uri "$ApiUrl/auth/forgot-password" `
        -Method POST `
        -Body $forgotBody `
        -ContentType "application/json" `
        -ErrorAction Stop

    if ($forgotResponse.message) {
        Write-Host "✓ Forgot password successful" -ForegroundColor Green
        Write-Host "  Message: $($forgotResponse.message)" -ForegroundColor Gray
        $testsPassed++
    } else {
        Write-Host "✗ Forgot password failed: No message returned" -ForegroundColor Red
        $testsFailed++
    }
} catch {
    Write-Host "✗ Forgot password failed: $($_.Exception.Message)" -ForegroundColor Red
    $testsFailed++
}

Write-Host ""

# Test 5: Invalid Login (Should Fail)
Write-Host "[Test 5/5] Testing invalid login (should fail)..." -ForegroundColor Cyan
try {
    $invalidLoginBody = @{
        email = $TestEmail
        password = "WrongPassword123!"
    } | ConvertTo-Json

    $invalidLoginResponse = Invoke-RestMethod `
        -Uri "$ApiUrl/auth/login" `
        -Method POST `
        -Body $invalidLoginBody `
        -ContentType "application/json" `
        -ErrorAction Stop

    Write-Host "✗ Invalid login test failed: Should have returned error" -ForegroundColor Red
    $testsFailed++
} catch {
    if ($_.Exception.Response.StatusCode -eq 401) {
        Write-Host "✓ Invalid login correctly rejected (401 Unauthorized)" -ForegroundColor Green
        $testsPassed++
    } else {
        Write-Host "✗ Invalid login test failed: Unexpected error $($_.Exception.Message)" -ForegroundColor Red
        $testsFailed++
    }
}

Write-Host ""
Write-Host "=== Test Summary ===" -ForegroundColor Cyan
Write-Host "Tests Passed: $testsPassed" -ForegroundColor Green
Write-Host "Tests Failed: $testsFailed" -ForegroundColor Red
Write-Host ""

if ($testsFailed -eq 0) {
    Write-Host "✓ All tests passed! API Gateway is working correctly." -ForegroundColor Green
    exit 0
} else {
    Write-Host "✗ Some tests failed. Please review the errors above." -ForegroundColor Red
    exit 1
}
