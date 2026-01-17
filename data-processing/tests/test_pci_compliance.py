"""
Property test for PCI DSS compliance

Task 5.7: Property 11 - PCI DSS Compliance for Payment Data
Validates: Requirements 25.6
"""

import pytest
from hypothesis import given, strategies as st, settings
import pandas as pd
import re

from src.validators.compliance_checker import ComplianceChecker


class MockConfig:
    """Mock configuration for testing"""
    def get(self, key, default=None):
        config_values = {
            'compliance.pci_dss.enabled': True,
            'compliance.pci_dss.mask_credit_cards': True,
        }
        return config_values.get(key, default)


def generate_credit_card():
    """Generate a valid-looking credit card number"""
    # Generate 16-digit credit card numbers
    return st.integers(min_value=1000000000000000, max_value=9999999999999999).map(str)


# Feature: ecommerce-ai-platform, Property 11: PCI DSS Compliance for Payment Data
@given(
    st.lists(
        st.fixed_dictionaries({
            'payment_id': st.uuids().map(str),
            'credit_card_number': generate_credit_card(),
            'cvv': st.integers(min_value=100, max_value=999).map(str),
            'amount': st.decimals(min_value=1, max_value=10000, places=2),
        }),
        min_size=1,
        max_size=20
    )
)
@settings(max_examples=100)
def test_credit_card_masking_in_payment_data(payments):
    """
    Property: For any payment record containing credit card information,
    the credit card number must be masked (showing only last 4 digits).
    """
    # Create DataFrame
    df = pd.DataFrame(payments)
    
    # Create compliance checker
    checker = ComplianceChecker(MockConfig())
    
    # Mask sensitive fields
    df_masked = checker.mask_sensitive_fields(df, 'payments')
    
    # Verify: All credit card numbers are masked
    for idx, row in df_masked.iterrows():
        original_card = payments[idx]['credit_card_number']
        masked_card = row['credit_card_number']
        
        # Should be masked (asterisks + last 4 digits)
        assert '*' in masked_card, \
            f"Credit card should be masked with asterisks: {masked_card}"
        
        # Should show last 4 digits
        last_4_original = original_card[-4:]
        assert masked_card.endswith(last_4_original), \
            f"Masked card should end with last 4 digits: {last_4_original}, got {masked_card}"
        
        # Should not contain the full original number
        assert original_card != masked_card, \
            "Credit card should be masked, not shown in full"
        
        # First 12 digits should be masked
        assert len(masked_card) >= 16, \
            f"Masked card should maintain length, got {len(masked_card)}"


# Feature: ecommerce-ai-platform, Property 11: PCI DSS Compliance for Payment Data
@given(
    st.lists(
        st.fixed_dictionaries({
            'payment_id': st.uuids().map(str),
            'credit_card_number': generate_credit_card(),
            'cvv': st.integers(min_value=100, max_value=999).map(str),
            'cardholder_name': st.text(min_size=5, max_size=50),
        }),
        min_size=1,
        max_size=20
    )
)
@settings(max_examples=100)
def test_cvv_not_stored_in_logs(payments):
    """
    Property: CVV codes must never be stored or logged.
    Compliance check should flag any CVV storage.
    """
    # Create DataFrame
    df = pd.DataFrame(payments)
    
    # Create compliance checker
    checker = ComplianceChecker(MockConfig())
    
    # Check compliance
    result = checker.check_compliance(df, 'payments')
    
    # If CVV column exists, compliance should fail
    if 'cvv' in df.columns:
        assert not result.passed, \
            "Compliance check should fail when CVV is present in data"
        
        # Should have error about CVV storage
        cvv_errors = [e for e in result.errors if 'cvv' in e.lower() or 'security code' in e.lower()]
        assert len(cvv_errors) > 0, \
            "Should report error about CVV storage"


# Feature: ecommerce-ai-platform, Property 11: PCI DSS Compliance for Payment Data
@given(
    st.lists(
        st.fixed_dictionaries({
            'payment_id': st.uuids().map(str),
            'credit_card_number': generate_credit_card(),
            'amount': st.decimals(min_value=1, max_value=10000, places=2),
            'status': st.sampled_from(['pending', 'completed', 'failed']),
        }),
        min_size=1,
        max_size=20
    )
)
@settings(max_examples=100)
def test_no_full_credit_card_in_masked_output(payments):
    """
    Property: After masking, no full credit card numbers should be
    recoverable from the masked data.
    """
    # Create DataFrame
    df = pd.DataFrame(payments)
    
    # Store original card numbers
    original_cards = df['credit_card_number'].tolist()
    
    # Create compliance checker and mask
    checker = ComplianceChecker(MockConfig())
    df_masked = checker.mask_sensitive_fields(df, 'payments')
    
    # Verify: No full credit card numbers in masked data
    for original_card in original_cards:
        # Check that full card number doesn't appear in any column
        for col in df_masked.columns:
            col_values = df_masked[col].astype(str).tolist()
            for value in col_values:
                assert original_card not in value, \
                    f"Full credit card number {original_card} should not appear in masked data"


