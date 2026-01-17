"""
Property test for deduplication

Task 5.5: Property 6 - Deduplication Keeps Most Recent Record
Validates: Requirements 8.5, 8.6
"""

import pytest
from hypothesis import given, strategies as st, settings, assume
import pandas as pd
from datetime import datetime, timedelta

from src.processors.raw_to_curated import RawToCuratedProcessor


class MockConfig:
    """Mock configuration for testing"""
    def get(self, key, default=None):
        config_values = {
            'aws.region': 'us-east-1',
            'deduplication.enabled': True,
            'deduplication.timestamp_column': 'dms_timestamp',
        }
        return config_values.get(key, default)


# Feature: ecommerce-ai-platform, Property 6: Deduplication Keeps Most Recent Record
@given(
    st.lists(
        st.fixed_dictionaries({
            'customer_id': st.integers(min_value=1, max_value=50),
            'dms_timestamp': st.datetimes(
                min_value=datetime(2024, 1, 1),
                max_value=datetime(2025, 12, 31)
            ),
            'name': st.text(min_size=1, max_size=50),
            'email': st.emails(),
        }),
        min_size=2,
        max_size=50
    )
)
@settings(max_examples=100)
def test_deduplication_keeps_most_recent_record(records):
    """
    Property: For any set of duplicate records (same primary key),
    the deduplication process must keep only the record with the most
    recent timestamp and remove all others.
    """
    # Ensure we have at least one duplicate
    if len(set(r['customer_id'] for r in records)) == len(records):
        # Force a duplicate by copying the first record with a different timestamp
        duplicate = records[0].copy()
        duplicate['dms_timestamp'] = records[0]['dms_timestamp'] + timedelta(hours=1)
        records.append(duplicate)
    
    # Create DataFrame
    df = pd.DataFrame(records)
    
    # Create processor and deduplicate
    processor = RawToCuratedProcessor(MockConfig())
    metadata = {'table': 'customers'}
    df_deduped = processor._deduplicate_records(df, metadata)
    
    # Verify: For each unique customer_id, only the most recent record is kept
    for customer_id in df['customer_id'].unique():
        # Get all records for this customer_id
        customer_records = [r for r in records if r['customer_id'] == customer_id]
        
        # Find the most recent record
        most_recent = max(customer_records, key=lambda r: r['dms_timestamp'])
        
        # Get the deduplicated record for this customer_id
        deduped_records = df_deduped[df_deduped['customer_id'] == customer_id]
        
        # Should have exactly one record
        assert len(deduped_records) == 1, f"Should have exactly 1 record for customer_id {customer_id}"
        
        # The timestamp should match the most recent
        deduped_timestamp = deduped_records.iloc[0]['dms_timestamp']
        assert deduped_timestamp == most_recent['dms_timestamp'], \
            f"Deduped record should have the most recent timestamp for customer_id {customer_id}"


# Feature: ecommerce-ai-platform, Property 6: Deduplication Keeps Most Recent Record
@given(
    st.lists(
        st.fixed_dictionaries({
            'order_id': st.integers(min_value=1, max_value=30),
            'dms_timestamp': st.datetimes(
                min_value=datetime(2024, 1, 1),
                max_value=datetime(2025, 12, 31)
            ),
            'order_total': st.decimals(min_value=1, max_value=10000, places=2),
            'status': st.sampled_from(['pending', 'completed', 'cancelled']),
        }),
        min_size=5,
        max_size=50
    )
)
@settings(max_examples=100)
def test_deduplication_removes_all_older_duplicates(records):
    """
    Property: For any set of duplicate records, deduplication must remove
    ALL older duplicates, not just some of them.
    """
    # Ensure we have multiple duplicates for at least one order_id
    if len(records) >= 3:
        # Force multiple duplicates
        base_order_id = records[0]['order_id']
        records[1]['order_id'] = base_order_id
        records[1]['dms_timestamp'] = records[0]['dms_timestamp'] + timedelta(hours=1)
        records[2]['order_id'] = base_order_id
        records[2]['dms_timestamp'] = records[0]['dms_timestamp'] + timedelta(hours=2)
    
    # Create DataFrame
    df = pd.DataFrame(records)
    
    # Create processor and deduplicate
    processor = RawToCuratedProcessor(MockConfig())
    metadata = {'table': 'orders'}
    df_deduped = processor._deduplicate_records(df, metadata)
    
    # Verify: Each order_id appears exactly once in deduplicated data
    for order_id in df['order_id'].unique():
        deduped_count = len(df_deduped[df_deduped['order_id'] == order_id])
        assert deduped_count == 1, \
            f"Order ID {order_id} should appear exactly once after deduplication, found {deduped_count}"


