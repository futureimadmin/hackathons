"""
End-to-End Integration Test for Data Pipeline
Tests: MySQL → DMS → S3 → Batch → Glue → Athena
Validates: Requirements 23.1, 23.2, 23.3
"""

import pytest
import boto3
import time
import json
from datetime import datetime
from typing import Dict, Any, List
import pymysql

# AWS clients
s3 = boto3.client('s3')
glue = boto3.client('glue')
athena = boto3.client('athena')
batch = boto3.client('batch')
dms = boto3.client('dms')

# Configuration
PROJECT_NAME = "ecommerce-ai-platform"
AWS_REGION = "us-east-1"
ATHENA_OUTPUT_BUCKET = f"{PROJECT_NAME}-athena-results"


class TestDataPipelineE2E:
    """End-to-end integration tests for data pipeline"""
    
    @pytest.fixture(scope="class")
    def mysql_connection(self):
        """Create MySQL connection"""
        conn = pymysql.connect(
            host='localhost',
            user='root',
            password='password',
            database='ecommerce',
            cursorclass=pymysql.cursors.DictCursor
        )
        yield conn
        conn.close()
    
    @pytest.fixture(scope="class")
    def test_data(self, mysql_connection):
        """Insert test data into MySQL"""
        cursor = mysql_connection.cursor()
        
        # Insert test customer
        test_customer_id = f"TEST_{int(time.time())}"
        cursor.execute("""
            INSERT INTO customers (customer_id, email, first_name, last_name, created_at)
            VALUES (%s, %s, %s, %s, %s)
        """, (test_customer_id, f"{test_customer_id}@test.com", "Test", "User", datetime.now()))
        
        # Insert test order
        test_order_id = f"ORD_{int(time.time())}"
        cursor.execute("""
            INSERT INTO orders (order_id, customer_id, order_date, total_amount, status)
            VALUES (%s, %s, %s, %s, %s)
        """, (test_order_id, test_customer_id, datetime.now(), 100.00, 'completed'))
        
        mysql_connection.commit()
        
        yield {
            'customer_id': test_customer_id,
            'order_id': test_order_id
        }
        
        # Cleanup
        cursor.execute("DELETE FROM orders WHERE order_id = %s", (test_order_id,))
        cursor.execute("DELETE FROM customers WHERE customer_id = %s", (test_customer_id,))
        mysql_connection.commit()
    
    def test_01_dms_replication_active(self):
        """Test: DMS replication task is running"""
        response = dms.describe_replication_tasks(
            Filters=[
                {'Name': 'replication-task-id', 'Values': [f'{PROJECT_NAME}-*']}
            ]
        )
        
        assert len(response['ReplicationTasks']) > 0, "No DMS replication tasks found"
        
        for task in response['ReplicationTasks']:
            assert task['Status'] in ['running', 'starting'], \
                f"DMS task {task['ReplicationTaskIdentifier']} is not running: {task['Status']}"
    
    def test_02_data_appears_in_s3_raw(self, test_data):
        """Test: Data from MySQL appears in S3 raw bucket"""
        bucket_name = f"{PROJECT_NAME}-raw"
        
        # Wait for DMS replication (max 60 seconds)
        max_wait = 60
        start_time = time.time()
        found = False
        
        while time.time() - start_time < max_wait:
            try:
                # List objects in raw bucket
                response = s3.list_objects_v2(
                    Bucket=bucket_name,
                    Prefix='customers/'
                )
                
                if 'Contents' in response:
                    # Check if our test data is present
                    for obj in response['Contents']:
                        # Download and check content
                        content = s3.get_object(Bucket=bucket_name, Key=obj['Key'])
                        data = content['Body'].read().decode('utf-8')
                        
                        if test_data['customer_id'] in data:
                            found = True
                            break
                
                if found:
                    break
                
                time.sleep(5)
            
            except Exception as e:
                print(f"Error checking S3: {e}")
                time.sleep(5)
        
        assert found, f"Test data not found in S3 raw bucket after {max_wait} seconds"
    
    def test_03_batch_job_processes_data(self):
        """Test: Batch job processes raw data to curated"""
        # Trigger batch job
        response = batch.submit_job(
            jobName=f'test-raw-to-curated-{int(time.time())}',
            jobQueue=f'{PROJECT_NAME}-job-queue',
            jobDefinition=f'{PROJECT_NAME}-raw-to-curated'
        )
        
        job_id = response['jobId']
        
        # Wait for job completion (max 5 minutes)
        max_wait = 300
        start_time = time.time()
        
        while time.time() - start_time < max_wait:
            job_status = batch.describe_jobs(jobs=[job_id])['jobs'][0]
            status = job_status['status']
            
            if status == 'SUCCEEDED':
                break
            elif status in ['FAILED', 'CANCELLED']:
                pytest.fail(f"Batch job failed with status: {status}")
            
            time.sleep(10)
        
        assert status == 'SUCCEEDED', f"Batch job did not complete in {max_wait} seconds"
    
    def test_04_data_appears_in_s3_curated(self, test_data):
        """Test: Validated data appears in S3 curated bucket"""
        bucket_name = f"{PROJECT_NAME}-curated"
        
        # Check for curated data
        response = s3.list_objects_v2(
            Bucket=bucket_name,
            Prefix='customers/'
        )
        
        assert 'Contents' in response, "No data found in curated bucket"
        assert len(response['Contents']) > 0, "Curated bucket is empty"
    
    def test_05_data_appears_in_s3_prod(self):
        """Test: Transformed data appears in S3 prod bucket"""
        bucket_name = f"{PROJECT_NAME}-prod"
        
        # Check for prod data
        response = s3.list_objects_v2(
            Bucket=bucket_name,
            Prefix='customers/'
        )
        
        assert 'Contents' in response, "No data found in prod bucket"
        assert len(response['Contents']) > 0, "Prod bucket is empty"
    
    def test_06_glue_crawler_runs(self):
        """Test: Glue crawler runs and updates catalog"""
        crawler_name = f"{PROJECT_NAME}-crawler"
        
        # Start crawler
        try:
            glue.start_crawler(Name=crawler_name)
        except glue.exceptions.CrawlerRunningException:
            pass  # Already running
        
        # Wait for crawler completion (max 5 minutes)
        max_wait = 300
        start_time = time.time()
        
        while time.time() - start_time < max_wait:
            response = glue.get_crawler(Name=crawler_name)
            state = response['Crawler']['State']
            
            if state == 'READY':
                break
            
            time.sleep(10)
        
        assert state == 'READY', f"Crawler did not complete in {max_wait} seconds"
    
    def test_07_athena_can_query_data(self, test_data):
        """Test: Athena can query data from Glue catalog"""
        database = f"{PROJECT_NAME}_db"
        query = f"""
            SELECT * FROM customers 
            WHERE customer_id = '{test_data['customer_id']}'
            LIMIT 10
        """
        
        # Execute query
        response = athena.start_query_execution(
            QueryString=query,
            QueryExecutionContext={'Database': database},
            ResultConfiguration={
                'OutputLocation': f's3://{ATHENA_OUTPUT_BUCKET}/'
            }
        )
        
        query_execution_id = response['QueryExecutionId']
        
        # Wait for query completion
        max_wait = 60
        start_time = time.time()
        
        while time.time() - start_time < max_wait:
            status = athena.get_query_execution(
                QueryExecutionId=query_execution_id
            )['QueryExecution']['Status']['State']
            
            if status == 'SUCCEEDED':
                break
            elif status in ['FAILED', 'CANCELLED']:
                pytest.fail(f"Athena query failed with status: {status}")
            
            time.sleep(2)
        
        assert status == 'SUCCEEDED', "Athena query did not complete"
        
        # Get results
        results = athena.get_query_results(QueryExecutionId=query_execution_id)
        
        assert len(results['ResultSet']['Rows']) > 1, "No data returned from Athena"
    
    def test_08_data_consistency_across_stages(self, test_data):
        """Test: Data is consistent across all pipeline stages"""
        # This test validates Property 10: Data Consistency Across Pipeline Stages
        
        # Get data from each stage
        raw_data = self._get_data_from_s3(f"{PROJECT_NAME}-raw", 'customers/', test_data['customer_id'])
        curated_data = self._get_data_from_s3(f"{PROJECT_NAME}-curated", 'customers/', test_data['customer_id'])
        prod_data = self._get_data_from_s3(f"{PROJECT_NAME}-prod", 'customers/', test_data['customer_id'])
        
        # Verify data consistency
        assert raw_data is not None, "Data not found in raw bucket"
        assert curated_data is not None, "Data not found in curated bucket"
        assert prod_data is not None, "Data not found in prod bucket"
        
        # Verify key fields match
        assert raw_data['customer_id'] == curated_data['customer_id'] == prod_data['customer_id']
        assert raw_data['email'] == curated_data['email'] == prod_data['email']
    
    def _get_data_from_s3(self, bucket: str, prefix: str, customer_id: str) -> Dict[str, Any]:
        """Helper: Get data from S3 bucket"""
        try:
            response = s3.list_objects_v2(Bucket=bucket, Prefix=prefix)
            
            if 'Contents' not in response:
                return None
            
            for obj in response['Contents']:
                content = s3.get_object(Bucket=bucket, Key=obj['Key'])
                data = content['Body'].read().decode('utf-8')
                
                if customer_id in data:
                    # Parse data (assuming JSON or CSV)
                    lines = data.split('\n')
                    for line in lines:
                        if customer_id in line:
                            # Simple parsing (adjust based on actual format)
                            return json.loads(line) if line.startswith('{') else None
            
            return None
        
        except Exception as e:
            print(f"Error getting data from S3: {e}")
            return None


if __name__ == "__main__":
    pytest.main([__file__, "-v", "--tb=short"])
