"""
Infrastructure Provisioner Lambda Handler
Automatically provisions infrastructure for registered systems
"""

import json
import os
from datetime import datetime
from typing import Dict, Any, List
import boto3
from botocore.exceptions import ClientError

# Initialize AWS clients
dynamodb = boto3.resource('dynamodb')
s3 = boto3.client('s3')
glue = boto3.client('glue')
dms = boto3.client('dms')
events = boto3.client('events')

# Environment variables
table_name = os.environ['REGISTRY_TABLE_NAME']
project_name = os.environ['PROJECT_NAME']
aws_region = os.environ['AWS_REGION']
kms_key_id = os.environ['KMS_KEY_ID']
data_lake_bucket = os.environ['DATA_LAKE_BUCKET']

table = dynamodb.Table(table_name)

def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """
    Handle infrastructure provisioning triggered by DynamoDB Stream
    """
    
    try:
        print(f"Received event: {json.dumps(event)}")
        
        # Process each record from DynamoDB Stream
        for record in event['Records']:
            if record['eventName'] in ['INSERT', 'MODIFY']:
                # Get new image
                new_image = record['dynamodb']['NewImage']
                
                # Check if status is pending_provisioning
                if new_image.get('status', {}).get('S') == 'pending_provisioning':
                    system_id = new_image['system_id']['S']
                    system_name = new_image['system_name']['S']
                    
                    print(f"Provisioning infrastructure for system: {system_name} ({system_id})")
                    
                    # Get full system record
                    system_record = get_system_record(system_id)
                    
                    if not system_record:
                        print(f"System record not found: {system_id}")
                        continue
                    
                    # Provision infrastructure
                    try:
                        infrastructure = provision_infrastructure(system_record)
                        
                        # Update system record with infrastructure details
                        update_system_status(
                            system_id,
                            'active',
                            infrastructure
                        )
                        
                        print(f"Infrastructure provisioned successfully for {system_name}")
                    
                    except Exception as e:
                        print(f"Error provisioning infrastructure: {e}")
                        update_system_status(
                            system_id,
                            'provisioning_failed',
                            {},
                            str(e)
                        )
        
        return {'statusCode': 200, 'body': 'Processing complete'}
    
    except Exception as e:
        print(f"Unexpected error: {e}")
        return {'statusCode': 500, 'body': str(e)}


def get_system_record(system_id: str) -> Dict[str, Any]:
    """Get system record from DynamoDB"""
    try:
        response = table.get_item(Key={'system_id': system_id})
        return response.get('Item')
    except ClientError as e:
        print(f"Error getting system record: {e}")
        return None


def provision_infrastructure(system: Dict[str, Any]) -> Dict[str, Any]:
    """
    Provision complete infrastructure for a system
    """
    system_name = system['system_name']
    infrastructure = {}
    
    # 1. Create S3 buckets
    print(f"Creating S3 buckets for {system_name}")
    buckets = create_s3_buckets(system_name)
    infrastructure['s3_buckets'] = buckets
    
    # 2. Create Glue database
    print(f"Creating Glue database for {system_name}")
    database = create_glue_database(system_name)
    infrastructure['glue_database'] = database
    
    # 3. Create Glue Crawler
    print(f"Creating Glue Crawler for {system_name}")
    crawler = create_glue_crawler(system_name, buckets['prod'], database)
    infrastructure['glue_crawler'] = crawler
    
    # 4. Create EventBridge rules
    print(f"Creating EventBridge rules for {system_name}")
    rules = create_eventbridge_rules(system_name, buckets)
    infrastructure['eventbridge_rules'] = rules
    
    # 5. Create DMS task (if data sources specified)
    if system.get('data_sources'):
        print(f"Creating DMS replication task for {system_name}")
        dms_task = create_dms_task(system_name, system['data_sources'], buckets['raw'])
        infrastructure['dms_task'] = dms_task
    
    return infrastructure


