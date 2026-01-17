# Automated AI Systems Verification Script
# Task 22: Verify All AI Systems

param(
    [Parameter(Mandatory=$true)]
    [string]$ApiUrl,
    
    [Parameter(Mandatory=$true)]
    [string]$Token,
    
    [Parameter(Mandatory=$false)]
    [switch]$Verbose
)

$ErrorActionPreference = "Continue"
$results = @()

function Test-Endpoint {
    param(
        [string]$System,
        [string]$Endpoint,
        [string]$Method,
        [object]$Body = $null,
        [string]$Description
    )
    
    $url = "$ApiUrl$Endpoint"
    $headers = @{
        "Authorization" = "Bearer $Token"
        "Content-Type" = "application/json"
    }
    
    Write-Host "`n[Testing] $System - $Description" -ForegroundColor Cyan
    Write-Host "  URL: $Method $url" -ForegroundColor Gray
    
    $startTime = Get-Date
    
    try {
        if ($Method -eq "GET") {
            $response = Invoke-RestMethod -Uri $url -Method GET -Headers $headers -ErrorAction Stop
        } else {
            $bodyJson = $Body | ConvertTo-Json -Depth 10
            if ($Verbose) {
                Write-Host "  Body: $bodyJson" -ForegroundColor Gray
            }
            $response = Invoke-RestMethod -Uri $url -Method POST -Headers $headers -Body $bodyJson -ContentType "application/json" -ErrorAction Stop
        }
        
        $endTime = Get-Date
        $duration = ($endTime - $startTime).TotalSeconds
        
        Write-Host "  [PASS] Status: 200 OK (${duration}s)" -ForegroundColor Green
        
        if ($Verbose -and $response) {
            Write-Host "  Response: $($response | ConvertTo-Json -Depth 2 -Compress)" -ForegroundColor Gray
        }
        
        $results += [PSCustomObject]@{
            System = $System
            Endpoint = $Endpoint
            Description = $Description
            Status = "PASS"
            Duration = [math]::Round($duration, 2)
            Error = $null
        }
        
        return $response
    }
    catch {
        $endTime = Get-Date
        $duration = ($endTime - $startTime).TotalSeconds
        
        Write-Host "  [FAIL] Error: $($_.Exception.Message)" -ForegroundColor Red
        
        $results += [PSCustomObject]@{
            System = $System
            Endpoint = $Endpoint
            Description = $Description
            Status = "FAIL"
            Duration = [math]::Round($duration, 2)
            Error = $_.Exception.Message
        }
        
        return $null
    }
}

Write-Host "========================================" -ForegroundColor Yellow
Write-Host "AI Systems Verification - Task 22" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Yellow
Write-Host "API URL: $ApiUrl"
Write-Host "Started: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Write-Host ""

# System 1: Market Intelligence Hub
Write-Host "`n=== System 1: Market Intelligence Hub ===" -ForegroundColor Yellow

Test-Endpoint -System "Market Intelligence Hub" `
    -Endpoint "/market-intelligence/forecast" `
    -Method "POST" `
    -Body @{product_id="PROD001"; periods=30; model="auto"} `
    -Description "Generate forecast"

Test-Endpoint -System "Market Intelligence Hub" `
    -Endpoint "/market-intelligence/trends?category=Electronics&days=90" `
    -Method "GET" `
    -Description "Analyze trends"

Test-Endpoint -System "Market Intelligence Hub" `
    -Endpoint "/market-intelligence/pricing?product_id=PROD001" `
    -Method "GET" `
    -Description "Pricing analysis"

Test-Endpoint -System "Market Intelligence Hub" `
    -Endpoint "/market-intelligence/compare" `
    -Method "POST" `
    -Body @{product_id="PROD001"; periods=30; models=@("arima","prophet","lstm")} `
    -Description "Compare models"

# System 2: Demand Insights Engine
Write-Host "`n=== System 2: Demand Insights Engine ===" -ForegroundColor Yellow