# Feature: ecommerce-ai-platform, Property 6: Deduplication Keeps Most Recent Record
@given(
    st.lists(
        st.fixed_dictionaries({
            'product_id': st.integers(min_value=1, max_value=20),
            'dms_timestamp': st.datetimes(
                min_value=datetime(2024, 1, 1),
                max_value=datetime(2025, 12, 31)
            ),
            'price': st.decimals(min_value=1, max_value=1000, places=2),
            'stock': st.integers(min_value=0, max_value=1000),
        }),
        min_size=1,
        max_size=30
    )
)
@settings(max_examples=100)
def test_deduplication_preserves_unique_records(records):
    """
    Property: Deduplication must preserve all unique records (no false positives).
    Records with different primary keys should never be removed.
    """
    # Create DataFrame
    df = pd.DataFrame(records)
    
    # Count unique product_ids in original data
    unique_product_ids = df['product_id'].nunique()
    
    # Create processor and deduplicate
    processor = RawToCuratedProcessor(MockConfig())
    metadata = {'table': 'products'}
    df_deduped = processor._deduplicate_records(df, metadata)
    
    # Verify: Number of unique product_ids is preserved
    deduped_unique_product_ids = df_deduped['product_id'].nunique()
    assert deduped_unique_product_ids == unique_product_ids, \
        f"Deduplication should preserve all unique product_ids. " \
        f"Expected {unique_product_ids}, got {deduped_unique_product_ids}"
    
    # Verify: All unique product_ids from original data are present
    original_ids = set(df['product_id'].unique())
    deduped_ids = set(df_deduped['product_id'].unique())
    assert original_ids == deduped_ids, \
        "All unique product_ids should be preserved after deduplication"


# Feature: ecommerce-ai-platform, Property 6: Deduplication Keeps Most Recent Record
@given(
    st.integers(min_value=1, max_value=100),
    st.datetimes(min_value=datetime(2024, 1, 1), max_value=datetime(2025, 12, 31)),
    st.integers(min_value=2, max_value=10)
)
@settings(max_examples=100)
def test_deduplication_with_identical_timestamps(customer_id, base_timestamp, duplicate_count):
    """
    Property: When duplicate records have identical timestamps,
    deduplication should still keep exactly one record.
    """
    # Create records with same customer_id and timestamp
    records = []
    for i in range(duplicate_count):
        records.append({
            'customer_id': customer_id,
            'dms_timestamp': base_timestamp,
            'name': f'Customer {i}',
            'email': f'customer{i}@example.com',
        })
    
    # Create DataFrame
    df = pd.DataFrame(records)
    
    # Create processor and deduplicate
    processor = RawToCuratedProcessor(MockConfig())
    metadata = {'table': 'customers'}
    df_deduped = processor._deduplicate_records(df, metadata)
    
    # Verify: Exactly one record remains
    assert len(df_deduped) == 1, \
        f"Should have exactly 1 record after deduplication, found {len(df_deduped)}"
    assert df_deduped.iloc[0]['customer_id'] == customer_id, \
        "The remaining record should have the correct customer_id"