def create_s3_buckets(system_name: str) -> Dict[str, str]:
    """Create S3 buckets for raw, curated, and prod data"""
    buckets = {}
    
    for tier in ['raw', 'curated', 'prod']:
        bucket_name = f"{project_name}-{system_name}-{tier}"
        
        try:
            # Create bucket
            if aws_region == 'us-east-1':
                s3.create_bucket(Bucket=bucket_name)
            else:
                s3.create_bucket(
                    Bucket=bucket_name,
                    CreateBucketConfiguration={'LocationConstraint': aws_region}
                )
            
            # Enable versioning
            s3.put_bucket_versioning(
                Bucket=bucket_name,
                VersioningConfiguration={'Status': 'Enabled'}
            )
            
            # Enable encryption
            s3.put_bucket_encryption(
                Bucket=bucket_name,
                ServerSideEncryptionConfiguration={
                    'Rules': [{
                        'ApplyServerSideEncryptionByDefault': {
                            'SSEAlgorithm': 'aws:kms',
                            'KMSMasterKeyID': kms_key_id
                        }
                    }]
                }
            )
            
            # Block public access
            s3.put_public_access_block(
                Bucket=bucket_name,
                PublicAccessBlockConfiguration={
                    'BlockPublicAcls': True,
                    'IgnorePublicAcls': True,
                    'BlockPublicPolicy': True,
                    'RestrictPublicBuckets': True
                }
            )
            
            buckets[tier] = bucket_name
            print(f"Created bucket: {bucket_name}")
        
        except ClientError as e:
            if e.response['Error']['Code'] == 'BucketAlreadyOwnedByYou':
                buckets[tier] = bucket_name
                print(f"Bucket already exists: {bucket_name}")
            else:
                raise
    
    return buckets


def create_glue_database(system_name: str) -> str:
    """Create Glue database"""
    database_name = f"{project_name}_{system_name}_db"
    
    try:
        glue.create_database(
            DatabaseInput={
                'Name': database_name,
                'Description': f"Database for {system_name} system"
            }
        )
        print(f"Created Glue database: {database_name}")
    
    except ClientError as e:
        if e.response['Error']['Code'] == 'AlreadyExistsException':
            print(f"Glue database already exists: {database_name}")
        else:
            raise
    
    return database_name


def create_glue_crawler(system_name: str, prod_bucket: str, database: str) -> str:
    """Create Glue Crawler"""
    crawler_name = f"{project_name}-{system_name}-crawler"
    
    try:
        glue.create_crawler(
            Name=crawler_name,
            Role=f"arn:aws:iam::{get_account_id()}:role/{project_name}-glue-role",
            DatabaseName=database,
            Targets={
                'S3Targets': [{
                    'Path': f"s3://{prod_bucket}/"
                }]
            },
            Schedule='cron(0 */6 * * ? *)',  # Every 6 hours
            SchemaChangePolicy={
                'UpdateBehavior': 'UPDATE_IN_DATABASE',
                'DeleteBehavior': 'LOG'
            }
        )
        print(f"Created Glue Crawler: {crawler_name}")
    
    except ClientError as e:
        if e.response['Error']['Code'] == 'AlreadyExistsException':
            print(f"Glue Crawler already exists: {crawler_name}")
        else:
            raise
    
    return crawler_name


def create_eventbridge_rules(system_name: str, buckets: Dict[str, str]) -> List[str]:
    """Create EventBridge rules for data pipeline orchestration"""
    rules = []
    
    # Rule for raw bucket events
    rule_name = f"{project_name}-{system_name}-raw-to-curated"
    
    try:
        events.put_rule(
            Name=rule_name,
            EventPattern=json.dumps({
                'source': ['aws.s3'],
                'detail-type': ['Object Created'],
                'detail': {
                    'bucket': {'name': [buckets['raw']]}
                }
            }),
            State='ENABLED',
            Description=f"Trigger processing for {system_name} raw data"
        )
        
        rules.append(rule_name)
        print(f"Created EventBridge rule: {rule_name}")
    
    except ClientError as e:
        print(f"Error creating EventBridge rule: {e}")
    
    return rules


def create_dms_task(system_name: str, data_sources: List[str], target_bucket: str) -> str:
    """Create DMS replication task"""
    task_name = f"{project_name}-{system_name}-replication"
    
    # Note: This is a simplified version
    # In production, you would need to configure source/target endpoints
    # and table mappings based on data_sources
    
    print(f"DMS task creation skipped (requires manual endpoint configuration): {task_name}")
    return task_name


def update_system_status(
    system_id: str,
    status: str,
    infrastructure: Dict[str, Any],
    error_message: str = None
):
    """Update system status in DynamoDB"""
    try:
        update_expression = "SET #status = :status, updated_at = :updated_at, infrastructure = :infrastructure"
        expression_values = {
            ':status': status,
            ':updated_at': datetime.utcnow().isoformat(),
            ':infrastructure': infrastructure
        }
        
        if error_message:
            update_expression += ", error_message = :error"
            expression_values[':error'] = error_message
        
        table.update_item(
            Key={'system_id': system_id},
            UpdateExpression=update_expression,
            ExpressionAttributeNames={'#status': 'status'},
            ExpressionAttributeValues=expression_values
        )
        
        print(f"Updated system status to: {status}")
    
    except ClientError as e:
        print(f"Error updating system status: {e}")


def get_account_id() -> str:
    """Get AWS account ID"""
    sts = boto3.client('sts')
    return sts.get_caller_identity()['Account']