Test-Endpoint -System "Demand Insights Engine" `
    -Endpoint "/demand-insights/segments?n_clusters=4" `
    -Method "GET" `
    -Description "Customer segmentation"

Test-Endpoint -System "Demand Insights Engine" `
    -Endpoint "/demand-insights/forecast" `
    -Method "POST" `
    -Body @{product_id="PROD001"; periods=30; include_features=@("seasonality","promotions","price")} `
    -Description "Demand forecast"

Test-Endpoint -System "Demand Insights Engine" `
    -Endpoint "/demand-insights/elasticity" `
    -Method "POST" `
    -Body @{product_id="PROD001"; price_range=@{min=50;max=150}} `
    -Description "Price elasticity"

Test-Endpoint -System "Demand Insights Engine" `
    -Endpoint "/demand-insights/clv" `
    -Method "POST" `
    -Body @{customer_ids=@("CUST001","CUST002","CUST003")} `
    -Description "CLV prediction"

Test-Endpoint -System "Demand Insights Engine" `
    -Endpoint "/demand-insights/churn" `
    -Method "POST" `
    -Body @{customer_ids=@("CUST001","CUST002")} `
    -Description "Churn prediction"

Test-Endpoint -System "Demand Insights Engine" `
    -Endpoint "/demand-insights/at-risk?threshold=0.7&limit=10" `
    -Method "GET" `
    -Description "At-risk customers"

# System 3: Compliance Guardian
Write-Host "`n=== System 3: Compliance Guardian ===" -ForegroundColor Yellow

Test-Endpoint -System "Compliance Guardian" `
    -Endpoint "/compliance/fraud-detection" `
    -Method "POST" `
    -Body @{transaction_ids=@("TXN001","TXN002","TXN003")} `
    -Description "Fraud detection"

Test-Endpoint -System "Compliance Guardian" `
    -Endpoint "/compliance/risk-score" `
    -Method "POST" `
    -Body @{transaction_ids=@("TXN001","TXN002")} `
    -Description "Risk scoring"

Test-Endpoint -System "Compliance Guardian" `
    -Endpoint "/compliance/high-risk-transactions?threshold=70&limit=50" `
    -Method "GET" `
    -Description "High-risk transactions"

Test-Endpoint -System "Compliance Guardian" `
    -Endpoint "/compliance/pci-compliance" `
    -Method "POST" `
    -Body @{payment_ids=@("PAY001","PAY002")} `
    -Description "PCI compliance check"

Test-Endpoint -System "Compliance Guardian" `
    -Endpoint "/compliance/compliance-report?start_date=2024-01-01&end_date=2024-12-31" `
    -Method "GET" `
    -Description "Compliance report"

Test-Endpoint -System "Compliance Guardian" `
    -Endpoint "/compliance/fraud-statistics?days=30" `
    -Method "GET" `
    -Description "Fraud statistics"

# System 4: Retail Copilot
Write-Host "`n=== System 4: Retail Copilot ===" -ForegroundColor Yellow

Test-Endpoint -System "Retail Copilot" `
    -Endpoint "/retail-copilot/chat" `
    -Method "POST" `
    -Body @{user_id="USER001"; message="What are the top 5 selling products this month?"} `
    -Description "Chat interaction"

Test-Endpoint -System "Retail Copilot" `
    -Endpoint "/retail-copilot/conversations?user_id=USER001&limit=10" `
    -Method "GET" `
    -Description "List conversations"

Test-Endpoint -System "Retail Copilot" `
    -Endpoint "/retail-copilot/inventory" `
    -Method "POST" `
    -Body @{user_id="USER001"; question="Show me products with low stock levels"} `
    -Description "Inventory query"

Test-Endpoint -System "Retail Copilot" `
    -Endpoint "/retail-copilot/orders" `
    -Method "POST" `
    -Body @{user_id="USER001"; question="What is the average order value this quarter?"} `
    -Description "Order analysis"

Test-Endpoint -System "Retail Copilot" `
    -Endpoint "/retail-copilot/customers" `
    -Method "POST" `
    -Body @{user_id="USER001"; question="Who are our top 10 customers by revenue?"} `
    -Description "Customer query"

Test-Endpoint -System "Retail Copilot" `
    -Endpoint "/retail-copilot/recommendations" `
    -Method "POST" `
    -Body @{customer_id="CUST001"; limit=5} `
    -Description "Product recommendations"

Test-Endpoint -System "Retail Copilot" `
    -Endpoint "/retail-copilot/sales-report" `
    -Method "POST" `
    -Body @{start_date="2024-01-01"; end_date="2024-12-31"; group_by="month"} `
    -Description "Sales report"

# System 5: Global Market Pulse
Write-Host "`n=== System 5: Global Market Pulse ===" -ForegroundColor Yellow

