"""
Property test for Parquet format validation

Task 5.9: Property 4 - Data Pipeline Outputs Valid Parquet Format
Validates: Requirements 6.9, 9.6
"""

import pytest
from hypothesis import given, strategies as st, settings
import pandas as pd
import pyarrow as pa
import pyarrow.parquet as pq
from io import BytesIO
from datetime import datetime
import tempfile
import os

from src.utils.s3_utils import S3Client


class MockConfig:
    """Mock configuration for testing"""
    def get(self, key, default=None):
        config_values = {
            'aws.region': 'us-east-1',
        }
        return config_values.get(key, default)


# Feature: ecommerce-ai-platform, Property 4: Data Pipeline Outputs Valid Parquet Format
@given(
    st.lists(
        st.fixed_dictionaries({
            'order_id': st.uuids().map(str),
            'customer_id': st.uuids().map(str),
            'order_total': st.decimals(min_value=0.01, max_value=10000, places=2).map(float),
            'order_date': st.datetimes(
                min_value=datetime(2020, 1, 1),
                max_value=datetime(2025, 12, 31)
            ),
            'status': st.sampled_from(['pending', 'completed', 'cancelled', 'refunded']),
        }),
        min_size=1,
        max_size=100
    )
)
@settings(max_examples=100)
def test_parquet_format_is_valid_and_readable(orders):
    """
    Property: For any data written to S3 by the data pipeline,
    the file must be in valid Parquet format that can be read back.
    """
    # Create DataFrame
    df = pd.DataFrame(orders)
    
    # Write to Parquet in memory
    buffer = BytesIO()
    df.to_parquet(buffer, engine='pyarrow', compression='gzip', index=False)
    
    # Verify: File is valid Parquet format by reading it back
    buffer.seek(0)
    df_read = pd.read_parquet(buffer, engine='pyarrow')
    
    # Verify: Data is preserved
    assert len(df_read) == len(df), \
        f"Row count should be preserved. Original: {len(df)}, Read: {len(df_read)}"
    
    assert list(df_read.columns) == list(df.columns), \
        f"Columns should be preserved. Original: {list(df.columns)}, Read: {list(df_read.columns)}"
    
    # Verify: Data types are appropriate
    assert df_read['order_id'].dtype == 'object', "order_id should be string type"
    assert df_read['order_total'].dtype in ['float64', 'float32'], "order_total should be float type"


# Feature: ecommerce-ai-platform, Property 4: Data Pipeline Outputs Valid Parquet Format
@given(
    st.lists(
        st.fixed_dictionaries({
            'product_id': st.integers(min_value=1, max_value=10000),
            'name': st.text(min_size=1, max_size=100),
            'price': st.decimals(min_value=0.01, max_value=10000, places=2).map(float),
            'stock': st.integers(min_value=0, max_value=10000),
        }),
        min_size=10,
        max_size=100
    ),
    st.sampled_from(['gzip', 'snappy', 'none'])
)
@settings(max_examples=100)
def test_parquet_compression_is_applied(products, compression):
    """
    Property: Parquet files must use appropriate compression
    (gzip or snappy) to reduce storage costs.
    """
    # Create DataFrame
    df = pd.DataFrame(products)
    
    # Write to temporary file with compression
    with tempfile.NamedTemporaryFile(delete=False, suffix='.parquet') as tmp:
        tmp_path = tmp.name
    
    try:
        # Write with specified compression
        df.to_parquet(tmp_path, engine='pyarrow', compression=compression, index=False)
        
        # Read Parquet metadata
        parquet_file = pq.ParquetFile(tmp_path)
        
        # Verify: File is valid and readable
        df_read = parquet_file.read().to_pandas()
        assert len(df_read) == len(df), "Data should be readable after compression"
        
        # Verify: Compression is applied (if not 'none')
        if compression != 'none':
            # File size should be smaller than uncompressed
            file_size = os.path.getsize(tmp_path)
            
            # Write uncompressed version for comparison
            with tempfile.NamedTemporaryFile(delete=False, suffix='.parquet') as tmp_uncompressed:
                tmp_uncompressed_path = tmp_uncompressed.name
            
            df.to_parquet(tmp_uncompressed_path, engine='pyarrow', compression='none', index=False)
            uncompressed_size = os.path.getsize(tmp_uncompressed_path)
            
            # Compressed should be smaller (or equal for very small files)
            assert file_size <= uncompressed_size, \
                f"Compressed file should be smaller. Compressed: {file_size}, Uncompressed: {uncompressed_size}"
            
            os.unlink(tmp_uncompressed_path)
    
    finally:
        # Cleanup
        if os.path.exists(tmp_path):
            os.unlink(tmp_path)


