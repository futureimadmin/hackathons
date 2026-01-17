# Market Intelligence Hub

AI-powered market intelligence, forecasting, and competitive analytics system for eCommerce.

## Overview

The Market Intelligence Hub provides advanced time series forecasting and market analytics capabilities using multiple machine learning models. It automatically selects the best-performing model for your data and generates accurate forecasts with confidence intervals.

## Features

### 1. Multi-Model Forecasting
- **ARIMA**: AutoRegressive Integrated Moving Average for linear trends
- **Prophet**: Facebook's Prophet for seasonality and holidays
- **LSTM**: Long Short-Term Memory neural networks for complex patterns
- **Auto-Selection**: Automatically compares models and selects the best

### 2. Market Analytics
- Sales forecasting with confidence intervals
- Market trend analysis
- Competitive pricing intelligence
- Product and category-level insights

### 3. Performance Metrics
- RMSE (Root Mean Squared Error)
- MAE (Mean Absolute Error)
- MAPE (Mean Absolute Percentage Error)
- R² (Coefficient of Determination)
- Confidence interval coverage

## Architecture

```
┌─────────────────┐
│   API Gateway   │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Lambda Handler │
└────────┬────────┘
         │
    ┌────┴────┐
    │         │
    ▼         ▼
┌────────┐ ┌──────────┐
│ Athena │ │  Models  │
│ Client │ │ Selector │
└────────┘ └─────┬────┘
                 │
         ┌───────┼───────┐
         ▼       ▼       ▼
     ┌──────┐ ┌────────┐ ┌──────┐
     │ARIMA │ │Prophet │ │ LSTM │
     └──────┘ └────────┘ └──────┘
```

## Installation

### Prerequisites
- Python 3.11+
- AWS CLI configured
- Terraform (for infrastructure deployment)

### Install Dependencies

```bash
pip install -r requirements.txt
```

### Build Deployment Package

```powershell
# Windows
./build.ps1 -Region us-east-1 -AccountId YOUR_ACCOUNT_ID

# This creates market-intelligence-hub-lambda.zip
```

## Usage

### 1. Generate Forecast

```python
import requests

url = "https://api.example.com/market-intelligence/forecast"
headers = {"Authorization": "Bearer YOUR_JWT_TOKEN"}

payload = {
    "metric": "sales",
    "horizon": 30,
    "model": "auto",  # or "arima", "prophet", "lstm"
    "start_date": "2024-01-01",
    "end_date": "2025-01-15"
}

response = requests.post(url, json=payload, headers=headers)
forecast = response.json()

print(f"Best model: {forecast['model']}")
print(f"30-day forecast: {forecast['forecast']}")
print(f"RMSE: {forecast['evaluation_metrics']['rmse']}")
```

### 2. Compare Models

```python
payload = {
    "models": ["arima", "prophet", "lstm"],
    "start_date": "2024-01-01",
    "end_date": "2025-01-15"
}

response = requests.post(
    "https://api.example.com/market-intelligence/compare-models",
    json=payload,
    headers=headers
)

comparison = response.json()
print(f"Best model: {comparison['best_model']}")
print(comparison['comparison'])
```

### 3. Get Market Trends

```python
params = {
    "start_date": "2024-01-01",
    "end_date": "2025-01-15"
}

response = requests.get(
    "https://api.example.com/market-intelligence/trends",
    params=params,
    headers=headers
)

trends = response.json()
print(f"Found {trends['count']} trend records")
```

## Forecasting Models

### ARIMA (AutoRegressive Integrated Moving Average)

**Best for:**
- Linear trends
- Short-term forecasts
- Stationary or near-stationary data

**Parameters:**
- `p`: AR order (auto-selected)
- `d`: Differencing order (auto-selected)
- `q`: MA order (auto-selected)

**Example:**
```python
from forecasting import ARIMAForecaster

model = ARIMAForecaster(max_p=5, max_d=2, max_q=5)
model.fit(sales_series)
forecast = model.forecast(steps=30)
```

### Prophet

**Best for:**
- Seasonal patterns
- Holiday effects
- Long-term forecasts
- Multiple seasonality

**Features:**
- Automatic seasonality detection
- Handles missing data
- Robust to outliers

**Example:**
```python
from forecasting import ProphetForecaster

model = ProphetForecaster(
    yearly_seasonality=True,
    weekly_seasonality=True,
    seasonality_mode='multiplicative'
)
model.fit(sales_series)
forecast = model.forecast(steps=30)
```

### LSTM (Long Short-Term Memory)

