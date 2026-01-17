"""
Shared fixtures and configuration for integration tests
"""

import pytest
import boto3
import os
from typing import Dict, Any
import requests
import time

# Configuration
PROJECT_NAME = os.getenv("PROJECT_NAME", "ecommerce-ai-platform")
AWS_REGION = os.getenv("AWS_REGION", "us-east-1")
API_BASE_URL = os.getenv("API_BASE_URL", "https://api.example.com")
TEST_USER_EMAIL = os.getenv("TEST_USER_EMAIL", "test@example.com")
TEST_USER_PASSWORD = os.getenv("TEST_USER_PASSWORD", "TestPassword123!")


# AWS Clients
@pytest.fixture(scope="session")
def s3_client():
    """Create S3 client"""
    return boto3.client('s3', region_name=AWS_REGION)


@pytest.fixture(scope="session")
def glue_client():
    """Create Glue client"""
    return boto3.client('glue', region_name=AWS_REGION)


@pytest.fixture(scope="session")
def athena_client():
    """Create Athena client"""
    return boto3.client('athena', region_name=AWS_REGION)


@pytest.fixture(scope="session")
def batch_client():
    """Create Batch client"""
    return boto3.client('batch', region_name=AWS_REGION)


@pytest.fixture(scope="session")
def dms_client():
    """Create DMS client"""
    return boto3.client('dms', region_name=AWS_REGION)


@pytest.fixture(scope="session")
def dynamodb_client():
    """Create DynamoDB client"""
    return boto3.client('dynamodb', region_name=AWS_REGION)


# Authentication
@pytest.fixture(scope="session")
def jwt_token():
    """Authenticate and get JWT token"""
    response = requests.post(
        f"{API_BASE_URL}/auth/login",
        json={
            "email": TEST_USER_EMAIL,
            "password": TEST_USER_PASSWORD
        }
    )
    
    if response.status_code != 200:
        pytest.fail(f"Authentication failed: {response.text}")
    
    return response.json()['token']


@pytest.fixture(scope="session")
def auth_headers(jwt_token):
    """Get authentication headers"""
    return {
        "Authorization": f"Bearer {jwt_token}",
        "Content-Type": "application/json"
    }


# Bucket names
@pytest.fixture(scope="session")
def raw_bucket():
    """Get raw bucket name"""
    return f"{PROJECT_NAME}-raw"


@pytest.fixture(scope="session")
def curated_bucket():
    """Get curated bucket name"""
    return f"{PROJECT_NAME}-curated"


@pytest.fixture(scope="session")
def prod_bucket():
    """Get prod bucket name"""
    return f"{PROJECT_NAME}-prod"


@pytest.fixture(scope="session")
def athena_output_bucket():
    """Get Athena output bucket name"""
    return f"{PROJECT_NAME}-athena-results"


# Database names
@pytest.fixture(scope="session")
def glue_database():
    """Get Glue database name"""
    return f"{PROJECT_NAME}_db"


# Helper functions
@pytest.fixture
def make_api_request(auth_headers):
    """Helper to make authenticated API requests"""
    def _make_request(method: str, endpoint: str, data: Dict[str, Any] = None) -> requests.Response:
        url = f"{API_BASE_URL}{endpoint}"
        
        if method == "GET":
            return requests.get(url, headers=auth_headers, params=data)
        elif method == "POST":
            return requests.post(url, headers=auth_headers, json=data)
        elif method == "PUT":
            return requests.put(url, headers=auth_headers, json=data)
        elif method == "DELETE":
            return requests.delete(url, headers=auth_headers)
        else:
            raise ValueError(f"Unsupported method: {method}")
    
    return _make_request


@pytest.fixture
def wait_for_s3_object(s3_client):
    """Helper to wait for S3 object to appear"""
    def _wait(bucket: str, prefix: str, search_term: str, max_wait: int = 60) -> bool:
        start_time = time.time()
        
        while time.time() - start_time < max_wait:
            try:
                response = s3_client.list_objects_v2(Bucket=bucket, Prefix=prefix)
                
                if 'Contents' in response:
                    for obj in response['Contents']:
                        if search_term in obj['Key']:
                            return True
                
                time.sleep(2)
            
            except Exception as e:
                print(f"Error checking S3: {e}")
                time.sleep(2)
        
        return False
    
    return _wait


@pytest.fixture
def execute_athena_query(athena_client, glue_database, athena_output_bucket):
    """Helper to execute Athena query"""
    def _execute(query: str, max_wait: int = 60) -> Dict[str, Any]:
        # Start query execution
        response = athena_client.start_query_execution(
            QueryString=query,
            QueryExecutionContext={'Database': glue_database},
            ResultConfiguration={
                'OutputLocation': f's3://{athena_output_bucket}/'
            }
        )
        
        query_execution_id = response['QueryExecutionId']
        
        # Wait for completion
        start_time = time.time()
        
        while time.time() - start_time < max_wait:
            status_response = athena_client.get_query_execution(
                QueryExecutionId=query_execution_id
            )
            
            status = status_response['QueryExecution']['Status']['State']
            
            if status == 'SUCCEEDED':
                # Get results
                results = athena_client.get_query_results(
                    QueryExecutionId=query_execution_id
                )
                return results
            
            elif status in ['FAILED', 'CANCELLED']:
                reason = status_response['QueryExecution']['Status'].get('StateChangeReason', 'Unknown')
                raise Exception(f"Query failed: {reason}")
            
            time.sleep(2)
        
        raise Exception(f"Query did not complete in {max_wait} seconds")
    
    return _execute


@pytest.fixture
def cleanup_s3_objects(s3_client):
    """Helper to cleanup S3 objects"""
    def _cleanup(bucket: str, prefix: str, search_term: str):
        try:
            response = s3_client.list_objects_v2(Bucket=bucket, Prefix=prefix)
            
            if 'Contents' in response:
                for obj in response['Contents']:
                    if search_term in obj['Key']:
                        s3_client.delete_object(Bucket=bucket, Key=obj['Key'])
        
        except Exception as e:
            print(f"Error cleaning up S3: {e}")
    
    return _cleanup


# Pytest configuration
def pytest_configure(config):
    """Configure pytest"""
    config.addinivalue_line(
        "markers", "slow: marks tests as slow (deselect with '-m \"not slow\"')"
    )
    config.addinivalue_line(
        "markers", "integration: marks tests as integration tests"
    )
    config.addinivalue_line(
        "markers", "e2e: marks tests as end-to-end tests"
    )


def pytest_collection_modifyitems(config, items):
    """Modify test collection"""
    for item in items:
        # Add integration marker to all tests in integration directory
        if "integration" in str(item.fspath):
            item.add_marker(pytest.mark.integration)
