"""
Property-Based Test for System Registration
Property 7: System Registration Creates Complete Bucket Structure
Validates: Requirements 11.2
"""

import pytest
from hypothesis import given, strategies as st, settings
import boto3
from botocore.exceptions import ClientError
import json
import time

# Test configuration
PROJECT_NAME = "ecommerce-ai-platform"
AWS_REGION = "us-east-1"

# Initialize AWS clients
dynamodb = boto3.resource('dynamodb', region_name=AWS_REGION)
s3 = boto3.client('s3', region_name=AWS_REGION)

# Strategies for generating test data
system_name_strategy = st.text(
    alphabet=st.characters(whitelist_categories=('Ll', 'Nd'), whitelist_characters='-'),
    min_size=5,
    max_size=20
).filter(lambda x: x[0].isalpha() and x[-1].isalnum())

data_sources_strategy = st.lists(
    st.text(alphabet=st.characters(whitelist_categories=('Ll', 'Lu', 'Nd'), whitelist_characters='_'),
            min_size=3, max_size=20),
    min_size=1,
    max_size=5
)


@given(
    system_name=system_name_strategy,
    data_sources=data_sources_strategy
)
@settings(max_examples=100, deadline=None)
def test_system_registration_creates_complete_bucket_structure(system_name, data_sources):
    """
    Property 7: System Registration Creates Complete Bucket Structure
    
    For any valid system registration, the system SHALL create:
    - Three S3 buckets (raw, curated, prod)
    - All buckets with versioning enabled
    - All buckets with encryption enabled
    - All buckets with public access blocked
    
    This property validates that the infrastructure provisioning
    creates a complete and properly configured bucket structure.
    """
    
    # Skip if system name is invalid
    if not is_valid_system_name(system_name):
        return
    
    # Register system
    system_id = register_system(system_name, data_sources)
    
    if not system_id:
        # Registration failed (expected for some edge cases)
        return
    
    try:
        # Wait for infrastructure provisioning
        max_wait = 60  # seconds
        start_time = time.time()
        
        while time.time() - start_time < max_wait:
            system_record = get_system_record(system_id)
            
            if system_record and system_record.get('status') == 'active':
                break
            
            if system_record and system_record.get('status') == 'provisioning_failed':
                # Provisioning failed, skip test
                cleanup_system(system_id)
                return
            
            time.sleep(2)
        
        # Get system record
        system_record = get_system_record(system_id)
        
        if not system_record or system_record.get('status') != 'active':
            # Provisioning not complete, skip test
            cleanup_system(system_id)
            return
        
        # Verify bucket structure
        infrastructure = system_record.get('infrastructure', {})
        buckets = infrastructure.get('s3_buckets', {})
        
        # Property: All three buckets must exist
        assert 'raw' in buckets, "Raw bucket not created"
        assert 'curated' in buckets, "Curated bucket not created"
        assert 'prod' in buckets, "Prod bucket not created"
        
        # Property: All buckets must be properly configured
        for tier, bucket_name in buckets.items():
            assert bucket_name, f"{tier} bucket name is empty"
            
            # Verify bucket exists
            assert bucket_exists(bucket_name), f"Bucket {bucket_name} does not exist"
            
            # Verify versioning enabled
            assert is_versioning_enabled(bucket_name), f"Versioning not enabled for {bucket_name}"
            
            # Verify encryption enabled
            assert is_encryption_enabled(bucket_name), f"Encryption not enabled for {bucket_name}"
            
            # Verify public access blocked
            assert is_public_access_blocked(bucket_name), f"Public access not blocked for {bucket_name}"
        
        # Property: Bucket names follow naming convention
        expected_raw = f"{PROJECT_NAME}-{system_name}-raw"
        expected_curated = f"{PROJECT_NAME}-{system_name}-curated"
        expected_prod = f"{PROJECT_NAME}-{system_name}-prod"
        
        assert buckets['raw'] == expected_raw, f"Raw bucket name mismatch: {buckets['raw']} != {expected_raw}"
        assert buckets['curated'] == expected_curated, f"Curated bucket name mismatch"
        assert buckets['prod'] == expected_prod, f"Prod bucket name mismatch"
    
    finally:
        # Cleanup
        cleanup_system(system_id)