**Best for:**
- Complex non-linear patterns
- Long-term dependencies
- Large datasets

**Architecture:**
- 2 LSTM layers (50 units each)
- Dropout regularization (0.2)
- Dense output layer

**Example:**
```python
from forecasting import LSTMForecaster

model = LSTMForecaster(
    lookback=30,
    lstm_units=50,
    epochs=50
)
model.fit(sales_series)
forecast = model.forecast(sales_series, steps=30)
```

### Model Selector

Automatically compares all models and selects the best:

```python
from forecasting import ModelSelector

selector = ModelSelector(test_size=0.2)
selector.evaluate_models(sales_series)

# Get best model
model_name, model = selector.get_best_model()

# Generate forecast with best model
forecast = selector.forecast_with_best_model(sales_series, steps=30)

# View comparison
comparison = selector.get_model_comparison()
print(comparison)
```

## Data Requirements

### Input Data Format

Time series data should be a pandas Series with datetime index:

```python
import pandas as pd

# Example
dates = pd.date_range('2024-01-01', '2025-01-15', freq='D')
sales = [100, 105, 98, ...]  # Your sales data
series = pd.Series(sales, index=dates)
```

### Minimum Data Requirements

- **ARIMA**: 50+ observations
- **Prophet**: 100+ observations (preferably 1+ year for seasonality)
- **LSTM**: 200+ observations

### Data Quality

- No missing values (or handle with interpolation)
- Consistent frequency (daily, weekly, monthly)
- Sufficient historical data for pattern detection

## Evaluation Metrics

### RMSE (Root Mean Squared Error)
- Measures average prediction error
- Same units as target variable
- Lower is better

### MAE (Mean Absolute Error)
- Average absolute difference
- Less sensitive to outliers than RMSE
- Lower is better

### MAPE (Mean Absolute Percentage Error)
- Percentage error metric
- Scale-independent
- Lower is better (< 10% is excellent)

### R² (Coefficient of Determination)
- Proportion of variance explained
- Range: 0 to 1
- Higher is better (> 0.8 is good)

## Configuration

### Environment Variables

```bash
ATHENA_DATABASE=market_intelligence_hub
ATHENA_STAGING_DIR=s3://athena-query-results-123456789012/
AWS_REGION_NAME=us-east-1
LOG_LEVEL=INFO
```

### Lambda Configuration

- **Memory**: 3008 MB (3 GB)
- **Timeout**: 300 seconds (5 minutes)
- **Runtime**: Python 3.11

## Performance

### Execution Times

| Operation | Cold Start | Warm |
|-----------|-----------|------|
| ARIMA Forecast | 15s | 5-10s |
| Prophet Forecast | 15s | 10-20s |
| LSTM Forecast | 20s | 15-30s |
| Model Comparison | 25s | 30-60s |

### Optimization Tips

1. **Use warm Lambda**: Keep function warm with scheduled pings
2. **Limit data size**: Query only necessary date ranges
3. **Cache results**: Store forecasts in DynamoDB for reuse
4. **Use layers**: Package large dependencies in Lambda layers

## Troubleshooting

### Common Issues

**1. "No data found for specified criteria"**
- Check date range
- Verify product_id or category_id exists
- Ensure data is in Athena tables

**2. "Model training failed"**
- Insufficient data points
- Data contains NaN values
- Check CloudWatch logs for details

**3. "Timeout error"**
- Reduce date range
- Increase Lambda timeout
- Use simpler model (ARIMA instead of LSTM)

### Debugging

Enable debug logging:
```python
import logging
logging.basicConfig(level=logging.DEBUG)
```

Check CloudWatch logs:
```bash
aws logs tail /aws/lambda/ecommerce-ai-platform-market-intelligence-hub --follow
```

## Testing

### Unit Tests

```bash
pytest tests/test_arima_forecaster.py
pytest tests/test_prophet_forecaster.py
pytest tests/test_lstm_forecaster.py
pytest tests/test_model_selector.py
```

### Integration Tests

```bash
pytest tests/test_handler.py
pytest tests/test_athena_client.py
```

## API Reference

See [Terraform Module README](../../terraform/modules/market-intelligence-lambda/README.md) for complete API documentation.

## Contributing

1. Follow PEP 8 style guide
2. Add unit tests for new features
3. Update documentation
4. Test with sample data before deployment

## License

Proprietary - eCommerce AI Platform

## Support

For issues or questions:
- Check CloudWatch logs
- Review troubleshooting section
- Contact platform team
