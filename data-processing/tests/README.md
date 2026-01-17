# Data Processing Tests

This directory contains comprehensive tests for the data processing pipeline, including property-based tests using Hypothesis.

## Test Structure

```
tests/
├── __init__.py
├── test_data_validation.py      # Property tests for data validation (Task 5.3)
├── test_deduplication.py         # Property tests for deduplication (Task 5.5)
├── test_pci_compliance.py        # Property tests for PCI compliance (Task 5.7)
└── test_parquet_format.py        # Property tests for Parquet format (Task 5.9)
```

## Property-Based Tests

Property-based tests verify universal correctness properties across a wide range of inputs using the Hypothesis framework. Each test validates specific requirements from the design document.

### Test Coverage

1. **Data Validation (Property 5)**
   - Schema validation identifies invalid records
   - Business rule validation detects violations
   - Range validation catches out-of-range values
   - Validates Requirements 8.4

2. **Deduplication (Property 6)**
   - Keeps most recent record by timestamp
   - Removes all older duplicates
   - Preserves unique records
   - Handles identical timestamps
   - Validates Requirements 8.5, 8.6

3. **PCI Compliance (Property 11)**
   - Masks credit card numbers (shows only last 4 digits)
   - Flags CVV storage violations
   - Prevents full card number recovery
   - Identifies PII fields
   - Validates Requirements 25.6

4. **Parquet Format (Property 4)**
   - Outputs valid Parquet format
   - Applies compression (gzip/snappy)
   - Preserves schema and data types
   - Maintains data integrity
   - Handles NULL values correctly
   - Validates Requirements 6.9, 9.6

## Running Tests

### Install Test Dependencies

```bash
pip install -r requirements-test.txt
```

### Run All Tests

```bash
pytest
```

### Run Specific Test Files

```bash
# Data validation tests
pytest tests/test_data_validation.py

# Deduplication tests
pytest tests/test_deduplication.py

# PCI compliance tests
pytest tests/test_pci_compliance.py

# Parquet format tests
pytest tests/test_parquet_format.py
```

### Run with Coverage

```bash
pytest --cov=src --cov-report=html
```

This generates an HTML coverage report in `htmlcov/index.html`.

### Run Property Tests Only

```bash
pytest -m property
```

### Run with Verbose Output

```bash
pytest -v
```

## Hypothesis Configuration

Property tests use Hypothesis with the following configuration:
- **Max examples**: 100 iterations per test
- **Strategy**: Generates diverse test data including edge cases
- **Shrinking**: Automatically finds minimal failing examples

## Test Markers

Tests are marked with pytest markers for categorization:
- `@pytest.mark.unit` - Unit tests
- `@pytest.mark.integration` - Integration tests
- `@pytest.mark.property` - Property-based tests
- `@pytest.mark.slow` - Long-running tests

## Continuous Integration

These tests should be run in CI/CD pipelines before deploying data processing jobs:

```bash
# Run all tests with coverage
pytest --cov=src --cov-report=term-missing --cov-fail-under=80
```

## Troubleshooting

### Import Errors

If you encounter import errors, ensure you're running tests from the `data-processing` directory:

```bash
cd data-processing
pytest
```

Or set the PYTHONPATH:

```bash
export PYTHONPATH="${PYTHONPATH}:$(pwd)"
pytest
```

### Hypothesis Failures

If a property test fails, Hypothesis will:
1. Show the failing example
2. Attempt to shrink it to a minimal case
3. Save it for replay in `.hypothesis/` directory

To replay a specific failure:

```bash
pytest tests/test_data_validation.py --hypothesis-seed=<seed>
```

## Adding New Tests

When adding new property tests:

1. Reference the design document property number
2. Add a comment with the format: `# Feature: ecommerce-ai-platform, Property {N}: {description}`
3. Use `@settings(max_examples=100)` for consistency
4. Validate the specific requirements being tested
5. Include clear assertion messages

Example:

```python
# Feature: ecommerce-ai-platform, Property X: Description
@given(st.lists(st.integers()))
@settings(max_examples=100)
def test_property_x(data):
    """Property: Description of what must hold true"""
    result = process(data)
    assert condition, "Clear error message"
```