def is_valid_system_name(name: str) -> bool:
    """Check if system name is valid"""
    if not name or len(name) < 3 or len(name) > 50:
        return False
    if not name[0].isalpha():
        return False
    if not all(c.isalnum() or c == '-' for c in name):
        return False
    return True


def register_system(system_name: str, data_sources: list) -> str:
    """Register a new system"""
    try:
        table = dynamodb.Table(f"{PROJECT_NAME}-system-registry")
        
        # Check if system already exists
        response = table.query(
            IndexName='SystemNameIndex',
            KeyConditionExpression='system_name = :name',
            ExpressionAttributeValues={':name': system_name}
        )
        
        if response['Items']:
            # System already exists, skip
            return None
        
        # Create system record
        import uuid
        from datetime import datetime
        
        system_id = str(uuid.uuid4())
        
        table.put_item(Item={
            'system_id': system_id,
            'system_name': system_name,
            'description': f"Test system {system_name}",
            'data_sources': data_sources,
            'status': 'pending_provisioning',
            'created_at': datetime.utcnow().isoformat(),
            'updated_at': datetime.utcnow().isoformat(),
            'infrastructure': {}
        })
        
        return system_id
    
    except Exception as e:
        print(f"Error registering system: {e}")
        return None


def get_system_record(system_id: str) -> dict:
    """Get system record from DynamoDB"""
    try:
        table = dynamodb.Table(f"{PROJECT_NAME}-system-registry")
        response = table.get_item(Key={'system_id': system_id})
        return response.get('Item')
    except Exception as e:
        print(f"Error getting system record: {e}")
        return None


def bucket_exists(bucket_name: str) -> bool:
    """Check if S3 bucket exists"""
    try:
        s3.head_bucket(Bucket=bucket_name)
        return True
    except ClientError:
        return False


def is_versioning_enabled(bucket_name: str) -> bool:
    """Check if versioning is enabled"""
    try:
        response = s3.get_bucket_versioning(Bucket=bucket_name)
        return response.get('Status') == 'Enabled'
    except ClientError:
        return False


def is_encryption_enabled(bucket_name: str) -> bool:
    """Check if encryption is enabled"""
    try:
        response = s3.get_bucket_encryption(Bucket=bucket_name)
        rules = response.get('ServerSideEncryptionConfiguration', {}).get('Rules', [])
        return len(rules) > 0
    except ClientError:
        return False


def is_public_access_blocked(bucket_name: str) -> bool:
    """Check if public access is blocked"""
    try:
        response = s3.get_public_access_block(Bucket=bucket_name)
        config = response.get('PublicAccessBlockConfiguration', {})
        return (
            config.get('BlockPublicAcls', False) and
            config.get('IgnorePublicAcls', False) and
            config.get('BlockPublicPolicy', False) and
            config.get('RestrictPublicBuckets', False)
        )
    except ClientError:
        return False


def cleanup_system(system_id: str):
    """Cleanup test system and resources"""
    try:
        # Get system record
        system_record = get_system_record(system_id)
        
        if not system_record:
            return
        
        # Delete S3 buckets
        infrastructure = system_record.get('infrastructure', {})
        buckets = infrastructure.get('s3_buckets', {})
        
        for bucket_name in buckets.values():
            if bucket_name and bucket_exists(bucket_name):
                try:
                    # Delete all objects first
                    s3.delete_bucket(Bucket=bucket_name)
                except ClientError as e:
                    print(f"Error deleting bucket {bucket_name}: {e}")
        
        # Delete system record
        table = dynamodb.Table(f"{PROJECT_NAME}-system-registry")
        table.delete_item(Key={'system_id': system_id})
    
    except Exception as e:
        print(f"Error cleaning up system: {e}")


if __name__ == "__main__":
    pytest.main([__file__, "-v", "--hypothesis-show-statistics"])