# Feature: ecommerce-ai-platform, Property 11: PCI DSS Compliance for Payment Data
@given(
    st.fixed_dictionaries({
        'payment_id': st.uuids().map(str),
        'credit_card_number': generate_credit_card(),
        'amount': st.decimals(min_value=1, max_value=10000, places=2),
    })
)
@settings(max_examples=100)
def test_masked_card_preserves_last_four_digits(payment):
    """
    Property: Masking must preserve the last 4 digits for customer
    reference while hiding the rest.
    """
    # Create DataFrame with single payment
    df = pd.DataFrame([payment])
    
    # Create compliance checker and mask
    checker = ComplianceChecker(MockConfig())
    df_masked = checker.mask_sensitive_fields(df, 'payments')
    
    # Get original and masked card numbers
    original_card = payment['credit_card_number']
    masked_card = df_masked.iloc[0]['credit_card_number']
    
    # Extract last 4 digits from both
    last_4_original = original_card[-4:]
    last_4_masked = masked_card[-4:]
    
    # Verify: Last 4 digits are preserved
    assert last_4_original == last_4_masked, \
        f"Last 4 digits should be preserved. Original: {last_4_original}, Masked: {last_4_masked}"
    
    # Verify: First digits are masked
    first_char_masked = masked_card[0]
    assert first_char_masked == '*' or not first_char_masked.isdigit(), \
        "First characters should be masked (not digits)"


# Feature: ecommerce-ai-platform, Property 11: PCI DSS Compliance for Payment Data
@given(
    st.lists(
        st.fixed_dictionaries({
            'order_id': st.uuids().map(str),
            'customer_email': st.emails(),
            'customer_phone': st.text(min_size=10, max_size=15, alphabet=st.characters(whitelist_categories=('Nd',))),
            'amount': st.decimals(min_value=1, max_value=10000, places=2),
        }),
        min_size=1,
        max_size=20
    )
)
@settings(max_examples=100)
def test_pii_identification_in_non_payment_tables(orders):
    """
    Property: Compliance checker should identify PII fields even in
    non-payment tables for proper handling.
    """
    # Create DataFrame
    df = pd.DataFrame(orders)
    
    # Create compliance checker
    checker = ComplianceChecker(MockConfig())
    
    # Check compliance
    result = checker.check_compliance(df, 'orders')
    
    # Should identify PII fields
    pii_fields = checker.identify_pii_fields(df)
    
    # Email and phone should be identified as PII
    assert 'customer_email' in pii_fields or 'email' in str(pii_fields).lower(), \
        "Email should be identified as PII"
    
    # Verify PII fields are flagged in warnings
    if len(pii_fields) > 0:
        assert len(result.warnings) > 0, \
            "Should have warnings about PII fields"


# Feature: ecommerce-ai-platform, Property 11: PCI DSS Compliance for Payment Data
@given(
    st.lists(
        st.fixed_dictionaries({
            'payment_id': st.uuids().map(str),
            'credit_card_number': st.one_of(
                generate_credit_card(),
                st.just('************1234'),  # Already masked
            ),
            'amount': st.decimals(min_value=1, max_value=10000, places=2),
        }),
        min_size=1,
        max_size=20
    )
)
@settings(max_examples=100)
def test_masking_is_idempotent(payments):
    """
    Property: Masking should be idempotent - masking already masked
    data should not change it further.
    """
    # Create DataFrame
    df = pd.DataFrame(payments)
    
    # Create compliance checker
    checker = ComplianceChecker(MockConfig())
    
    # Mask once
    df_masked_once = checker.mask_sensitive_fields(df, 'payments')
    
    # Mask again
    df_masked_twice = checker.mask_sensitive_fields(df_masked_once, 'payments')
    
    # Verify: Second masking doesn't change the data
    for idx in range(len(df_masked_once)):
        card_once = df_masked_once.iloc[idx]['credit_card_number']
        card_twice = df_masked_twice.iloc[idx]['credit_card_number']
        
        assert card_once == card_twice, \
            f"Masking should be idempotent. First: {card_once}, Second: {card_twice}"
