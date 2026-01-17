"""
System Registration Lambda Handler
Handles registration of new AI systems
"""

import json
import os
import uuid
from datetime import datetime
from typing import Dict, Any
import boto3
from botocore.exceptions import ClientError

# Initialize AWS clients
dynamodb = boto3.resource('dynamodb')
table_name = os.environ['REGISTRY_TABLE_NAME']
table = dynamodb.Table(table_name)

def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """
    Handle system registration requests
    
    Event structure:
    {
        "system_name": "new-ai-system",
        "description": "Description of the system",
        "data_sources": ["mysql_table1", "mysql_table2"],
        "endpoints": [
            {"path": "/new-system/endpoint1", "method": "GET"},
            {"path": "/new-system/endpoint2", "method": "POST"}
        ],
        "lambda_config": {
            "memory": 1024,
            "timeout": 300,
            "runtime": "python3.11"
        }
    }
    """
    
    try:
        # Parse request body
        if 'body' in event:
            body = json.loads(event['body']) if isinstance(event['body'], str) else event['body']
        else:
            body = event
        
        # Validate required fields
        required_fields = ['system_name', 'description', 'data_sources']
        for field in required_fields:
            if field not in body:
                return error_response(400, f"Missing required field: {field}")
        
        # Generate system ID
        system_id = str(uuid.uuid4())
        
        # Prepare system record
        system_record = {
            'system_id': system_id,
            'system_name': body['system_name'],
            'description': body['description'],
            'data_sources': body['data_sources'],
            'endpoints': body.get('endpoints', []),
            'lambda_config': body.get('lambda_config', {
                'memory': 1024,
                'timeout': 300,
                'runtime': 'python3.11'
            }),
            'status': 'pending_provisioning',
            'created_at': datetime.utcnow().isoformat(),
            'updated_at': datetime.utcnow().isoformat(),
            'infrastructure': {
                's3_buckets': {
                    'raw': None,
                    'curated': None,
                    'prod': None
                },
                'glue_database': None,
                'glue_crawler': None,
                'dms_task': None,
                'eventbridge_rules': []
            }
        }
        
        # Check if system already exists
        try:
            response = table.query(
                IndexName='SystemNameIndex',
                KeyConditionExpression='system_name = :name',
                ExpressionAttributeValues={':name': body['system_name']}
            )
            
            if response['Items']:
                return error_response(409, f"System '{body['system_name']}' already exists")
        
        except ClientError as e:
            print(f"Error checking existing system: {e}")
            return error_response(500, "Error checking existing system")
        
        # Save to DynamoDB
        try:
            table.put_item(Item=system_record)
            print(f"System registered: {system_id}")
        
        except ClientError as e:
            print(f"Error saving system: {e}")
            return error_response(500, "Error saving system registration")
        
        # Return success response
        return {
            'statusCode': 201,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            'body': json.dumps({
                'message': 'System registered successfully',
                'system_id': system_id,
                'system_name': body['system_name'],
                'status': 'pending_provisioning',
                'note': 'Infrastructure provisioning will begin automatically'
            })
        }
    
    except json.JSONDecodeError:
        return error_response(400, "Invalid JSON in request body")
    
    except Exception as e:
        print(f"Unexpected error: {e}")
        return error_response(500, f"Internal server error: {str(e)}")


def error_response(status_code: int, message: str) -> Dict[str, Any]:
    """Generate error response"""
    return {
        'statusCode': status_code,
        'headers': {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*'
        },
        'body': json.dumps({
            'error': message
        })
    }
