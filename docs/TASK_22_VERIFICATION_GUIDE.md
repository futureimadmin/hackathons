# Task 22: Verify All AI Systems - Verification Guide

## Overview

This guide provides comprehensive verification procedures for all 5 AI systems implemented in Phase 5. Each system has specific endpoints, expected behaviors, and validation criteria.

## Prerequisites

Before starting verification:

1. ✅ All Terraform infrastructure deployed
2. ✅ Lambda functions deployed and active
3. ✅ API Gateway configured with endpoints
4. ✅ DMS replication running (data in S3)
5. ✅ Glue Crawlers executed (Athena tables available)
6. ✅ Valid JWT token for authentication

## Quick Start

```powershell
# Run automated verification script
.\verify-ai-systems.ps1 -ApiUrl "https://your-api-gateway-url" -Token "your-jwt-token"
```

## System 1: Market Intelligence Hub

### Endpoints to Test

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/market-intelligence/forecast` | POST | Generate sales forecasts |
| `/market-intelligence/trends` | GET | Analyze market trends |
| `/market-intelligence/pricing` | GET | Pricing analysis |
| `/market-intelligence/compare` | POST | Compare forecast models |

### Test Cases

#### 1.1 Forecast Generation
```powershell
$body = @{
    product_id = "PROD001"
    periods = 30
    model = "auto"
} | ConvertTo-Json

Invoke-RestMethod -Uri "$ApiUrl/market-intelligence/forecast" `
    -Method POST `
    -Headers @{Authorization="Bearer $Token"} `
    -Body $body `
    -ContentType "application/json"
```

**Expected Response**:
- Status: 200
- Contains: `forecast`, `confidence_intervals`, `model_used`, `metrics`
- Metrics: RMSE, MAE, MAPE, R²

#### 1.2 Trend Analysis
```powershell
Invoke-RestMethod -Uri "$ApiUrl/market-intelligence/trends?category=Electronics&days=90" `
    -Method GET `
    -Headers @{Authorization="Bearer $Token"}
```

**Expected Response**:
- Status: 200
- Contains: `trends`, `seasonality`, `growth_rate`

#### 1.3 Model Comparison
```powershell
$body = @{
    product_id = "PROD001"
    periods = 30
    models = @("arima", "prophet", "lstm")
} | ConvertTo-Json

Invoke-RestMethod -Uri "$ApiUrl/market-intelligence/compare" `
    -Method POST `
    -Headers @{Authorization="Bearer $Token"} `
    -Body $body `
    -ContentType "application/json"
```

**Expected Response**:
- Status: 200
- Contains: `comparison`, `best_model`, `metrics_by_model`

### Validation Criteria

- ✅ All endpoints return 200 status
- ✅ Forecast values are numeric and reasonable
- ✅ Confidence intervals are wider than point estimates
- ✅ RMSE/MAE/MAPE metrics are present
- ✅ Model selection logic works (auto mode)
- ✅ Response time < 30 seconds

---

## System 2: Demand Insights Engine

### Endpoints to Test

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/demand-insights/segments` | GET | Customer segmentation |
| `/demand-insights/forecast` | POST | Demand forecasting |
| `/demand-insights/elasticity` | POST | Price elasticity |
| `/demand-insights/optimization` | POST | Price optimization |
| `/demand-insights/clv` | POST | Customer lifetime value |
| `/demand-insights/churn` | POST | Churn prediction |
| `/demand-insights/at-risk` | GET | At-risk customers |

### Test Cases

#### 2.1 Customer Segmentation
```powershell
Invoke-RestMethod -Uri "$ApiUrl/demand-insights/segments?n_clusters=4" `
    -Method GET `
    -Headers @{Authorization="Bearer $Token"}
```

**Expected Response**:
- Status: 200
- Contains: `segments`, `cluster_centers`, `segment_sizes`
- 4 distinct segments with RFM characteristics

#### 2.2 Demand Forecasting
```powershell
$body = @{
    product_id = "PROD001"
    periods = 30
    include_features = @("seasonality", "promotions", "price")
} | ConvertTo-Json

Invoke-RestMethod -Uri "$ApiUrl/demand-insights/forecast" `
    -Method POST `
    -Headers @{Authorization="Bearer $Token"} `
    -Body $body `
    -ContentType "application/json"
```

**Expected Response**:
- Status: 200
- Contains: `forecast`, `feature_importance`, `metrics`

#### 2.3 Price Elasticity
```powershell
$body = @{
    product_id = "PROD001"
    price_range = @{min=50; max=150}
} | ConvertTo-Json

Invoke-RestMethod -Uri "$ApiUrl/demand-insights/elasticity" `
    -Method POST `
    -Headers @{Authorization="Bearer $Token"} `
    -Body $body `
    -ContentType "application/json"
```

