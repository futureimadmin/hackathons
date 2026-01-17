"""
Property test for data validation

Task 5.3: Property 5 - Data Validation Identifies Invalid Records
Validates: Requirements 8.4
"""

import pytest
from hypothesis import given, strategies as st, settings
import pandas as pd
from datetime import datetime, timedelta

from src.validators.schema_validator import SchemaValidator, SchemaDefinition, ColumnDefinition
from src.validators.business_rules import BusinessRuleValidator


# Feature: ecommerce-ai-platform, Property 5: Data Validation Identifies Invalid Records
@given(
    st.lists(
        st.fixed_dictionaries({
            'order_id': st.one_of(
                st.uuids().map(str),  # Valid UUIDs
                st.just(None),  # Invalid: NULL
                st.just(''),  # Invalid: empty string
            ),
            'customer_id': st.one_of(
                st.uuids().map(str),
                st.just(None),
            ),
            'order_total': st.one_of(
                st.decimals(min_value=0.01, max_value=10000, places=2),  # Valid
                st.decimals(min_value=-100, max_value=-0.01, places=2),  # Invalid: negative
                st.just(None),  # Invalid: NULL for non-nullable field
            ),
            'order_date': st.one_of(
                st.datetimes(
                    min_value=datetime(2020, 1, 1),
                    max_value=datetime(2025, 12, 31)
                ),  # Valid
                st.just(None),  # Invalid: NULL
            ),
            'email': st.one_of(
                st.emails(),  # Valid
                st.text(min_size=1, max_size=20).filter(lambda x: '@' not in x),  # Invalid format
                st.just(''),  # Invalid: empty
            )
        }),
        min_size=1,
        max_size=20
    )
)
@settings(max_examples=100)
def test_schema_validation_identifies_invalid_records(records):
    """
    Property: For any dataset with records that violate schema rules,
    the validation process must identify and flag all invalid records.
    """
    # Create DataFrame
    df = pd.DataFrame(records)
    
    # Define schema with strict rules
    schema = SchemaDefinition(
        columns=[
            ColumnDefinition(name='order_id', dtype='string', nullable=False),
            ColumnDefinition(name='customer_id', dtype='string', nullable=False),
            ColumnDefinition(name='order_total', dtype='float', nullable=False, min_value=0.0),
            ColumnDefinition(name='order_date', dtype='datetime', nullable=False),
            ColumnDefinition(name='email', dtype='string', nullable=False, format_pattern=r'^[^@]+@[^@]+\.[^@]+$'),
        ]
    )
    
    # Validate
    validator = SchemaValidator()
    validator.expected_schema = schema
    result = validator.validate(df)
    
    # Count actual invalid records
    invalid_count = 0
    for record in records:
        is_invalid = (
            record['order_id'] is None or record['order_id'] == '' or
            record['customer_id'] is None or
            record['order_total'] is None or (isinstance(record['order_total'], (int, float)) and record['order_total'] < 0) or
            record['order_date'] is None or
            record['email'] == '' or '@' not in str(record['email'])
        )
        if is_invalid:
            invalid_count += 1
    
    # If there are invalid records, validation must fail
    if invalid_count > 0:
        assert not result.passed, "Validation should fail when invalid records exist"
        assert len(result.errors) > 0, "Validation errors should be reported"
    else:
        # All records are valid
        assert result.passed, "Validation should pass when all records are valid"


# Feature: ecommerce-ai-platform, Property 5: Data Validation Identifies Invalid Records
@given(
    st.lists(
        st.fixed_dictionaries({
            'order_id': st.uuids().map(str),
            'order_total': st.decimals(min_value=0.01, max_value=10000, places=2),
            'item_total': st.decimals(min_value=0.01, max_value=10000, places=2),
        }),
        min_size=1,
        max_size=20
    )
)
@settings(max_examples=100)
def test_business_rule_validation_identifies_violations(orders):
    """
    Property: For any dataset with records that violate business rules,
    the validation process must identify and flag all violations.
    """
    # Create DataFrame
    df = pd.DataFrame(orders)
    
    # Validate business rules
    validator = BusinessRuleValidator()
    result = validator.validate(df, 'orders')
    
    # Count actual violations (order_total should equal item_total)
    violations = 0
    for order in orders:
        if abs(float(order['order_total']) - float(order['item_total'])) > 0.01:
            violations += 1
    
    # If there are violations, validation must fail
    if violations > 0:
        assert not result.passed, "Business rule validation should fail when violations exist"
        assert len(result.errors) > 0, "Business rule errors should be reported"


# Feature: ecommerce-ai-platform, Property 5: Data Validation Identifies Invalid Records
@given(
    st.lists(
        st.fixed_dictionaries({
            'product_id': st.uuids().map(str),
            'price': st.one_of(
                st.decimals(min_value=0.01, max_value=10000, places=2),  # Valid
                st.decimals(min_value=-100, max_value=0, places=2),  # Invalid: non-positive
            ),
            'quantity': st.one_of(
                st.integers(min_value=0, max_value=1000),  # Valid
                st.integers(min_value=-100, max_value=-1),  # Invalid: negative
            ),
        }),
        min_size=1,
        max_size=20
    )
)
@settings(max_examples=100)
def test_range_validation_identifies_out_of_range_values(products):
    """
    Property: For any dataset with values outside valid ranges,
    the validation process must identify and flag all out-of-range values.
    """
    # Create DataFrame
    df = pd.DataFrame(products)
    
    # Define schema with range constraints
    schema = SchemaDefinition(
        columns=[
            ColumnDefinition(name='product_id', dtype='string', nullable=False),
            ColumnDefinition(name='price', dtype='float', nullable=False, min_value=0.01),
            ColumnDefinition(name='quantity', dtype='int', nullable=False, min_value=0),
        ]
    )
    
    # Validate
    validator = SchemaValidator()
    validator.expected_schema = schema
    result = validator.validate(df)
    
    # Count actual range violations
    violations = 0
    for product in products:
        if (isinstance(product['price'], (int, float)) and product['price'] <= 0) or \
           (isinstance(product['quantity'], int) and product['quantity'] < 0):
            violations += 1
    
    # If there are violations, validation must fail
    if violations > 0:
        assert not result.passed, "Range validation should fail when violations exist"
        assert len(result.errors) > 0, "Range validation errors should be reported"
