# Testing Framework

This directory contains all testing-related files for the eCommerce AI Analytics Platform.

## Directory Structure

```
tests/
├── integration/          # Integration and end-to-end tests
├── performance/          # Performance and load testing
└── security/            # Security testing and hardening
```

## Integration Tests

**Location:** `tests/integration/`

**Contents:**
- End-to-end data pipeline tests
- Property-based data consistency tests
- AI systems integration tests
- Test configuration and fixtures

**Run Tests:**
```powershell
cd tests/integration
.\run_integration_tests.ps1
```

**Documentation:** See `tests/integration/README.md`

## Performance Tests

**Location:** `tests/performance/`

**Contents:**
- Load test configuration (1000 concurrent users)
- Performance test runner script
- Comprehensive optimization guide

**Run Tests:**
```powershell
cd tests/performance
.\run-load-tests.ps1 -TestType all
```

**Key Files:**
- `load-test-config.yaml` - Test scenarios and thresholds
- `run-load-tests.ps1` - Automated test execution
- `OPTIMIZATION_GUIDE.md` - Performance optimization strategies

## Security Tests

**Location:** `tests/security/`

**Contents:**
- Security testing guide (OWASP ZAP, SQL injection, XSS)
- Security test runner script
- Security hardening checklist

**Run Tests:**
```powershell
cd tests/security
.\run-security-tests.ps1 -TestType all
```

**Key Files:**
- `SECURITY_TESTING_GUIDE.md` - Comprehensive security testing procedures
- `run-security-tests.ps1` - Automated security tests

## Test Coverage

### Integration Tests
- 70+ tests covering all major components
- Property-based tests for correctness validation
- End-to-end data pipeline verification
- AI systems integration testing

### Performance Tests
- API Gateway load testing (1000 RPS)
- Athena query performance
- Lambda cold start and warm response
- Data pipeline throughput

### Security Tests
- OWASP ZAP vulnerability scanning
- SQL injection prevention
- XSS prevention
- Authentication/authorization
- Data encryption verification
- Sensitive data masking

## Prerequisites

### Integration Tests
- Python 3.9+
- pytest
- boto3
- AWS credentials configured

### Performance Tests
- Python 3.9+
- Locust (load testing tool)
- AWS CLI
- API_BASE_URL environment variable

### Security Tests
- OWASP ZAP (optional)
- AWS CLI
- API_BASE_URL environment variable
- TEST_TOKEN environment variable

## Running All Tests

To run all tests in sequence:

```powershell
# Integration tests
cd tests/integration
.\run_integration_tests.ps1

# Performance tests
cd ..\performance
.\run-load-tests.ps1 -TestType all

# Security tests
cd ..\security
.\run-security-tests.ps1 -TestType all
```

## CI/CD Integration

All test suites can be integrated into CI/CD pipelines:

```yaml
# Example GitHub Actions workflow
name: Test Suite

on: [push, pull_request]

jobs:
  integration-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Run Integration Tests
        run: |
          cd tests/integration
          python -m pytest
  
  performance-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Run Performance Tests
        run: |
          cd tests/performance
          ./run-load-tests.ps1 -TestType api
  
  security-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Run Security Tests
        run: |
          cd tests/security
          ./run-security-tests.ps1 -TestType all
```

## Test Reports

Test reports are generated in each subdirectory:

- **Integration:** `tests/integration/test-results/`
- **Performance:** `tests/performance/reports/`
- **Security:** `tests/security/reports/`

## Contributing

When adding new tests:

1. Place integration tests in `tests/integration/`
2. Place performance tests in `tests/performance/`
3. Place security tests in `tests/security/`
4. Update this README with new test information
5. Ensure tests are documented and can run in CI/CD

## Support

For questions or issues with tests:
- Check individual README files in each subdirectory
- Review troubleshooting guides
- Contact the development team

---

**Last Updated:** January 16, 2026
