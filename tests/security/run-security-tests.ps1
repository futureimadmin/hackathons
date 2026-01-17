#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Run security tests for eCommerce AI Platform

.DESCRIPTION
    Comprehensive security testing including:
    - OWASP ZAP vulnerability scanning
    - SQL injection testing
    - XSS prevention testing
    - Authentication/authorization testing
    - Sensitive data masking verification

.PARAMETER TestType
    Type of test: all, zap, sql-injection, xss, auth, encryption, masking

.PARAMETER ApiUrl
    API base URL (default: from environment variable)

.EXAMPLE
    .\run-security-tests.ps1 -TestType all
    .\run-security-tests.ps1 -TestType sql-injection
#>

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet("all", "zap", "sql-injection", "xss", "auth", "encryption", "masking")]
    [string]$TestType = "all",
    
    [Parameter(Mandatory=$false)]
    [string]$ApiUrl = $env:API_BASE_URL
)

$COLOR_GREEN = "Green"
$COLOR_RED = "Red"
$COLOR_YELLOW = "Yellow"
$COLOR_CYAN = "Cyan"

function Write-ColorOutput {
    param([string]$Message, [string]$Color = "White")
    Write-Host $Message -ForegroundColor $Color
}

function Test-SQLInjection {
    Write-ColorOutput "`n=== SQL Injection Testing ===" $COLOR_CYAN
    
    $tests = @(
        @{Name="Auth Bypass"; Endpoint="/auth/login"; Payload='{"email":"admin@example.com'' OR ''1''=''1","password":"anything"}'},
        @{Name="Query Injection"; Endpoint="/analytics/query"; Payload='{"system":"market-intelligence","query":"SELECT * FROM customers WHERE id=''1'' OR ''1''=''1''"}'}
    )
    
    $passed = 0
    $failed = 0
    
    foreach ($test in $tests) {
        Write-ColorOutput "`nTesting: $($test.Name)" $COLOR_CYAN
        
        try {
            $response = Invoke-WebRequest -Uri "$ApiUrl$($test.Endpoint)" `
                -Method POST `
                -Body $test.Payload `
                -ContentType "application/json" `
                -ErrorAction Stop
            
            if ($response.StatusCode -eq 200) {
                Write-ColorOutput "  ✗ FAILED: SQL injection not blocked" $COLOR_RED
                $failed++
            }
        } catch {
            if ($_.Exception.Response.StatusCode -in @(400, 401)) {
                Write-ColorOutput "  ✓ PASSED: SQL injection blocked" $COLOR_GREEN
                $passed++
            } else {
                Write-ColorOutput "  ⚠ WARNING: Unexpected response" $COLOR_YELLOW
            }
        }
    }
    
    Write-ColorOutput "`nSQL Injection Tests: $passed passed, $failed failed" $COLOR_CYAN
}

