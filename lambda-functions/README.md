# Data Pipeline Lambda Functions

This directory contains Lambda functions that replace the AWS Batch-based data processing pipeline with a simpler, event-driven architecture.

## Architecture

```
MySQL → Export → Parquet
         ↓
1 Raw Bucket (ecommerce-raw-450133579764)
         ↓ [S3 Event Trigger]
Lambda: raw-to-curated
  - Validates data
  - Deduplicates records
  - Masks sensitive fields (PCI compliance)
         ↓
1 Curated Bucket (ecommerce-curated-450133579764)
         ↓ [S3 Event Trigger]
Lambda: curated-to-prod
  - Runs AI models (5 systems)
  - Generates analytics
  - Writes to system-specific prod buckets
         ↓
5 Prod Buckets (system-specific analytics)
├─ market-intelligence-hub-prod-450133579764
├─ demand-insights-engine-prod-450133579764
├─ compliance-guardian-prod-450133579764
├─ global-market-pulse-prod-450133579764
└─ retail-copilot-prod-450133579764
         ↓
Glue Crawlers → Athena Tables
         ↓
Frontend Queries via AI Lambda Functions
```

## Lambda Functions

### 1. raw-to-curated

**Trigger**: S3 ObjectCreated event on `ecommerce-raw-*` bucket  
**Runtime**: Python 3.11  
**Memory**: 3 GB  
**Timeout**: 15 minutes

**Functionality**:
- Reads Parquet files from raw bucket
- Validates data quality
- Deduplicates records based on primary keys
- Masks sensitive fields (card numbers, SSN, CVV)
- Writes validated data to curated bucket

### 2. curated-to-prod

**Trigger**: S3 ObjectCreated event on `ecommerce-curated-*` bucket  
**Runtime**: Python 3.11  
**Memory**: 3 GB  
**Timeout**: 15 minutes

**Functionality**:
- Loads all curated data
- Runs AI models for each system:
  - **Market Intelligence Hub**: Sales forecasting, trend analysis
  - **Demand Insights Engine**: Customer segmentation, CLV prediction, churn prediction
  - **Compliance Guardian**: Fraud detection, risk scoring
  - **Global Market Pulse**: Market opportunities, regional analysis
  - **Retail Copilot**: Query pattern analysis
- Writes analytics to system-specific prod buckets
- Triggers Glue Crawlers

## Deployment

### Prerequisites

- Python 3.11
- pip
- AWS CLI configured
- Terraform

### Steps

1. **Package Lambda functions**:
   ```powershell
   cd lambda-functions
   .\deploy-lambdas.ps1
   ```

2. **Deploy with Terraform**:
   ```powershell
   cd ../terraform
   terraform apply
   ```

3. **Test the pipeline**:
   ```powershell
   # Upload test data
   cd ../database
   .\quick-data-pipeline.ps1
   
   # Check Lambda logs
   aws logs tail /aws/lambda/futureim-ecommerce-ai-platform-raw-to-curated --follow
   ```

## Advantages over AWS Batch

1. **Simpler Architecture**: No Docker images, ECR, or Batch compute environments
2. **Native S3 Integration**: Direct S3 event triggers (no EventBridge needed)
3. **Faster Cold Starts**: Lambda starts in seconds vs. Batch in minutes
4. **Cost Effective**: Pay only for execution time
5. **Easier Debugging**: CloudWatch Logs integration
6. **Auto-scaling**: Lambda scales automatically

## Monitoring

### CloudWatch Logs

- Raw to Curated: `/aws/lambda/futureim-ecommerce-ai-platform-raw-to-curated`
- Curated to Prod: `/aws/lambda/futureim-ecommerce-ai-platform-curated-to-prod`

### Metrics

- Invocations
- Duration
- Errors
- Throttles

## Troubleshooting

### Lambda times out

- Increase memory (more memory = more CPU)
- Increase timeout (max 15 minutes)
- Optimize data processing (filter early, use efficient pandas operations)

### Out of memory errors

- Increase memory size in Terraform
- Process data in chunks
- Use pandas optimizations (categorical dtypes, etc.)

### S3 events not triggering

- Check S3 bucket notification configuration
- Verify Lambda permissions
- Check CloudWatch Logs for errors

## Development

### Local Testing

```python
# Test raw-to-curated locally
python raw-to-curated/lambda_function.py

# Test curated-to-prod locally
python curated-to-prod/lambda_function.py
```

### Adding New AI Models

Edit `curated-to-prod/lambda_function.py` and add your model to the appropriate system function (e.g., `run_market_intelligence_models`).

## Dependencies

- pandas: Data manipulation
- pyarrow: Parquet file I/O
- boto3: AWS SDK

## License

Proprietary - FutureIM
