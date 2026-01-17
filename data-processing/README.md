# Data Processing Jobs

This directory contains the Docker image and Python code for data processing jobs in the eCommerce AI Analytics Platform.

## Overview

The data processing pipeline consists of two main stages:

1. **Raw to Curated**: Validates, deduplicates, and ensures compliance of raw data from DMS
2. **Curated to Prod**: Transforms curated data into analyst-ready format with Athena optimizations

## Architecture

```
S3 Raw Bucket → EventBridge → AWS Batch → Raw-to-Curated Processor → S3 Curated Bucket
S3 Curated Bucket → EventBridge → AWS Batch → Curated-to-Prod Processor → S3 Prod Bucket
```

## Directory Structure

```
data-processing/
├── Dockerfile                 # Docker image definition
├── requirements.txt           # Python dependencies
├── build-and-push.ps1        # Build and push script
├── README.md                  # This file
├── src/
│   ├── __init__.py
│   ├── main.py               # Entry point
│   ├── processors/
│   │   ├── __init__.py
│   │   ├── raw_to_curated.py    # Raw to curated processor
│   │   └── curated_to_prod.py   # Curated to prod processor
│   ├── validators/
│   │   ├── __init__.py
│   │   ├── schema_validator.py
│   │   ├── business_rules.py
│   │   └── compliance_checker.py
│   └── utils/
│       ├── __init__.py
│       ├── logger.py          # Logging configuration
│       ├── config.py          # Configuration management
│       └── s3_utils.py        # S3 helper functions
├── config/
│   └── schemas/               # JSON schemas for validation
└── tests/
    ├── __init__.py
    ├── test_raw_to_curated.py
    └── test_curated_to_prod.py
```

## Building the Docker Image

### Prerequisites

- Docker installed
- AWS CLI configured
- AWS account with ECR access

### Build and Push

```powershell
# Windows PowerShell
cd data-processing
.\build-and-push.ps1 -Region us-east-1 -AccountId 123456789012
```

```bash
# Linux/Mac
cd data-processing
chmod +x build-and-push.sh
./build-and-push.sh
```

### Manual Build

```bash
# Build image
docker build -t ecommerce-data-processor:latest .

# Tag for ECR
docker tag ecommerce-data-processor:latest 123456789012.dkr.ecr.us-east-1.amazonaws.com/ecommerce-data-processor:latest

# Push to ECR
docker push 123456789012.dkr.ecr.us-east-1.amazonaws.com/ecommerce-data-processor:latest
```

## Local Testing

### Run with Docker

```bash
# Create test event file
cat > test-event.json <<EOF
{
  "bucket": "market-intelligence-hub-raw-123456789012",
  "key": "ecommerce/customers-raw/year=2025/month=01/day=16/data-001.parquet",
  "event_type": "manual"
}
EOF

# Run container
docker run --rm \
  -e AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID \
  -e AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY \
  -e AWS_DEFAULT_REGION=us-east-1 \
  -v $(pwd)/test-event.json:/app/event.json \
  ecommerce-data-processor:latest \
  python -m src.main /app/event.json
```

### Run Locally (without Docker)

```bash
# Install dependencies
pip install -r requirements.txt

# Set environment variables
export AWS_DEFAULT_REGION=us-east-1
export LOG_LEVEL=INFO

# Run processor
python -m src.main test-event.json
```

## Configuration

Configuration can be provided via:

1. **Environment Variables**:
   - `AWS_DEFAULT_REGION`: AWS region (default: us-east-1)
   - `LOG_LEVEL`: Logging level (default: INFO)
   - `BATCH_SIZE`: Processing batch size (default: 10000)
   - `VALIDATION_ENABLED`: Enable validation (default: true)
   - `DEDUPLICATION_ENABLED`: Enable deduplication (default: true)
   - `PCI_DSS_ENABLED`: Enable PCI DSS compliance checks (default: true)

2. **Configuration File**: JSON file at `/app/config/config.json`

3. **CONFIG_JSON Environment Variable**: JSON string with configuration

## Data Processing Stages

### Stage 1: Raw to Curated

**Input**: Raw Parquet files from DMS in S3 raw buckets

**Processing**:
1. Read Parquet file from S3
2. Validate schema (column names, data types, nullable constraints)
3. Validate ranges (numeric fields within expected ranges)
4. Validate formats (email, phone, date formats)
5. Check referential integrity (foreign key constraints)
6. Apply business rules (order total = sum(order_items), inventory >= 0)
7. Deduplicate records (keep most recent by timestamp)
8. Check PCI DSS compliance (mask credit cards)
9. Write to curated bucket in Parquet format