**Expected Response**:
- Status: 200
- Contains: `elasticity_coefficient`, `demand_curve`, `revenue_impact`

#### 2.4 CLV Prediction
```powershell
$body = @{
    customer_ids = @("CUST001", "CUST002", "CUST003")
} | ConvertTo-Json

Invoke-RestMethod -Uri "$ApiUrl/demand-insights/clv" `
    -Method POST `
    -Headers @{Authorization="Bearer $Token"} `
    -Body $body `
    -ContentType "application/json"
```

**Expected Response**:
- Status: 200
- Contains: `clv_predictions`, `confidence_scores`

#### 2.5 Churn Prediction
```powershell
$body = @{
    customer_ids = @("CUST001", "CUST002")
} | ConvertTo-Json

Invoke-RestMethod -Uri "$ApiUrl/demand-insights/churn" `
    -Method POST `
    -Headers @{Authorization="Bearer $Token"} `
    -Body $body `
    -ContentType "application/json"
```

**Expected Response**:
- Status: 200
- Contains: `churn_predictions`, `churn_probability`, `risk_factors`

### Validation Criteria

- ✅ All endpoints return 200 status
- ✅ Segments have distinct RFM characteristics
- ✅ Elasticity coefficient is negative (normal goods)
- ✅ CLV predictions are positive
- ✅ Churn probabilities are between 0 and 1
- ✅ Response time < 30 seconds

---

## System 3: Compliance Guardian

### Endpoints to Test

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/compliance/fraud-detection` | POST | Detect fraudulent transactions |
| `/compliance/risk-score` | POST | Calculate risk scores |
| `/compliance/high-risk-transactions` | GET | List high-risk transactions |
| `/compliance/pci-compliance` | POST | PCI DSS compliance check |
| `/compliance/compliance-report` | GET | Generate compliance report |
| `/compliance/fraud-statistics` | GET | Fraud statistics |

### Test Cases

#### 3.1 Fraud Detection
```powershell
$body = @{
    transaction_ids = @("TXN001", "TXN002", "TXN003")
} | ConvertTo-Json

Invoke-RestMethod -Uri "$ApiUrl/compliance/fraud-detection" `
    -Method POST `
    -Headers @{Authorization="Bearer $Token"} `
    -Body $body `
    -ContentType "application/json"
```

**Expected Response**:
- Status: 200
- Contains: `fraud_scores`, `anomaly_flags`, `risk_level`
- Scores between -1 and 1 (Isolation Forest)

#### 3.2 Risk Scoring
```powershell
$body = @{
    transaction_ids = @("TXN001", "TXN002")
} | ConvertTo-Json

Invoke-RestMethod -Uri "$ApiUrl/compliance/risk-score" `
    -Method POST `
    -Headers @{Authorization="Bearer $Token"} `
    -Body $body `
    -ContentType "application/json"
```

**Expected Response**:
- Status: 200
- Contains: `risk_scores`, `risk_category` (Low/Medium/High/Critical)
- Scores between 0 and 100

#### 3.3 High-Risk Transactions
```powershell
Invoke-RestMethod -Uri "$ApiUrl/compliance/high-risk-transactions?threshold=70&limit=50" `
    -Method GET `
    -Headers @{Authorization="Bearer $Token"}
```

**Expected Response**:
- Status: 200
- Contains: `transactions`, `count`, `total_amount`
- All transactions have risk_score >= 70

#### 3.4 PCI Compliance Check
```powershell
$body = @{
    payment_ids = @("PAY001", "PAY002")
} | ConvertTo-Json

Invoke-RestMethod -Uri "$ApiUrl/compliance/pci-compliance" `
    -Method POST `
    -Headers @{Authorization="Bearer $Token"} `
    -Body $body `
    -ContentType "application/json"
```

**Expected Response**:
- Status: 200
- Contains: `compliance_status`, `violations`, `masked_data`
- Credit cards should be masked (****1234)

#### 3.5 Compliance Report
```powershell
Invoke-RestMethod -Uri "$ApiUrl/compliance/compliance-report?start_date=2024-01-01&end_date=2024-12-31" `
    -Method GET `
    -Headers @{Authorization="Bearer $Token"}
```

**Expected Response**:
- Status: 200
- Contains: `summary`, `fraud_rate`, `high_risk_count`, `pci_compliance_rate`

### Validation Criteria

- ✅ All endpoints return 200 status
- ✅ Fraud scores are within valid range
- ✅ Risk scores are 0-100
- ✅ High-risk transactions meet threshold
- ✅ Credit cards are properly masked
- ✅ Compliance report has all metrics
- ✅ Response time < 30 seconds

---

## System 4: Retail Copilot

### Endpoints to Test

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/retail-copilot/chat` | POST | Chat with copilot |
| `/retail-copilot/conversations` | GET | List conversations |
| `/retail-copilot/inventory` | POST | Inventory questions |
| `/retail-copilot/orders` | POST | Order questions |
| `/retail-copilot/customers` | POST | Customer questions |
| `/retail-copilot/recommendations` | POST | Product recommendations |
| `/retail-copilot/sales-report` | POST | Generate sales report |

