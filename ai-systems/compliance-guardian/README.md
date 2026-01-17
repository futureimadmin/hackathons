# Compliance Guardian

AI-powered fraud detection, risk scoring, and PCI DSS compliance monitoring system for eCommerce platforms.

## Overview

The Compliance Guardian provides comprehensive security and compliance capabilities for eCommerce transactions. It uses machine learning models to detect fraudulent activity, score transaction risk, ensure PCI DSS compliance, and analyze compliance documents using NLP.

## Features

### 1. Fraud Detection
- **Isolation Forest**: Anomaly detection for fraudulent transactions
- **Feature Engineering**: Transaction, customer, behavioral, geographic, and velocity features
- **Fraud Probability**: Risk levels (Low, Medium, High, Critical)
- **Pattern Analysis**: Identifies common fraud patterns and feature importance

### 2. Risk Scoring
- **Gradient Boosting**: Comprehensive risk scoring (0-100 scale)
- **30+ Risk Factors**: Transaction, customer, geographic, time-based, payment method, merchant, velocity, device, and compliance factors
- **Risk Classification**: Low, Medium, High, Critical levels
- **High-Risk Flagging**: Automatic identification of high-risk transactions

### 3. PCI DSS Compliance
- **Credit Card Masking**: Shows first 6 and last 4 digits only
- **CVV Protection**: Never stores CVV after authorization
- **Card Validation**: Luhn algorithm for card number validation
- **Encryption Compliance**: Checks data encryption requirements
- **Access Control**: Monitors access to payment data
- **Compliance Reports**: Comprehensive PCI DSS compliance reporting

### 4. Document Understanding (NLP)
- **Transformer Models**: BERT/RoBERTa for document analysis
- **Entity Extraction**: Identifies key entities in compliance documents
- **Document Classification**: Categorizes document types
- **Compliance Validation**: Ensures documents meet regulatory requirements

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    API Gateway                               │
│  /compliance/fraud-detection                                 │
│  /compliance/risk-score                                      │
│  /compliance/high-risk-transactions                          │
│  /compliance/pci-compliance                                  │
│  /compliance/compliance-report                               │
│  /compliance/fraud-statistics                                │
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
│    Fraud     │ │     Risk     │ │     PCI      │
│  Detection   │ │   Scoring    │ │  Compliance  │
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

### Fraud Detection
```http
POST /compliance/fraud-detection
Authorization: Bearer <jwt_token>
Content-Type: application/json

{
  "transaction_ids": ["TXN-001", "TXN-002"],
  "days": 7
}
```

**Response:**
```json
{
  "predictions": [
    {
      "transaction_id": "TXN-001",
      "fraud_probability": 0.85,
      "fraud_risk_level": "High",
      "is_anomaly": true
    }
  ],
  "fraudulent_transactions": [
    {
      "transaction_id": "TXN-001",
      "fraud_probability": 0.85,
      "amount": 5000.0
    }
  ],
  "patterns": {
    "total_transactions": 1000,
    "anomalies_detected": 25,
    "anomaly_rate": 2.5,
    "avg_fraud_probability": 0.15
  }
}
```

### Risk Scoring
```http
POST /compliance/risk-score
Authorization: Bearer <jwt_token>
Content-Type: application/json

{
  "transaction_ids": ["TXN-001"],
  "days": 7
}
```

**Response:**
```json
{
  "risk_scores": [
    {
      "transaction_id": "TXN-001",
      "risk_score": 85,
      "risk_level": "Critical",
      "is_high_risk": true
    }
  ],
  "high_risk_transactions": [
    {
      "transaction_id": "TXN-001",
      "risk_score": 85,
      "amount": 5000.0
    }
  ],
  "distribution": {
    "Low": 750,
    "Medium": 200,
    "High": 40,
    "Critical": 10
  }
}
```

### High-Risk Transactions
```http
GET /compliance/high-risk-transactions?days=7&threshold=70&limit=100
Authorization: Bearer <jwt_token>
```

**Response:**
```json
{
  "high_risk_transactions": [
    {
      "transaction_id": "TXN-001",
      "customer_id": "CUST-001",
      "amount": 5000.0,
      "risk_score": 85,
      "risk_level": "Critical"
    }
  ],
  "count": 1,
  "threshold": 70
}
```

### PCI DSS Compliance
```http
POST /compliance/pci-compliance
Authorization: Bearer <jwt_token>
Content-Type: application/json

{
  "transaction_ids": ["TXN-001", "TXN-002"]
}
```

**Response:**
```json
{
  "compliance_report": {
    "total_records": 2,
    "compliant_records": 2,
    "non_compliant_records": 0,
    "compliance_rate": 100.0,
    "issues": [],
    "card_masking_compliant": true,
    "cvv_storage_compliant": true,
    "encryption_compliant": true,
    "access_control_compliant": true
  },
  "sample_data": [
    {
      "transaction_id": "TXN-001",
      "masked_card_number": "411111******1111",
      "cvv_stored": false
    }
  ]
}
```

### Compliance Report
```http
GET /compliance/compliance-report?days=30
Authorization: Bearer <jwt_token>
```