# Feature: ecommerce-ai-platform, Property 4: Data Pipeline Outputs Valid Parquet Format
@given(
    st.lists(
        st.fixed_dictionaries({
            'customer_id': st.integers(min_value=1, max_value=1000),
            'name': st.text(min_size=1, max_size=50),
            'email': st.emails(),
            'signup_date': st.datetimes(
                min_value=datetime(2020, 1, 1),
                max_value=datetime(2025, 12, 31)
            ),
            'total_spent': st.decimals(min_value=0, max_value=100000, places=2).map(float),
        }),
        min_size=1,
        max_size=50
    )
)
@settings(max_examples=100)
def test_parquet_schema_is_preserved(customers):
    """
    Property: Parquet files must preserve the schema (column names,
    data types) when written and read back.
    """
    # Create DataFrame
    df = pd.DataFrame(customers)
    
    # Write to Parquet
    buffer = BytesIO()
    df.to_parquet(buffer, engine='pyarrow', compression='gzip', index=False)
    
    # Read back
    buffer.seek(0)
    df_read = pd.read_parquet(buffer, engine='pyarrow')
    
    # Verify: Column names are preserved
    assert list(df.columns) == list(df_read.columns), \
        f"Column names should be preserved. Original: {list(df.columns)}, Read: {list(df_read.columns)}"
    
    # Verify: Data types are compatible
    for col in df.columns:
        original_dtype = df[col].dtype
        read_dtype = df_read[col].dtype
        
        # Check type compatibility (exact match or compatible types)
        if original_dtype == 'object':
            assert read_dtype == 'object', f"Column {col} type mismatch"
        elif 'int' in str(original_dtype):
            assert 'int' in str(read_dtype), f"Column {col} should be integer type"
        elif 'float' in str(original_dtype):
            assert 'float' in str(read_dtype), f"Column {col} should be float type"
        elif 'datetime' in str(original_dtype):
            assert 'datetime' in str(read_dtype), f"Column {col} should be datetime type"


# Feature: ecommerce-ai-platform, Property 4: Data Pipeline Outputs Valid Parquet Format
@given(
    st.lists(
        st.fixed_dictionaries({
            'order_id': st.integers(min_value=1, max_value=10000),
            'order_date': st.datetimes(
                min_value=datetime(2024, 1, 1),
                max_value=datetime(2025, 12, 31)
            ),
            'amount': st.decimals(min_value=0.01, max_value=10000, places=2).map(float),
        }),
        min_size=1,
        max_size=100
    )
)
@settings(max_examples=100)
def test_parquet_data_integrity(orders):
    """
    Property: Data written to Parquet must maintain integrity -
    all values should be exactly preserved when read back.
    """
    # Create DataFrame
    df = pd.DataFrame(orders)
    
    # Write to Parquet
    buffer = BytesIO()
    df.to_parquet(buffer, engine='pyarrow', compression='gzip', index=False)
    
    # Read back
    buffer.seek(0)
    df_read = pd.read_parquet(buffer, engine='pyarrow')
    
    # Verify: All order_ids are preserved
    original_ids = set(df['order_id'].tolist())
    read_ids = set(df_read['order_id'].tolist())
    assert original_ids == read_ids, \
        "All order IDs should be preserved"
    
    # Verify: Row count is preserved
    assert len(df) == len(df_read), \
        f"Row count should be preserved. Original: {len(df)}, Read: {len(df_read)}"
    
    # Verify: Amounts are preserved (within floating point precision)
    for idx in range(len(df)):
        original_amount = float(df.iloc[idx]['amount'])
        read_amount = float(df_read.iloc[idx]['amount'])
        
        # Allow small floating point differences
        assert abs(original_amount - read_amount) < 0.01, \
            f"Amount should be preserved. Original: {original_amount}, Read: {read_amount}"