Test-Endpoint -System "Global Market Pulse" `
    -Endpoint "/global-market/trends?product_id=PROD001&days=180" `
    -Method "GET" `
    -Description "Market trends"

Test-Endpoint -System "Global Market Pulse" `
    -Endpoint "/global-market/regional-prices?product_id=PROD001" `
    -Method "GET" `
    -Description "Regional prices"

Test-Endpoint -System "Global Market Pulse" `
    -Endpoint "/global-market/price-comparison" `
    -Method "POST" `
    -Body @{product_id="PROD001"; regions=@("North America","Europe","Asia")} `
    -Description "Price comparison"

Test-Endpoint -System "Global Market Pulse" `
    -Endpoint "/global-market/opportunities" `
    -Method "POST" `
    -Body @{regions=@("North America","Europe","Asia","Latin America"); weights=@{market_size=0.25;growth_rate=0.25;competition=0.20;price_premium=0.15;maturity=0.15}} `
    -Description "Market opportunities"

Test-Endpoint -System "Global Market Pulse" `
    -Endpoint "/global-market/competitor-analysis" `
    -Method "POST" `
    -Body @{region="North America"; category="Electronics"} `
    -Description "Competitor analysis"

Test-Endpoint -System "Global Market Pulse" `
    -Endpoint "/global-market/market-share?region=North America&category=Electronics" `
    -Method "GET" `
    -Description "Market share"

Test-Endpoint -System "Global Market Pulse" `
    -Endpoint "/global-market/growth-rates?category=Electronics" `
    -Method "GET" `
    -Description "Growth rates"

Test-Endpoint -System "Global Market Pulse" `
    -Endpoint "/global-market/trend-changes" `
    -Method "POST" `
    -Body @{product_id="PROD001"; days=365} `
    -Description "Trend changes"

# Summary
Write-Host "`n========================================" -ForegroundColor Yellow
Write-Host "Verification Summary" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Yellow

$totalTests = $results.Count
$passedTests = ($results | Where-Object {$_.Status -eq "PASS"}).Count
$failedTests = ($results | Where-Object {$_.Status -eq "FAIL"}).Count
$avgDuration = ($results | Measure-Object -Property Duration -Average).Average

Write-Host "`nTotal Tests: $totalTests"
Write-Host "Passed: $passedTests" -ForegroundColor Green
Write-Host "Failed: $failedTests" -ForegroundColor $(if ($failedTests -gt 0) {"Red"} else {"Green"})
Write-Host "Average Response Time: $([math]::Round($avgDuration, 2))s"

# Group by system
Write-Host "`n--- Results by System ---"
$results | Group-Object System | ForEach-Object {
    $systemPassed = ($_.Group | Where-Object {$_.Status -eq "PASS"}).Count
    $systemTotal = $_.Group.Count
    $systemAvgDuration = ($_.Group | Measure-Object -Property Duration -Average).Average
    
    Write-Host "`n$($_.Name): $systemPassed/$systemTotal passed (avg ${systemAvgDuration}s)"
    
    $_.Group | Where-Object {$_.Status -eq "FAIL"} | ForEach-Object {
        Write-Host "  [FAIL] $($_.Description): $($_.Error)" -ForegroundColor Red
    }
}

# Export results
$resultsFile = "verification-results-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
$results | ConvertTo-Json -Depth 10 | Out-File $resultsFile
Write-Host "`nResults exported to: $resultsFile" -ForegroundColor Cyan

# Exit code
if ($failedTests -gt 0) {
    Write-Host "`n[VERIFICATION FAILED] Some tests did not pass." -ForegroundColor Red
    exit 1
} else {
    Write-Host "`n[VERIFICATION PASSED] All systems operational!" -ForegroundColor Green
    exit 0
}
