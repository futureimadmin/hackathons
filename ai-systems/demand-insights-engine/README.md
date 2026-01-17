# Demand Insights Engine

AI-powered customer insights, demand forecasting, and pricing intelligence system for eCommerce platforms.

## Overview

The Demand Insights Engine provides comprehensive analytics for understanding customer behavior, predicting demand, optimizing pricing, and identifying at-risk customers. It uses machine learning models to deliver actionable insights that drive revenue growth and customer retention.

## Features

### 1. Customer Segmentation
- **K-Means Clustering**: Automatically segments customers into meaningful groups
- **RFM Analysis**: Recency, Frequency, Monetary value analysis
- **Optimal Cluster Detection**: Uses elbow method and silhouette score
- **Segment Profiling**: Descriptive names and characteristics for each segment

### 2. Demand Forecasting
- **XGBoost Model**: Gradient boosting for accurate demand predictions
- **Feature Engineering**: Time-based, lag, rolling statistics, and price features
- **Seasonality Detection**: Cyclical encoding for seasonal patterns
- **Feature Importance**: Identifies key drivers of demand

### 3. Price Elasticity Analysis
- **Elasticity Calculation**: Measures demand sensitivity to price changes
- **Revenue Optimization**: Recommends optimal pricing for maximum revenue
- **Sensitivity Analysis**: Analyzes demand across different price points
- **Confidence Intervals**: Statistical confidence in elasticity estimates

### 4. Customer Lifetime Value (CLV) Prediction
- **Random Forest Model**: Predicts long-term customer value
- **Behavioral Features**: Purchase patterns, engagement, satisfaction
- **CLV Segmentation**: Groups customers by value potential
- **Simple CLV Formula**: Quick estimates using standard metrics

### 5. Churn Prediction
- **Gradient Boosting Classifier**: Identifies at-risk customers
- **Risk Scoring**: Probability-based risk levels (Low, Medium, High, Critical)
- **Churn Factors**: Identifies key indicators of churn
- **Proactive Retention**: Early warning system for customer loss

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    API Gateway                               │
│  /demand-insights/segments                                   │
│  /demand-insights/forecast                                   │
│  /demand-insights/price-elasticity                          │
│  /demand-insights/price-optimization                        │
│  /demand-insights/clv                                       │
│  /demand-insights/churn                                     │
│  /demand-insights/at-risk-customers                         │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│              Lambda Handler (handler.py)                     │
│  - Routes requests to appropriate models                     │
│  - Manages model lifecycle and caching                       │
│  - Handles authentication and error responses                │
└────────────────────┬────────────────────────────────────────┘
                     │
        ┌────────────┼────────────┐
        │            │            │
        ▼            ▼            ▼
┌──────────────┐ ┌──────────────┐ ┌──────────────┐
│ Segmentation │ │  Forecasting │ │    Pricing   │
│    Models    │ │    Models    │ │    Models    │
└──────┬───────┘ └──────┬───────┘ └──────┬───────┘
       │                │                │
       └────────────────┼────────────────┘
                        │
                        ▼
                ┌──────────────┐
                │ Athena Client│
                │ (Data Access)│
                └──────┬───────┘
                       │
                       ▼
                ┌──────────────┐
                │  AWS Athena  │
                │  (S3 Queries)│
                └──────────────┘
```

## API Endpoints

### Customer Segmentation
```http
GET /demand-insights/segments?n_clusters=5
Authorization: Bearer <jwt_token>
```

**Response:**
```json
{
  "segments": [
    {
      "segment": "Champions",
      "count": 1250,
      "percentage": 12.5,
      "avg_recency": 15,
      "avg_frequency": 25,
      "avg_monetary": 5000
    }
  ],
  "total_customers": 10000,
  "n_clusters": 5
}
```

### Demand Forecasting
```http
POST /demand-insights/forecast
Authorization: Bearer <jwt_token>
Content-Type: application/json

