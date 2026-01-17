# Global Market Pulse

Global and regional market trend analysis system for identifying expansion opportunities, comparing regional prices, and analyzing competitor strategies.

## Overview

The Global Market Pulse provides comprehensive market intelligence across regions, helping businesses identify growth opportunities, understand pricing dynamics, and make data-driven expansion decisions.

## Features

### 1. Market Trend Analysis
- **Time Series Decomposition**: Separates trends, seasonality, and residuals
- **Trend Detection**: Identifies increasing, decreasing, or stable trends
- **Seasonality Analysis**: Detects and quantifies seasonal patterns
- **Stationarity Testing**: Augmented Dickey-Fuller test for time series stationarity
- **Growth Metrics**: CAGR, volatility, and period-over-period growth
- **Trend Change Detection**: Identifies significant breakpoints in trends

### 2. Regional Price Comparison
- **Multi-Currency Support**: Automatic currency conversion to USD
- **Statistical Significance**: T-tests and effect size calculations
- **Price Dispersion**: Coefficient of variation and Gini coefficient
- **Outlier Detection**: IQR-based outlier identification
- **Pairwise Comparisons**: Compare prices between all region pairs

### 3. Market Opportunity Scoring
- **MCDA Methodology**: Multi-Criteria Decision Analysis
- **Customizable Weights**: Adjust importance of different criteria
- **Normalized Scoring**: 0-100 scale for easy comparison
- **Opportunity Ranking**: Automatic ranking of markets
- **Sensitivity Analysis**: Test impact of weight changes
- **Scenario Comparison**: Compare different weighting strategies

### 4. Competitor Analysis
- **Pricing Strategies**: Identify uniform vs. regional pricing
- **Market Share**: Calculate HHI and market concentration
- **Price Positioning**: Budget, value, market, premium, luxury
- **Competitive Advantages**: Identify strengths by competitor
- **Regional Strategies**: Analyze competitor behavior by region

### 5. External Data Integration
- **API Ready**: Designed for external market data sources
- **Currency Exchange**: Real-time exchange rate support
- **Market Intelligence**: Combine internal and external data

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    API Gateway                               │
│  /global-market/trends                                       │
│  /global-market/regional-prices                              │
│  /global-market/price-comparison                             │
│  /global-market/opportunities                                │
│  /global-market/competitor-analysis                          │
│  /global-market/market-share                                 │
│  /global-market/growth-rates                                 │
│  /global-market/trend-changes                                │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│              Lambda Handler (handler.py)                     │
│  - Routes requests to analysis modules                       │
│  - Manages authentication and authorization                  │
│  - Handles error responses                                   │
└────────────────────┬────────────────────────────────────────┘
                     │
        ┌────────────┼────────────┬────────────┬────────────┐
        │            │            │            │            │
        ▼            ▼            ▼            ▼            ▼
┌──────────────┐ ┌──────────────┐ ┌──────────────┐ ┌──────────────┐ ┌──────────────┐
│    Trend     │ │   Regional   │ │ Opportunity  │ │  Competitor  │ │   Athena     │
│   Analyzer   │ │  Comparator  │ │   Scorer     │ │   Analyzer   │ │   Client     │
└──────┬───────┘ └──────┬───────┘ └──────┬───────┘ └──────┬───────┘ └──────┬───────┘
       │                │                │                │                │
       ▼                ▼                ▼                ▼                ▼
┌──────────────┐ ┌──────────────┐ ┌──────────────┐ ┌──────────────┐ ┌──────────────┐
│ Time Series  │ │ Statistical  │ │     MCDA     │ │ Market Share │ │ AWS Athena   │
│ Decomposition│ │    Tests     │ │   Scoring    │ │     HHI      │ │ (S3 Queries) │
└──────────────┘ └──────────────┘ └──────────────┘ └──────────────┘ └──────────────┘
```

## API Endpoints

### Market Trends
```http
GET /global-market/trends?region=USA&days=90
Authorization: Bearer <jwt_token>
```

**Response:**
```json
{
  "analysis": {
    "decomposition": {
      "trend": [...],
      "seasonal": [...],
      "residual": [...]
    },
    "trend": {
      "direction": "increasing",
      "strength": 0.85,
      "percentage_change": 15.3
    },
    "seasonality": {
      "has_seasonality": true,
      "amplitude": 1250.5
    },
    "growth_metrics": {
      "total_growth_pct": 15.3,
      "cagr_pct": 5.2,
      "volatility_pct": 8.1
    }
  },
  "data_points": 90,
  "region": "USA",
  "period_days": 90
}
```

### Regional Prices
```http
GET /global-market/regional-prices?limit=1000
Authorization: Bearer <jwt_token>
```

**Response:**
```json
{
  "prices": [
    {
      "product_id": "PROD-001",
      "product_name": "Widget A",
      "price": 29.99,
      "currency": "USD",
      "region": "USA",
      "order_count": 150
    }
  ],
  "count": 1000
}
```

### Price Comparison
```http
POST /global-market/price-comparison
Authorization: Bearer <jwt_token>
Content-Type: application/json

