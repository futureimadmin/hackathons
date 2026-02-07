# Test API Authentication
# This script tests the API Gateway authentication flow

$apiUrl = "https://nqmakokb2a.execute-api.us-east-2.amazonaws.com/dev"

# Step 1: Login to get token
Write-Host "Step 1: Testing login..." -ForegroundColor Cyan
$loginBody = @{
    email = "test@example.com"
    password = "Test123!"
} | ConvertTo-Json

try {
    $loginResponse = Invoke-RestMethod -Uri "$apiUrl/auth/login" -Method POST -Body $loginBody -ContentType "application/json"
    Write-Host "✓ Login successful" -ForegroundColor Green
    Write-Host "Token: $($loginResponse.token.Substring(0, 50))..." -ForegroundColor Gray
    $token = $loginResponse.token
} catch {
    Write-Host "✗ Login failed: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Response: $($_.ErrorDetails.Message)" -ForegroundColor Yellow
    exit 1
}

# Step 2: Test Market Intelligence endpoint with token
Write-Host "`nStep 2: Testing Market Intelligence endpoint..." -ForegroundColor Cyan
$headers = @{
    "Authorization" = "Bearer $token"
    "Content-Type" = "application/json"
}

try {
    $trendsResponse = Invoke-RestMethod -Uri "$apiUrl/market-intelligence/trends" -Method GET -Headers $headers
    Write-Host "✓ Market Intelligence API call successful" -ForegroundColor Green
    Write-Host "Response: $($trendsResponse | ConvertTo-Json -Depth 2)" -ForegroundColor Gray
} catch {
    Write-Host "✗ Market Intelligence API call failed" -ForegroundColor Red
    Write-Host "Status Code: $($_.Exception.Response.StatusCode.value__)" -ForegroundColor Yellow
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Yellow
    
    if ($_.ErrorDetails) {
        Write-Host "Details: $($_.ErrorDetails.Message)" -ForegroundColor Yellow
    }
    
    # Check authorizer logs
    Write-Host "`nChecking authorizer logs..." -ForegroundColor Cyan
    aws logs tail /aws/lambda/futureim-ecommerce-ai-platform-api-authorizer --since 5m --format short | Select-Object -Last 20
}

Write-Host "`nTest complete." -ForegroundColor Cyan