{
  "product_id": "PROD-123",
  "forecast_days": 30
}
```

**Response:**
```json
{
  "forecast": [
    {
      "date": "2026-02-15",
      "predicted_quantity": 1250,
      "confidence_lower": 1100,
      "confidence_upper": 1400
    }
  ],
  "feature_importance": [
    {"feature": "day_of_week", "importance": 0.25},
    {"feature": "price", "importance": 0.18}
  ],
  "forecast_days": 30
}
```

### Price Elasticity
```http
POST /demand-insights/price-elasticity
Authorization: Bearer <jwt_token>
Content-Type: application/json

{
  "product_id": "PROD-123"
}
```

**Response:**
```json
{
  "elasticity_coefficient": -1.5,
  "r_squared": 0.85,
  "elasticity_type": "Elastic",
  "interpretation": "Demand is highly sensitive to price changes",
  "price_range": {
    "min": 50.0,
    "max": 150.0,
    "mean": 99.99
  }
}
```

### Price Optimization
```http
POST /demand-insights/price-optimization
Authorization: Bearer <jwt_token>
Content-Type: application/json

{
  "product_id": "PROD-123",
  "current_price": 100.0,
  "current_quantity": 1000,
  "cost_per_unit": 60.0
}
```

**Response:**
```json
{
  "current_price": 100.0,
  "optimal_price": 120.0,
  "price_change_pct": 20.0,
  "recommendation": "Increase price",
  "estimated_impact": {
    "quantity_change_pct": -15.0,
    "revenue_change_pct": 2.0,
    "profit_change_pct": 5.5,
    "estimated_revenue": 102000
  }
}
```

### CLV Prediction
```http
POST /demand-insights/clv
Authorization: Bearer <jwt_token>
Content-Type: application/json

{
  "customer_ids": ["CUST-001", "CUST-002"]
}
```

**Response:**
```json
{
  "predictions": [
    {
      "customer_id": "CUST-001",
      "predicted_clv": 2500.0,
      "clv_segment": "High"
    }
  ],
  "segments": {
    "total_customers": 2,
    "avg_clv": 2000.0
  }
}
```

### Churn Prediction
```http
POST /demand-insights/churn
Authorization: Bearer <jwt_token>
Content-Type: application/json

{
  "customer_ids": ["CUST-001", "CUST-002"]
}
```

**Response:**
```json
{
  "predictions": [
    {
      "customer_id": "CUST-001",
      "churn_probability": 0.75,
      "risk_level": "High"
    }
  ],
  "summary": {
    "total_customers": 2,
    "at_risk_count": 1,
    "at_risk_percentage": 50.0
  }
}
```

### At-Risk Customers
```http
GET /demand-insights/at-risk-customers?threshold=0.6&limit=100
Authorization: Bearer <jwt_token>
```

**Response:**
```json
{
  "at_risk_customers": [
    {
      "customer_id": "CUST-001",
      "email": "customer@example.com",
      "churn_probability": 0.85,
      "recency_days": 120,
      "frequency": 2,
      "monetary_total": 500.0
    }
  ],
  "count": 1,
  "threshold": 0.6
}
```

## Machine Learning Models

### Customer Segmentation
- **Algorithm**: K-Means Clustering
- **Features**: RFM (Recency, Frequency, Monetary)
- **Optimization**: Elbow method + Silhouette score
- **Output**: Customer segments with profiles

### Demand Forecasting
- **Algorithm**: XGBoost Regressor
- **Features**: Time features, lag features, rolling statistics, price
- **Training**: Early stopping with validation set
- **Output**: Daily demand predictions with confidence intervals

### Price Elasticity
- **Algorithm**: Linear Regression (log-log model)
- **Formula**: log(Q) = a + b*log(P)
- **Coefficient**: b = price elasticity
- **Output**: Elasticity coefficient and optimal price

### CLV Prediction
- **Algorithm**: Random Forest Regressor
- **Features**: RFM, engagement, satisfaction, product diversity
- **Training**: 80/20 train-test split
- **Output**: Predicted lifetime value per customer

### Churn Prediction
- **Algorithm**: Gradient Boosting Classifier
- **Features**: Recency, frequency, engagement, satisfaction
- **Training**: Stratified train-test split
- **Output**: Churn probability and risk level

## Dependencies

```
boto3>=1.34.0
pandas>=2.0.0
numpy>=1.24.0
scikit-learn>=1.3.0
xgboost>=2.0.0
lightgbm>=4.0.0
scipy>=1.11.0
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
  --function-name demand-insights-engine \
  --zip-file fileb://deployment.zip