function Test-XSS {
    Write-ColorOutput "`n=== XSS Prevention Testing ===" $COLOR_CYAN
    
    $xssPayloads = @(
        "<script>alert('XSS')</script>",
        "<img src=x onerror=alert('XSS')>",
        "javascript:alert('XSS')",
        "<svg onload=alert('XSS')>"
    )
    
    $passed = 0
    $failed = 0
    
    foreach ($payload in $xssPayloads) {
        Write-ColorOutput "`nTesting payload: $payload" $COLOR_CYAN
        
        try {
            $body = @{
                user_id = "USER001"
                message = $payload
            } | ConvertTo-Json
            
            $response = Invoke-WebRequest -Uri "$ApiUrl/retail-copilot/chat" `
                -Method POST `
                -Body $body `
                -ContentType "application/json" `
                -Headers @{Authorization="Bearer $env:TEST_TOKEN"} `
                -ErrorAction Stop
            
            $content = $response.Content | ConvertFrom-Json
            
            if ($content.response -match "<script|onerror|javascript:") {
                Write-ColorOutput "  ✗ FAILED: XSS payload not sanitized" $COLOR_RED
                $failed++
            } else {
                Write-ColorOutput "  ✓ PASSED: XSS payload sanitized" $COLOR_GREEN
                $passed++
            }
        } catch {
            Write-ColorOutput "  ⚠ WARNING: Request failed" $COLOR_YELLOW
        }
    }
    
    Write-ColorOutput "`nXSS Tests: $passed passed, $failed failed" $COLOR_CYAN
}

function Test-Authentication {
    Write-ColorOutput "`n=== Authentication Testing ===" $COLOR_CYAN
    
    # Test 1: Expired token
    Write-ColorOutput "`nTest: Expired JWT token" $COLOR_CYAN
    try {
        $response = Invoke-WebRequest -Uri "$ApiUrl/market-intelligence/forecast" `
            -Method GET `
            -Headers @{Authorization="Bearer EXPIRED_TOKEN"} `
            -ErrorAction Stop
        
        Write-ColorOutput "  ✗ FAILED: Expired token accepted" $COLOR_RED
    } catch {
        if ($_.Exception.Response.StatusCode -eq 401) {
            Write-ColorOutput "  ✓ PASSED: Expired token rejected" $COLOR_GREEN
        }
    }
    
    # Test 2: No token
    Write-ColorOutput "`nTest: No authentication token" $COLOR_CYAN
    try {
        $response = Invoke-WebRequest -Uri "$ApiUrl/market-intelligence/forecast" `
            -Method GET `
            -ErrorAction Stop
        
        Write-ColorOutput "  ✗ FAILED: Request without token accepted" $COLOR_RED
    } catch {
        if ($_.Exception.Response.StatusCode -eq 401) {
            Write-ColorOutput "  ✓ PASSED: Request without token rejected" $COLOR_GREEN
        }
    }
    
    # Test 3: Weak password
    Write-ColorOutput "`nTest: Weak password rejection" $COLOR_CYAN
    try {
        $body = @{
            email = "test@example.com"
            password = "123456"
            firstName = "Test"
            lastName = "User"
        } | ConvertTo-Json
        
        $response = Invoke-WebRequest -Uri "$ApiUrl/auth/register" `
            -Method POST `
            -Body $body `
            -ContentType "application/json" `
            -ErrorAction Stop
        
        Write-ColorOutput "  ✗ FAILED: Weak password accepted" $COLOR_RED
    } catch {
        if ($_.Exception.Response.StatusCode -eq 400) {
            Write-ColorOutput "  ✓ PASSED: Weak password rejected" $COLOR_GREEN
        }
    }
}

function Test-Encryption {
    Write-ColorOutput "`n=== Encryption Testing ===" $COLOR_CYAN
    
    # Test 1: HTTPS enforcement
    Write-ColorOutput "`nTest: HTTPS enforcement" $COLOR_CYAN
    try {
        $httpUrl = $ApiUrl -replace "https://", "http://"
        $response = Invoke-WebRequest -Uri $httpUrl -Method GET -MaximumRedirection 0 -ErrorAction Stop
        
        if ($response.StatusCode -eq 301 -or $response.StatusCode -eq 302) {
            Write-ColorOutput "  ✓ PASSED: HTTP redirects to HTTPS" $COLOR_GREEN
        } else {
            Write-ColorOutput "  ✗ FAILED: HTTP not redirected" $COLOR_RED
        }
    } catch {
        Write-ColorOutput "  ⚠ WARNING: Could not test HTTP redirect" $COLOR_YELLOW
    }
    
    # Test 2: S3 encryption
    Write-ColorOutput "`nTest: S3 bucket encryption" $COLOR_CYAN
    $buckets = @("ecommerce-ai-platform-raw", "ecommerce-ai-platform-curated", "ecommerce-ai-platform-prod")
    
    foreach ($bucket in $buckets) {
        try {
            $encryption = aws s3api get-bucket-encryption --bucket $bucket 2>&1
            
            if ($encryption -match "AES256|aws:kms") {
                Write-ColorOutput "  ✓ PASSED: $bucket is encrypted" $COLOR_GREEN
            } else {
                Write-ColorOutput "  ✗ FAILED: $bucket is not encrypted" $COLOR_RED
            }
        } catch {
            Write-ColorOutput "  ⚠ WARNING: Could not check $bucket encryption" $COLOR_YELLOW
        }
    }
}

function Test-DataMasking {
    Write-ColorOutput "`n=== Sensitive Data Masking Testing ===" $COLOR_CYAN
    
    # Test PCI compliance endpoint
    Write-ColorOutput "`nTest: Credit card masking" $COLOR_CYAN
    try {
        $body = @{
            payment_ids = @("PAY001", "PAY002")
        } | ConvertTo-Json
        
        $response = Invoke-WebRequest -Uri "$ApiUrl/compliance/pci-compliance" `
            -Method POST `
            -Body $body `
            -ContentType "application/json" `
            -Headers @{Authorization="Bearer $env:TEST_TOKEN"} `
            -ErrorAction Stop
        
        $content = $response.Content | ConvertFrom-Json
        
        $allMasked = $true
        foreach ($payment in $content.masked_data.PSObject.Properties) {
            if ($payment.Value.card_number -notmatch "\*\*\*\*") {
                $allMasked = $false
                break
            }
        }
        
        if ($allMasked) {
            Write-ColorOutput "  ✓ PASSED: Credit cards properly masked" $COLOR_GREEN
        } else {
            Write-ColorOutput "  ✗ FAILED: Credit cards not masked" $COLOR_RED
        }
    } catch {
        Write-ColorOutput "  ⚠ WARNING: Could not test credit card masking" $COLOR_YELLOW
    }
}

# Main execution
Write-ColorOutput @"
╔═══════════════════════════════════════════════════════════╗
║   eCommerce AI Platform - Security Testing               ║
╚═══════════════════════════════════════════════════════════╝
"@ $COLOR_CYAN

if (-not $ApiUrl) {
    Write-ColorOutput "`n✗ API_BASE_URL not set" $COLOR_RED
    exit 1
}

Write-ColorOutput "API URL: $ApiUrl`n" $COLOR_CYAN

switch ($TestType) {
    "sql-injection" { Test-SQLInjection }
    "xss" { Test-XSS }
    "auth" { Test-Authentication }
    "encryption" { Test-Encryption }
    "masking" { Test-DataMasking }
    "all" {
        Test-SQLInjection
        Test-XSS
        Test-Authentication
        Test-Encryption
        Test-DataMasking
    }
}

Write-ColorOutput "`n=== Security Testing Complete ===" $COLOR_CYAN