### Test Cases

#### 4.1 Chat Interaction
```powershell
$body = @{
    user_id = "USER001"
    message = "What are the top 5 selling products this month?"
    conversation_id = $null
} | ConvertTo-Json

Invoke-RestMethod -Uri "$ApiUrl/retail-copilot/chat" `
    -Method POST `
    -Headers @{Authorization="Bearer $Token"} `
    -Body $body `
    -ContentType "application/json"
```

**Expected Response**:
- Status: 200
- Contains: `response`, `conversation_id`, `query_type`, `data`
- Response should be natural language
- Data should contain SQL results

#### 4.2 Inventory Query
```powershell
$body = @{
    user_id = "USER001"
    question = "Show me products with low stock levels"
} | ConvertTo-Json

Invoke-RestMethod -Uri "$ApiUrl/retail-copilot/inventory" `
    -Method POST `
    -Headers @{Authorization="Bearer $Token"} `
    -Body $body `
    -ContentType "application/json"
```

**Expected Response**:
- Status: 200
- Contains: `answer`, `data`, `sql_query`
- Data should have inventory records

#### 4.3 Order Analysis
```powershell
$body = @{
    user_id = "USER001"
    question = "What is the average order value this quarter?"
} | ConvertTo-Json

Invoke-RestMethod -Uri "$ApiUrl/retail-copilot/orders" `
    -Method POST `
    -Headers @{Authorization="Bearer $Token"} `
    -Body $body `
    -ContentType "application/json"
```

**Expected Response**:
- Status: 200
- Contains: `answer`, `data`, `sql_query`
- Answer should include numeric value

#### 4.4 Product Recommendations
```powershell
$body = @{
    customer_id = "CUST001"
    limit = 5
} | ConvertTo-Json

Invoke-RestMethod -Uri "$ApiUrl/retail-copilot/recommendations" `
    -Method POST `
    -Headers @{Authorization="Bearer $Token"} `
    -Body $body `
    -ContentType "application/json"
```

**Expected Response**:
- Status: 200
- Contains: `recommendations`, `reasoning`
- Up to 5 product recommendations

#### 4.5 Sales Report
```powershell
$body = @{
    start_date = "2024-01-01"
    end_date = "2024-12-31"
    group_by = "month"
} | ConvertTo-Json

Invoke-RestMethod -Uri "$ApiUrl/retail-copilot/sales-report" `
    -Method POST `
    -Headers @{Authorization="Bearer $Token"} `
    -Body $body `
    -ContentType "application/json"
```

**Expected Response**:
- Status: 200
- Contains: `report`, `summary`, `data`
- Monthly breakdown of sales

### Validation Criteria

- ✅ All endpoints return 200 status
- ✅ Chat responses are coherent and relevant
- ✅ SQL queries are valid and safe
- ✅ Conversation history is maintained
- ✅ Recommendations are personalized
- ✅ Reports contain accurate data
- ✅ Response time < 45 seconds (LLM calls)

---

## System 5: Global Market Pulse

### Endpoints to Test

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/global-market/trends` | GET | Market trend analysis |
| `/global-market/regional-prices` | GET | Regional pricing data |
| `/global-market/price-comparison` | POST | Statistical price comparison |
| `/global-market/opportunities` | POST | Market opportunity scoring |
| `/global-market/competitor-analysis` | POST | Competitor analysis |
| `/global-market/market-share` | GET | Market share with HHI |
| `/global-market/growth-rates` | GET | Regional growth rates |
| `/global-market/trend-changes` | POST | Trend breakpoint detection |

### Test Cases

#### 5.1 Market Trends
```powershell
Invoke-RestMethod -Uri "$ApiUrl/global-market/trends?product_id=PROD001&days=180" `
    -Method GET `
    -Headers @{Authorization="Bearer $Token"}
```

**Expected Response**:
- Status: 200
- Contains: `trend`, `seasonal`, `residual`, `statistics`
- Trend direction: "increasing", "decreasing", or "stable"

#### 5.2 Regional Prices
```powershell
Invoke-RestMethod -Uri "$ApiUrl/global-market/regional-prices?product_id=PROD001" `
    -Method GET `
    -Headers @{Authorization="Bearer $Token"}