```

## Configuration

### Environment Variables

- `ATHENA_DATABASE`: Athena database name (default: `demand_insights_db`)
- `ATHENA_OUTPUT_LOCATION`: S3 location for query results
- `AWS_REGION`: AWS region (default: `us-east-1`)
- `LOG_LEVEL`: Logging level (default: `INFO`)

### Lambda Configuration

- **Runtime**: Python 3.11
- **Memory**: 3008 MB (3 GB)
- **Timeout**: 300 seconds (5 minutes)
- **Handler**: `handler.lambda_handler`

## Data Requirements

### Customer Data Schema
```sql
- customer_id: STRING
- email: STRING
- created_at: TIMESTAMP
- recency_days: INT
- frequency: INT
- monetary_total: DECIMAL
- customer_age_days: INT
```

### Sales Data Schema
```sql
- date: DATE
- product_id: STRING
- quantity: INT
- price: DECIMAL
- revenue: DECIMAL
```

## Performance Optimization

1. **Model Caching**: Models are cached across Lambda invocations
2. **Batch Processing**: Process multiple customers in single request
3. **Query Optimization**: Athena queries use partitioning and filtering
4. **Memory Allocation**: 3 GB memory for ML operations
5. **Connection Pooling**: Reuse Athena client connections

## Monitoring

### CloudWatch Metrics
- Lambda invocations
- Duration
- Errors
- Throttles
- Memory usage

### CloudWatch Logs
- Request/response logging
- Model training metrics
- Error stack traces
- Performance timings

### Recommended Alarms
- Error rate > 1%
- Duration > 4 minutes
- Throttles > 0
- Memory usage > 90%

## Testing

### Unit Tests
```bash
pytest tests/
```

### Integration Tests
```bash
pytest tests/integration/
```

### Load Testing
```bash
artillery run load-test.yml
```

## Troubleshooting

### Common Issues

**Issue**: Lambda timeout
- **Solution**: Increase timeout or reduce data volume

**Issue**: Out of memory
- **Solution**: Increase memory allocation or optimize model size

**Issue**: Athena query timeout
- **Solution**: Optimize query with partitioning and filtering

**Issue**: Cold start latency
- **Solution**: Use provisioned concurrency or keep Lambda warm

## Best Practices

1. **Data Quality**: Ensure clean, validated data in Athena
2. **Model Retraining**: Retrain models monthly with new data
3. **Feature Engineering**: Continuously improve feature sets
4. **Monitoring**: Set up comprehensive CloudWatch alarms
5. **Cost Optimization**: Use appropriate memory and timeout settings

## Requirements Validation

This implementation satisfies the following requirements:

- **16.1**: Customer segmentation with K-Means and RFM analysis ✓
- **16.2**: Demand forecasting by product category with XGBoost ✓
- **16.3**: Dynamic pricing recommendations with elasticity analysis ✓
- **16.4**: Customer lifetime value predictions with Random Forest ✓
- **16.5**: Churn prediction models with Gradient Boosting ✓
- **16.6**: Machine learning algorithms (Random Forest, XGBoost, Neural Networks) ✓
- **16.7**: Price elasticity analysis ✓
- **16.8**: Daily insights updates ✓

## License

Copyright © 2026 eCommerce AI Platform. All rights reserved.