**Response:**
```json
{
  "pci_compliance": {
    "compliance_rate": 99.5,
    "issues": []
  },
  "fraud_analysis": {
    "anomaly_rate": 2.5,
    "avg_fraud_probability": 0.15
  },
  "risk_analysis": {
    "Low": 750,
    "Medium": 200,
    "High": 40,
    "Critical": 10
  },
  "report_period_days": 30
}
```

### Fraud Statistics
```http
GET /compliance/fraud-statistics?days=30
Authorization: Bearer <jwt_token>
```

**Response:**
```json
{
  "summary": {
    "total_transactions": 10000,
    "total_amount": 500000.0,
    "total_flagged": 250,
    "total_flagged_amount": 125000.0,
    "fraud_rate": 2.5,
    "avg_risk_score": 35.5
  },
  "daily_statistics": [
    {
      "date": "2026-01-15",
      "total_transactions": 350,
      "flagged_transactions": 8
    }
  ]
}
```

## Machine Learning Models

### Fraud Detection
- **Algorithm**: Isolation Forest
- **Features**: Transaction amount, customer age, velocity, geographic, behavioral
- **Contamination**: 0.1 (10% expected anomalies)
- **Output**: Fraud probability and risk level

### Risk Scoring
- **Algorithm**: Gradient Boosting Classifier
- **Features**: 30+ risk factors across multiple categories
- **Score Range**: 0-100
- **Thresholds**: Low (<40), Medium (40-60), High (60-80), Critical (>80)

### PCI DSS Compliance
- **Card Masking**: First 6 + Last 4 digits
- **CVV Protection**: Never stored after authorization
- **Luhn Validation**: Card number checksum validation
- **Encryption**: AES-256 for sensitive data

### Document Understanding
- **Model**: BERT/RoBERTa transformer
- **Tasks**: Entity extraction, document classification
- **Languages**: English (primary), multilingual support
- **Output**: Entities, document type, compliance status

## Dependencies

```
boto3>=1.34.0
pandas>=2.0.0
numpy>=1.24.0
scikit-learn>=1.3.0
xgboost>=2.0.0
transformers>=4.35.0
torch>=2.1.0
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
  --function-name compliance-guardian \
  --zip-file fileb://deployment.zip
```

## Configuration

### Environment Variables

- `ATHENA_DATABASE`: Athena database name (default: `compliance_db`)
- `ATHENA_OUTPUT_LOCATION`: S3 location for query results
- `AWS_REGION`: AWS region (default: `us-east-1`)
- `LOG_LEVEL`: Logging level (default: `INFO`)

### Lambda Configuration

- **Runtime**: Python 3.11
- **Memory**: 3008 MB (3 GB)
- **Timeout**: 300 seconds (5 minutes)
- **Handler**: `handler.lambda_handler`

## Data Requirements

### Transaction Data Schema
```sql
- transaction_id: STRING
- customer_id: STRING
- amount: DECIMAL
- timestamp: TIMESTAMP
- payment_method: STRING
- merchant_id: STRING
- country: STRING
- device_id: STRING
- ip_address: STRING
- customer_age_days: INT
- previous_transactions: INT
- avg_transaction_amount: DECIMAL
- transactions_last_hour: INT
- transactions_last_day: INT
- failed_attempts_last_day: INT
```

### Payment Data Schema
```sql
- transaction_id: STRING
- card_number: STRING (encrypted)
- cvv: STRING (should not be stored)
- expiry_date: STRING
- cardholder_name: STRING
- billing_address: STRING
```

## Performance Optimization

1. **Model Caching**: Models are cached across Lambda invocations
2. **Batch Processing**: Process multiple transactions in single request
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
- Fraud detection rate
- Risk score distribution

### CloudWatch Logs
- Request/response logging
- Model training metrics
- Error stack traces
- Performance timings
- Compliance violations

### Recommended Alarms
- Error rate > 1%
- Duration > 4 minutes
- Throttles > 0
- Memory usage > 90%
- Fraud rate > 5%
- High-risk transactions > 10%

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

**Issue**: Transformer model loading slow
- **Solution**: Use smaller model or cache model in /tmp

## Best Practices

1. **Data Quality**: Ensure clean, validated data in Athena
2. **Model Retraining**: Retrain models monthly with new fraud patterns
3. **Feature Engineering**: Continuously improve feature sets
4. **Monitoring**: Set up comprehensive CloudWatch alarms
5. **Cost Optimization**: Use appropriate memory and timeout settings
6. **Security**: Never log sensitive payment data
7. **Compliance**: Regular PCI DSS audits and updates

## Requirements Validation

This implementation satisfies the following requirements:

- **17.1**: PCI DSS compliance monitoring ✓
- **17.2**: Fraud detection models with Isolation Forest ✓
- **17.3**: Transaction risk scoring with Gradient Boosting ✓
- **17.4**: Document understanding using NLP with transformers ✓
- **17.5**: Compliance report generation ✓
- **17.6**: Anomaly detection algorithms ✓
- **17.7**: Real-time alerts on high-risk transactions ✓
- **17.8**: Audit logs for all compliance checks ✓

## License

Copyright © 2026 eCommerce AI Platform. All rights reserved.