```

**Expected Response**:
- Status: 200
- Contains: `regional_prices`, `currency`, `statistics`
- Multiple regions with prices

#### 5.3 Price Comparison
```powershell
$body = @{
    product_id = "PROD001"
    regions = @("North America", "Europe", "Asia")
} | ConvertTo-Json

Invoke-RestMethod -Uri "$ApiUrl/global-market/price-comparison" `
    -Method POST `
    -Headers @{Authorization="Bearer $Token"} `
    -Body $body `
    -ContentType "application/json"
```

**Expected Response**:
- Status: 200
- Contains: `comparisons`, `statistical_tests`, `effect_sizes`
- T-test results with p-values

#### 5.4 Market Opportunities
```powershell
$body = @{
    regions = @("North America", "Europe", "Asia", "Latin America")
    weights = @{
        market_size = 0.25
        growth_rate = 0.25
        competition = 0.20
        price_premium = 0.15
        maturity = 0.15
    }
} | ConvertTo-Json

Invoke-RestMethod -Uri "$ApiUrl/global-market/opportunities" `
    -Method POST `
    -Headers @{Authorization="Bearer $Token"} `
    -Body $body `
    -ContentType "application/json"
```

**Expected Response**:
- Status: 200
- Contains: `opportunities`, `scores`, `rankings`
- Scores between 0 and 100

#### 5.5 Competitor Analysis
```powershell
$body = @{
    region = "North America"
    category = "Electronics"
} | ConvertTo-Json

Invoke-RestMethod -Uri "$ApiUrl/global-market/competitor-analysis" `
    -Method POST `
    -Headers @{Authorization="Bearer $Token"} `
    -Body $body `
    -ContentType "application/json"
```

**Expected Response**:
- Status: 200
- Contains: `competitors`, `market_share`, `pricing_strategy`, `hhi`

#### 5.6 Market Share
```powershell
Invoke-RestMethod -Uri "$ApiUrl/global-market/market-share?region=North America&category=Electronics" `
    -Method GET `
    -Headers @{Authorization="Bearer $Token"}
```

**Expected Response**:
- Status: 200
- Contains: `market_share`, `hhi`, `concentration_level`
- HHI between 0 and 10,000

### Validation Criteria

- ✅ All endpoints return 200 status
- ✅ Trend decomposition is accurate
- ✅ Statistical tests have p-values
- ✅ Opportunity scores are 0-100
- ✅ HHI is calculated correctly
- ✅ Currency conversions are accurate
- ✅ Response time < 30 seconds

---

## Automated Verification Script

See `verify-ai-systems.ps1` for automated testing of all systems.

## Dashboard Verification

### Frontend Integration

1. **Navigate to each dashboard**:
   - Market Intelligence Hub
   - Demand Insights Engine
   - Compliance Guardian
   - Retail Copilot
   - Global Market Pulse

2. **Verify data display**:
   - Charts render correctly
   - Tables show data
   - No console errors
   - Loading states work

3. **Test interactions**:
   - Filters work
   - Date ranges update data
   - Export functionality works
   - Navigation is smooth

## Performance Benchmarks

| System | Endpoint | Expected Response Time |
|--------|----------|------------------------|
| Market Intelligence | Forecast | < 30s |
| Demand Insights | Segmentation | < 20s |
| Compliance Guardian | Fraud Detection | < 15s |
| Retail Copilot | Chat | < 45s |
| Global Market Pulse | Trends | < 20s |

## Common Issues and Solutions

### Issue 1: 401 Unauthorized
**Solution**: Verify JWT token is valid and not expired (1-hour expiry)

### Issue 2: 500 Internal Server Error
**Solution**: Check CloudWatch logs for Lambda errors

### Issue 3: Empty Data Response
**Solution**: Verify Glue Crawlers have run and Athena tables exist

### Issue 4: Slow Response Times
**Solution**: Check Lambda memory allocation and Athena query optimization

### Issue 5: Model Training Errors
**Solution**: Verify sufficient historical data exists (minimum 30 days)

## Success Criteria

Task 22 is complete when:

- ✅ All 5 systems respond to API calls
- ✅ All endpoints return expected data structures
- ✅ Response times meet benchmarks
- ✅ No critical errors in CloudWatch logs
- ✅ Dashboards display data correctly
- ✅ Model predictions are reasonable
- ✅ Statistical tests produce valid results
- ✅ Authentication works for all endpoints

## Next Steps

After Task 22 verification:

1. **Task 23**: Implement monitoring and logging
2. **Task 24**: Implement system registration
3. **Task 25**: Integration testing
4. **Task 26**: Performance testing
5. **Task 27**: Security testing

---

**Status**: Ready for Verification  
**Date**: January 16, 2026  
**Phase**: 6 (Integration and Testing)  
**Task**: 22 - Verify All AI Systems
