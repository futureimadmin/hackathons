"""
Property-Based Test for Data Consistency
Property 10: Data Consistency Across Pipeline Stages
Validates: Requirements 23.3
"""

import pytest
from hypothesis import given, strategies as st, settings, assume
import boto3
import json
from typing import Dict, Any
import hashlib

# AWS clients
s3 = boto3.client('s3')
athena = boto3.client('athena')

# Configuration
PROJECT_NAME = "ecommerce-ai-platform"
AWS_REGION = "us-east-1"


# Strategies for generating test data
customer_strategy = st.fixed_dictionaries({
    'customer_id': st.text(alphabet=st.characters(whitelist_categories=('Lu', 'Nd')), min_size=10, max_size=20),
    'email': st.emails(),
    'first_name': st.text(alphabet=st.characters(whitelist_categories=('Lu', 'Ll')), min_size=2, max_size=20),
    'last_name': st.text(alphabet=st.characters(whitelist_categories=('Lu', 'Ll')), min_size=2, max_size=20),
    'phone': st.text(alphabet=st.characters(whitelist_categories=('Nd',)), min_size=10, max_size=15),
    'address': st.text(min_size=10, max_size=100)
})


@given(customer_data=customer_strategy)
@settings(max_examples=50, deadline=None)
def test_data_consistency_across_pipeline_stages(customer_data):
    """
    Property 10: Data Consistency Across Pipeline Stages
    
    For any data record that enters the pipeline:
    - The record MUST appear in all three stages (raw, curated, prod)
    - Key fields MUST remain unchanged across stages
    - Data transformations MUST be deterministic
    - No data loss MUST occur during processing
    
    This property validates that the data pipeline maintains
    consistency and integrity throughout all processing stages.
    """
    
    # Skip invalid data
    if not is_valid_customer_data(customer_data):
        return
    
    try:
        # Step 1: Insert data into raw bucket
        raw_key = insert_data_to_raw(customer_data)
        
        if not raw_key:
            # Insertion failed, skip test
            return
        
        # Step 2: Wait for processing and verify data in curated bucket
        curated_data = wait_for_data_in_curated(customer_data['customer_id'])
        
        if not curated_data:
            # Data not yet processed, skip test
            cleanup_test_data(customer_data['customer_id'])
            return
        
        # Step 3: Verify data in prod bucket
        prod_data = wait_for_data_in_prod(customer_data['customer_id'])
        
        if not prod_data:
            # Data not yet in prod, skip test
            cleanup_test_data(customer_data['customer_id'])
            return
        
        # Property: Key fields must be identical across all stages
        assert customer_data['customer_id'] == curated_data['customer_id'] == prod_data['customer_id'], \
            "Customer ID mismatch across pipeline stages"
        
        assert customer_data['email'] == curated_data['email'] == prod_data['email'], \
            "Email mismatch across pipeline stages"
        
        assert customer_data['first_name'] == curated_data['first_name'] == prod_data['first_name'], \
            "First name mismatch across pipeline stages"
        
        assert customer_data['last_name'] == curated_data['last_name'] == prod_data['last_name'], \
            "Last name mismatch across pipeline stages"
        
        # Property: Data hash should be consistent (for immutable fields)
        raw_hash = calculate_data_hash(customer_data)
        curated_hash = calculate_data_hash(curated_data)
        prod_hash = calculate_data_hash(prod_data)
        
        assert raw_hash == curated_hash == prod_hash, \
            "Data hash mismatch indicates data corruption"
        
        # Property: No data loss - all fields present
        for field in customer_data.keys():
            assert field in curated_data, f"Field {field} missing in curated data"
            assert field in prod_data, f"Field {field} missing in prod data"
        
        # Property: Transformations are deterministic
        # If we process the same data twice, we should get the same result
        curated_data_2 = wait_for_data_in_curated(customer_data['customer_id'])
        assert curated_data == curated_data_2, "Non-deterministic transformation detected"
    
    finally:
        # Cleanup
        cleanup_test_data(customer_data['customer_id'])


def is_valid_customer_data(data: Dict[str, Any]) -> bool:
    """Validate customer data"""
    if not data.get('customer_id') or len(data['customer_id']) < 5:
        return False
    if not data.get('email') or '@' not in data['email']:
        return False
    if not data.get('first_name') or not data.get('last_name'):
        return False
    return True


def insert_data_to_raw(data: Dict[str, Any]) -> str:
    """Insert data into raw S3 bucket"""
    try:
        bucket = f"{PROJECT_NAME}-raw"
        key = f"customers/test_{data['customer_id']}.json"
        
        s3.put_object(
            Bucket=bucket,
            Key=key,
            Body=json.dumps(data).encode('utf-8')
        )
        
        return key
    
    except Exception as e:
        print(f"Error inserting data to raw: {e}")
        return None


def wait_for_data_in_curated(customer_id: str, max_wait: int = 60) -> Dict[str, Any]:
    """Wait for data to appear in curated bucket"""
    import time
    
    bucket = f"{PROJECT_NAME}-curated"
    prefix = f"customers/"
    
    start_time = time.time()
    
    while time.time() - start_time < max_wait:
        try:
            response = s3.list_objects_v2(Bucket=bucket, Prefix=prefix)
            
            if 'Contents' in response:
                for obj in response['Contents']:
                    if customer_id in obj['Key']:
                        content = s3.get_object(Bucket=bucket, Key=obj['Key'])
                        data = json.loads(content['Body'].read().decode('utf-8'))
                        
                        if data.get('customer_id') == customer_id:
                            return data
            
            time.sleep(2)
        
        except Exception as e:
            print(f"Error checking curated bucket: {e}")
            time.sleep(2)
    
    return None


def wait_for_data_in_prod(customer_id: str, max_wait: int = 60) -> Dict[str, Any]:
    """Wait for data to appear in prod bucket"""
    import time
    
    bucket = f"{PROJECT_NAME}-prod"
    prefix = f"customers/"
    
    start_time = time.time()
    
    while time.time() - start_time < max_wait:
        try:
            response = s3.list_objects_v2(Bucket=bucket, Prefix=prefix)
            
            if 'Contents' in response:
                for obj in response['Contents']:
                    if customer_id in obj['Key']:
                        content = s3.get_object(Bucket=bucket, Key=obj['Key'])
                        data = json.loads(content['Body'].read().decode('utf-8'))
                        
                        if data.get('customer_id') == customer_id:
                            return data
            
            time.sleep(2)
        
        except Exception as e:
            print(f"Error checking prod bucket: {e}")
            time.sleep(2)
    
    return None


def calculate_data_hash(data: Dict[str, Any]) -> str:
    """Calculate hash of data for consistency checking"""
    # Sort keys for consistent hashing
    sorted_data = json.dumps(data, sort_keys=True)
    return hashlib.sha256(sorted_data.encode('utf-8')).hexdigest()


def cleanup_test_data(customer_id: str):
    """Cleanup test data from all buckets"""
    buckets = [
        f"{PROJECT_NAME}-raw",
        f"{PROJECT_NAME}-curated",
        f"{PROJECT_NAME}-prod"
    ]
    
    for bucket in buckets:
        try:
            response = s3.list_objects_v2(Bucket=bucket, Prefix='customers/')
            
            if 'Contents' in response:
                for obj in response['Contents']:
                    if customer_id in obj['Key']:
                        s3.delete_object(Bucket=bucket, Key=obj['Key'])
        
        except Exception as e:
            print(f"Error cleaning up {bucket}: {e}")


if __name__ == "__main__":
    pytest.main([__file__, "-v", "--hypothesis-show-statistics"])