{
  "product_ids": ["PROD-001", "PROD-002"]
}
```

**Response:**
```json
{
  "regional_statistics": [
    {
      "region": "USA",
      "mean_price": 32.50,
      "median_price": 31.99,
      "std_dev": 5.20,
      "count": 150
    }
  ],
  "pairwise_comparisons": [
    {
      "region1": "USA",
      "region2": "Canada",
      "price_difference": 2.50,
      "price_difference_pct": 8.3,
      "is_significant": true,
      "effect_size": "medium"
    }
  ],
  "price_dispersion": {
    "overall_mean": 30.25,
    "coefficient_of_variation": 0.18,
    "gini_coefficient": 0.15
  }
}
```

### Market Opportunities
```http
POST /global-market/opportunities
Authorization: Bearer <jwt_token>
Content-Type: application/json

{
  "weights": {
    "market_size": 0.25,
    "growth_rate": 0.25,
    "competition_level": 0.20,
    "price_premium": 0.15,
    "market_maturity": 0.15
  },
  "top_n": 10
}
```

**Response:**
```json
{
  "opportunities": [
    {
      "region": "India",
      "opportunity_score": 87.5,
      "rank": 1,
      "category": "Excellent",
      "market_size": 15000,
      "growth_rate": 25.3,
      "competition_level": 35
    }
  ],
  "total_regions": 50,
  "weights_used": {...}
}
```

### Competitor Analysis
```http
POST /global-market/competitor-analysis
Authorization: Bearer <jwt_token>
Content-Type: application/json

{
  "region": "USA",
  "analysis_type": "pricing"
}
```

**Response:**
```json
{
  "competitor_statistics": [
    {
      "competitor": "Competitor A",
      "avg_price": 28.50,
      "regions_present": 15,
      "total_products": 250
    }
  ],
  "price_leaders": {
    "overall": {
      "lowest_price_competitor": "Competitor B",
      "lowest_avg_price": 25.99
    }
  },
  "price_positioning": [
    {
      "competitor": "Competitor A",
      "positioning": "Value",
      "difference_pct": -7.5
    }
  ]
}
```

### Market Share
```http
GET /global-market/market-share?region=USA
Authorization: Bearer <jwt_token>
```

**Response:**
```json
{
  "overall_market_share": [
    {
      "competitor": "Competitor A",
      "market_share_pct": 35.2,
      "total_sales": 1250000
    }
  ],
  "market_concentration": {
    "hhi": 1850,
    "interpretation": "Moderate"
  }
}
```

### Growth Rates
```http
GET /global-market/growth-rates?days=180
Authorization: Bearer <jwt_token>
```

**Response:**
```json
{
  "growth_rates": [
    {
      "region": "India",
      "avg_growth_rate": 25.3,
      "total_revenue": 5250000,
      "months_count": 6
    }
  ],
  "count": 50,
  "period_days": 180
}
```

### Trend Changes
```http
POST /global-market/trend-changes
Authorization: Bearer <jwt_token>
Content-Type: application/json

