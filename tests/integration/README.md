# Integration Tests

This directory contains comprehensive integration tests for the eCommerce AI Analytics Platform.

## Overview

The integration tests validate end-to-end functionality across all system components:

- **Data Pipeline Tests**: MySQL → DMS → S3 → Batch → Glue → Athena
- **Property-Based Tests**: Data consistency across pipeline stages
- **AI Systems Tests**: All 5 AI systems with cross-system integration

## Test Files

### 1. `test_data_pipeline_e2e.py`
End-to-end integration test for the complete data pipeline.

**Tests:**
- DMS replication is active
- Data appears in S3 raw bucket
- Batch job processes data
- Data appears in S3 curated bucket
- Data appears in S3 prod bucket
- Glue crawler runs and updates catalog
- Athena can query data
- Data consistency across all stages

**Requirements Validated:** 23.1, 23.2, 23.3

### 2. `test_data_consistency_property.py`
Property-based test for data consistency using Hypothesis.

**Property 10: Data Consistency Across Pipeline Stages**

For any data record that enters the pipeline:
- The record MUST appear in all three stages (raw, curated, prod)
- Key fields MUST remain unchanged across stages
- Data transformations MUST be deterministic
- No data loss MUST occur during processing

**Requirements Validated:** 23.3

**Test Configuration:**
- 50 test iterations with randomly generated customer data
- Validates consistency using data hashing
- Tests deterministic transformations

### 3. `test_ai_systems_integration.py`
Integration tests for all 5 AI systems.

**Systems Tested:**
1. **Market Intelligence Hub** (3 tests)
   - Forecast generation
   - Trend analysis
   - Model comparison

2. **Demand Insights Engine** (4 tests)
   - Customer segmentation
   - CLV prediction
   - Churn prediction
   - Price elasticity

3. **Compliance Guardian** (4 tests)
   - Fraud detection
   - Risk scoring
   - PCI compliance
   - High-risk transactions

4. **Retail Copilot** (3 tests)
   - Chat interaction
   - Inventory queries
   - Product recommendations

5. **Global Market Pulse** (4 tests)
   - Market trends
   - Price comparison
   - Market opportunities
   - Competitor analysis

**Cross-System Tests:**
- Data flow between systems
- Data consistency across systems

**Requirements Validated:** 15.1-15.9, 16.1-16.8, 17.1-17.8, 18.1-18.8, 19.1-19.8

## Prerequisites

### Required Software
- Python 3.9+
- pytest
- hypothesis
- boto3
- requests
- pymysql

### Installation
```powershell
# Install test dependencies
pip install pytest hypothesis boto3 requests pymysql

# Or install from requirements file
pip install -r requirements-test.txt
```

### AWS Configuration
```powershell
# Configure AWS credentials
aws configure

# Set environment variables
$env:AWS_REGION = "us-east-1"
$env:PROJECT_NAME = "ecommerce-ai-platform"
```

### API Configuration
```powershell
# Set API endpoint
$env:API_BASE_URL = "https://api.example.com"

# Set test user credentials
$env:TEST_USER_EMAIL = "test@example.com"
$env:TEST_USER_PASSWORD = "TestPassword123!"
```

## Running Tests

### Using PowerShell Script (Recommended)

```powershell
# Run all integration tests
.\run_integration_tests.ps1 -TestType all

# Run only end-to-end tests
.\run_integration_tests.ps1 -TestType e2e

# Run only property-based tests
.\run_integration_tests.ps1 -TestType property

# Run only AI systems tests
.\run_integration_tests.ps1 -TestType ai-systems

# Run with verbose output
.\run_integration_tests.ps1 -TestType all -Verbose

# Run with coverage report
.\run_integration_tests.ps1 -TestType all -Coverage
```

### Using pytest Directly

```powershell
# Run all integration tests
pytest tests/integration -v

# Run specific test file
pytest tests/integration/test_data_pipeline_e2e.py -v

# Run with markers
pytest tests/integration -m integration -v

# Run with hypothesis statistics
pytest tests/integration/test_data_consistency_property.py -v --hypothesis-show-statistics

# Run with coverage
pytest tests/integration --cov=tests/integration --cov-report=html
```

## Test Configuration

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `PROJECT_NAME` | Project name prefix | `ecommerce-ai-platform` |
| `AWS_REGION` | AWS region | `us-east-1` |
| `API_BASE_URL` | API Gateway URL | `https://api.example.com` |
| `TEST_USER_EMAIL` | Test user email | `test@example.com` |
| `TEST_USER_PASSWORD` | Test user password | `TestPassword123!` |

### Shared Fixtures

The `conftest.py` file provides shared fixtures:

**AWS Clients:**
- `s3_client`: S3 client
- `glue_client`: Glue client
- `athena_client`: Athena client
- `batch_client`: Batch client
- `dms_client`: DMS client
- `dynamodb_client`: DynamoDB client

**Authentication:**
- `jwt_token`: JWT authentication token
- `auth_headers`: Authentication headers

**Bucket Names:**
- `raw_bucket`: Raw data bucket
- `curated_bucket`: Curated data bucket
- `prod_bucket`: Production data bucket
- `athena_output_bucket`: Athena results bucket

**Helper Functions:**
- `make_api_request`: Make authenticated API requests
- `wait_for_s3_object`: Wait for S3 object to appear
- `execute_athena_query`: Execute Athena query
- `cleanup_s3_objects`: Cleanup test data

## Test Markers

Tests are marked with pytest markers:

- `@pytest.mark.integration`: Integration tests
- `@pytest.mark.e2e`: End-to-end tests
- `@pytest.mark.slow`: Slow-running tests

```powershell
# Run only integration tests
pytest -m integration

# Skip slow tests
pytest -m "not slow"
```

## Expected Test Duration

| Test Suite | Duration | Tests |
|------------|----------|-------|
| Data Pipeline E2E | ~10 minutes | 8 tests |
| Data Consistency Property | ~15 minutes | 50 iterations |
| AI Systems Integration | ~5 minutes | 20+ tests |
| **Total** | **~30 minutes** | **70+ tests** |

## Troubleshooting

### Common Issues

**1. Authentication Failed**
```
Error: Authentication failed: 401 Unauthorized
```
**Solution:** Verify test user credentials and API endpoint:
```powershell
$env:API_BASE_URL = "https://your-api-gateway-url.amazonaws.com/prod"
$env:TEST_USER_EMAIL = "your-test-user@example.com"
$env:TEST_USER_PASSWORD = "YourPassword123!"
```

**2. AWS Credentials Not Configured**
```
Error: Unable to locate credentials
```
**Solution:** Configure AWS credentials:
```powershell
aws configure
```

**3. DMS Replication Not Running**
```
Error: No DMS replication tasks found
```
**Solution:** Start DMS replication tasks:
```powershell
aws dms start-replication-task --replication-task-arn <task-arn>
```

**4. S3 Bucket Not Found**
```
Error: The specified bucket does not exist
```
**Solution:** Verify bucket names and ensure infrastructure is deployed:
```powershell
terraform apply
```

**5. Athena Query Failed**
```
Error: Query failed: Table not found
```
**Solution:** Run Glue crawler to update catalog:
```powershell
aws glue start-crawler --name ecommerce-ai-platform-crawler
```

### Debug Mode

Run tests with verbose output and logging:

```powershell
# Enable verbose output
pytest tests/integration -vv --log-cli-level=DEBUG

# Show hypothesis statistics
pytest tests/integration/test_data_consistency_property.py --hypothesis-show-statistics

# Show full traceback
pytest tests/integration --tb=long
```

## CI/CD Integration

### GitHub Actions Example

```yaml
name: Integration Tests

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  integration-tests:
    runs-on: ubuntu-latest
    
    steps:
      - uses: actions/checkout@v2
      
      - name: Set up Python
        uses: actions/setup-python@v2
        with:
          python-version: '3.9'
      
      - name: Install dependencies
        run: |
          pip install -r requirements-test.txt
      
      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v1
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: us-east-1
      
      - name: Run integration tests
        env:
          API_BASE_URL: ${{ secrets.API_BASE_URL }}
          TEST_USER_EMAIL: ${{ secrets.TEST_USER_EMAIL }}
          TEST_USER_PASSWORD: ${{ secrets.TEST_USER_PASSWORD }}
        run: |
          pytest tests/integration -v --tb=short
```

## Best Practices

1. **Run tests in order**: E2E → Property → AI Systems
2. **Clean up test data**: Tests should clean up after themselves
3. **Use fixtures**: Leverage shared fixtures from `conftest.py`
4. **Mock external services**: Use mocks for external APIs when possible
5. **Set timeouts**: Configure appropriate timeouts for long-running operations
6. **Parallel execution**: Use `pytest-xdist` for parallel test execution
7. **Retry flaky tests**: Use `pytest-rerunfailures` for transient failures

## Contributing

When adding new integration tests:

1. Follow existing test structure and naming conventions
2. Add appropriate markers (`@pytest.mark.integration`, etc.)
3. Use shared fixtures from `conftest.py`
4. Include cleanup logic to remove test data
5. Document test purpose and requirements validated
6. Update this README with new test information

## Support

For issues or questions:
- Check troubleshooting section above
- Review test logs for detailed error messages
- Verify AWS infrastructure is deployed correctly
- Ensure all prerequisites are installed