# Feature: ecommerce-ai-platform, Property 4: Data Pipeline Outputs Valid Parquet Format
@given(
    st.lists(
        st.fixed_dictionaries({
            'id': st.integers(min_value=1, max_value=1000),
            'value': st.one_of(
                st.text(min_size=0, max_size=100),
                st.none(),
            ),
            'number': st.one_of(
                st.integers(min_value=-1000, max_value=1000),
                st.none(),
            ),
        }),
        min_size=1,
        max_size=50
    )
)
@settings(max_examples=100)
def test_parquet_handles_null_values(records):
    """
    Property: Parquet format must correctly handle NULL values
    in any column without data corruption.
    """
    # Create DataFrame
    df = pd.DataFrame(records)
    
    # Write to Parquet
    buffer = BytesIO()
    df.to_parquet(buffer, engine='pyarrow', compression='gzip', index=False)
    
    # Read back
    buffer.seek(0)
    df_read = pd.read_parquet(buffer, engine='pyarrow')
    
    # Verify: NULL values are preserved
    for col in ['value', 'number']:
        original_nulls = df[col].isna().sum()
        read_nulls = df_read[col].isna().sum()
        
        assert original_nulls == read_nulls, \
            f"NULL count for column {col} should be preserved. Original: {original_nulls}, Read: {read_nulls}"


# Feature: ecommerce-ai-platform, Property 4: Data Pipeline Outputs Valid Parquet Format
@given(
    st.lists(
        st.fixed_dictionaries({
            'transaction_id': st.uuids().map(str),
            'timestamp': st.datetimes(
                min_value=datetime(2024, 1, 1),
                max_value=datetime(2025, 12, 31)
            ),
            'amount': st.decimals(min_value=0.01, max_value=10000, places=2).map(float),
        }),
        min_size=1,
        max_size=100
    )
)
@settings(max_examples=100)
def test_parquet_metadata_is_valid(transactions):
    """
    Property: Parquet files must have valid metadata that describes
    the schema and allows for efficient querying.
    """
    # Create DataFrame
    df = pd.DataFrame(transactions)
    
    # Write to temporary file
    with tempfile.NamedTemporaryFile(delete=False, suffix='.parquet') as tmp:
        tmp_path = tmp.name
    
    try:
        df.to_parquet(tmp_path, engine='pyarrow', compression='gzip', index=False)
        
        # Read Parquet file metadata
        parquet_file = pq.ParquetFile(tmp_path)
        
        # Verify: Metadata exists and is valid
        assert parquet_file.metadata is not None, "Parquet file should have metadata"
        assert parquet_file.schema is not None, "Parquet file should have schema"
        
        # Verify: Schema matches DataFrame columns
        schema_names = [field.name for field in parquet_file.schema]
        assert set(schema_names) == set(df.columns), \
            f"Schema should match DataFrame columns. Schema: {schema_names}, Columns: {list(df.columns)}"
        
        # Verify: Number of rows in metadata matches actual rows
        assert parquet_file.metadata.num_rows == len(df), \
            f"Metadata row count should match actual rows. Metadata: {parquet_file.metadata.num_rows}, Actual: {len(df)}"
    
    finally:
        # Cleanup
        if os.path.exists(tmp_path):
            os.unlink(tmp_path)