{
  "region": "USA",
  "days": 90,
  "window": 7
}
```

**Response:**
```json
{
  "trend_changes": [
    {
      "date": "2026-01-10",
      "before_mean": 125000,
      "after_mean": 145000,
      "change_pct": 16.0,
      "z_score": 2.5,
      "significance": "medium"
    }
  ],
  "changes_detected": 3,
  "period_days": 90
}
```

## Scoring Methodology

### MCDA (Multi-Criteria Decision Analysis)

The opportunity scoring uses MCDA with the following default criteria:

1. **Market Size** (25%): Total addressable market
2. **Growth Rate** (25%): Historical growth trajectory
3. **Competition Level** (20%): Market concentration (inverse)
4. **Price Premium** (15%): Ability to command higher prices
5. **Market Maturity** (15%): Stage in market lifecycle (inverse)

**Scoring Process:**
1. Normalize each criterion to 0-1 scale
2. Apply weights to normalized values
3. Sum weighted values and scale to 0-100
4. Categorize: Excellent (80+), Good (60-79), Moderate (40-59), Low (20-39), Very Low (<20)

### Statistical Tests

- **T-Test**: Compare means between regions (p < 0.05 for significance)
- **Cohen's d**: Effect size (small: 0.2-0.5, medium: 0.5-0.8, large: >0.8)
- **ADF Test**: Stationarity testing (p < 0.05 indicates stationarity)
- **HHI**: Market concentration (< 1500: competitive, 1500-2500: moderate, > 2500: concentrated)

## Dependencies

```
boto3>=1.34.0
pandas>=2.0.0
numpy>=1.24.0
scipy>=1.11.0
statsmodels>=0.14.0
```

## Deployment

### Build Deployment Package

```powershell
# Windows
.\build.ps1
```

```bash
# Linux/Mac
chmod +x build.sh
./build.sh
```

### Deploy with Terraform

```bash
cd ../../terraform
terraform init
terraform plan
terraform apply
```

### Manual Deployment

```bash
aws lambda update-function-code \
  --function-name global-market-pulse \
  --zip-file fileb://deployment.zip
```

## Configuration

### Environment Variables

- `ATHENA_DATABASE`: Athena database name (default: `global_market_db`)
- `ATHENA_OUTPUT_LOCATION`: S3 location for query results
- `AWS_REGION`: AWS region (default: `us-east-1`)
- `LOG_LEVEL`: Logging level (default: `INFO`)

### Lambda Configuration

- **Runtime**: Python 3.11
- **Memory**: 1024 MB (1 GB)
- **Timeout**: 300 seconds (5 minutes)
- **Handler**: `handler.lambda_handler`

## Currency Support

Supported currencies with exchange rates (USD as base):
- USD (1.0)
- EUR (1.08)
- GBP (1.27)
- JPY (0.0067)
- CNY (0.14)
- INR (0.012)
- CAD (0.74)
- AUD (0.66)
- BRL (0.20)
- MXN (0.058)

## Best Practices

1. **Data Freshness**: Update market data daily for accurate trends
2. **Weight Tuning**: Adjust MCDA weights based on business priorities
3. **Regional Context**: Consider local market conditions in analysis
4. **Currency Updates**: Refresh exchange rates regularly
5. **Outlier Investigation**: Investigate price outliers for data quality

## Troubleshooting

### Common Issues

**Issue**: No trend data found
- **Solution**: Check date range, verify data in Athena tables

**Issue**: Insufficient data points for decomposition
- **Solution**: Increase date range (minimum 14 days recommended)

**Issue**: Weights don't sum to 1.0
- **Solution**: Ensure custom weights sum to exactly 1.0

**Issue**: Currency conversion errors
- **Solution**: Verify currency codes match supported currencies

**Issue**: Lambda timeout
- **Solution**: Increase timeout, reduce data volume, optimize queries

## Requirements Validation

This implementation satisfies the following requirements:

- **19.1**: Global market trend dashboards ✓
- **19.2**: Regional price comparison analysis ✓
- **19.3**: Currency exchange impact analysis ✓
- **19.4**: Market entry opportunity scoring ✓
- **19.5**: Competitor analysis across regions ✓
- **19.6**: External market data integration (API ready) ✓
- **19.7**: Geospatial visualizations (data provided) ✓
- **19.8**: Daily market data updates ✓

## Additional Features

- **Time Series Decomposition**: Trend, seasonal, residual components
- **Statistical Significance**: T-tests, effect sizes, confidence intervals
- **MCDA Scoring**: Customizable multi-criteria decision analysis
- **Market Concentration**: HHI calculation and interpretation
- **Sensitivity Analysis**: Test impact of weight changes
- **Trend Change Detection**: Identify significant breakpoints
- **Price Positioning**: Budget to luxury categorization
- **Growth Metrics**: CAGR, volatility, period-over-period growth

## License

Copyright © 2026 eCommerce AI Platform. All rights reserved.