**Output**: Validated, deduplicated data in S3 curated buckets

### Stage 2: Curated to Prod

**Input**: Curated Parquet files in S3 curated buckets

**Processing**:
1. Read Parquet file from S3
2. Apply transformations (denormalization, aggregations)
3. Calculate derived columns
4. Optimize for Athena (partitioning, sorting, compression)
5. Write to prod bucket with date partitioning
6. Trigger Glue Crawler to update catalog

**Output**: Analyst-ready data in S3 prod buckets

## Validation Rules

### Schema Validation
- Column names match expected schema
- Data types are correct
- Nullable constraints are enforced

### Range Validation
- Numeric fields within expected ranges
- Dates are valid and within reasonable bounds
- Prices and quantities are positive

### Format Validation
- Email addresses match regex pattern
- Phone numbers match expected format
- Dates follow ISO 8601 format

### Business Rules
- Order total equals sum of order items
- Inventory quantities are non-negative
- Foreign keys reference existing records

### Compliance Checks
- Credit card numbers are masked (show only last 4 digits)
- PII fields are encrypted or masked
- Audit logs are maintained

## Error Handling

### Validation Errors
- Log detailed error information
- Write failed records to error bucket
- Send SNS notification to data engineering team
- Continue processing remaining records

### Processing Errors
- Retry up to 3 times with exponential backoff
- Log error details to CloudWatch
- Write to DLQ (Dead Letter Queue) if all retries fail
- Alert operations team via SNS

## Testing

The data processing pipeline includes comprehensive property-based tests using Hypothesis.

### Run Tests

```bash
# Install test dependencies
pip install -r requirements-test.txt

# Run all tests
pytest

# Run with coverage
pytest --cov=src --cov-report=html
```

See `tests/README.md` for detailed testing documentation.

## Monitoring

### CloudWatch Metrics
- Records processed per minute
- Validation failure rate
- Deduplication rate
- Processing duration
- Error rate

### CloudWatch Logs
- Structured JSON logs
- Log level: INFO, WARNING, ERROR
- Includes request ID, bucket, key, processing stage

### Alarms
- High error rate (> 5%)
- High validation failure rate (> 10%)
- Long processing duration (> 30 minutes)
- DLQ messages (> 0)

## Testing

### Unit Tests

```bash
# Run all tests
pytest tests/

# Run with coverage
pytest --cov=src tests/

# Run specific test
pytest tests/test_raw_to_curated.py
```

### Property-Based Tests

Property tests are included for:
- Data validation logic
- Deduplication algorithm
- PCI DSS compliance checks
- Parquet format validation

### Integration Tests

Integration tests verify:
- S3 read/write operations
- End-to-end pipeline flow
- Error handling and retries

## Performance

### Optimization Tips

1. **Batch Processing**: Process data in batches to reduce memory usage
2. **Parallel Processing**: Use multiprocessing for CPU-intensive tasks
3. **Columnar Format**: Use Parquet for efficient storage and querying
4. **Partitioning**: Partition data by date for faster queries
5. **Compression**: Use Snappy compression for balance of speed and size

### Benchmarks

- **Raw to Curated**: ~10,000 records/second
- **Curated to Prod**: ~15,000 records/second
- **Memory Usage**: ~2 GB for 1M records
- **Processing Time**: ~5 minutes for 1M records

## Troubleshooting

### Common Issues

**Issue**: Out of memory errors

**Solution**: Reduce batch size or increase container memory

**Issue**: Slow processing

**Solution**: Increase parallelism or optimize queries

**Issue**: Validation failures

**Solution**: Check schema definitions and data quality

**Issue**: S3 access denied

**Solution**: Verify IAM role permissions

## Security

- All data encrypted at rest (S3 SSE-KMS)
- All data encrypted in transit (TLS 1.2+)
- IAM roles follow least-privilege principle
- Sensitive data masked in logs
- PCI DSS compliant for payment data

## Dependencies

See `requirements.txt` for full list of dependencies.

Key dependencies:
- **boto3**: AWS SDK for Python
- **pandas**: Data manipulation
- **pyarrow**: Parquet file format
- **pydantic**: Data validation
- **structlog**: Structured logging

## License

Proprietary - eCommerce AI Analytics Platform

## Support

For issues or questions, contact: sales@futureim.in
