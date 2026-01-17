"""
Main entry point for data processing jobs

This module orchestrates the data processing pipeline:
1. Raw to Curated: Validation, deduplication, compliance checks
2. Curated to Prod: Transformations and optimizations
"""

import os
import sys
import json
import logging
from typing import Dict, Any

import boto3
from botocore.exceptions import ClientError

from src.processors.raw_to_curated import RawToCuratedProcessor
from src.processors.curated_to_prod import CuratedToProdProcessor
from src.utils.logger import setup_logger
from src.utils.config import load_config

# Setup logger
logger = setup_logger(__name__)


def parse_s3_event(event: Dict[str, Any]) -> Dict[str, str]:
    """
    Parse S3 event to extract bucket and key information
    
    Args:
        event: AWS event dictionary
        
    Returns:
        Dictionary with bucket, key, and event type
    """
    try:
        # Handle S3 event from EventBridge
        if 'detail' in event and 'bucket' in event['detail']:
            bucket = event['detail']['bucket']['name']
            key = event['detail']['object']['key']
            event_type = event['detail-type']
        # Handle direct S3 event
        elif 'Records' in event:
            record = event['Records'][0]
            bucket = record['s3']['bucket']['name']
            key = record['s3']['object']['key']
            event_type = record['eventName']
        # Handle manual invocation
        else:
            bucket = event.get('bucket')
            key = event.get('key')
            event_type = event.get('event_type', 'manual')
        
        logger.info(f"Parsed S3 event: bucket={bucket}, key={key}, type={event_type}")
        return {
            'bucket': bucket,
            'key': key,
            'event_type': event_type
        }
    except (KeyError, IndexError) as e:
        logger.error(f"Failed to parse S3 event: {e}")
        raise ValueError(f"Invalid S3 event format: {e}")


def determine_processing_type(bucket: str, key: str) -> str:
    """
    Determine which processing pipeline to run based on bucket name
    
    Args:
        bucket: S3 bucket name
        key: S3 object key
        
    Returns:
        Processing type: 'raw-to-curated' or 'curated-to-prod'
    """
    if '-raw-' in bucket:
        return 'raw-to-curated'
    elif '-curated-' in bucket:
        return 'curated-to-prod'
    else:
        raise ValueError(f"Unknown bucket type: {bucket}")


def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """
    AWS Lambda/Batch handler for data processing jobs
    
    Args:
        event: AWS event dictionary
        context: AWS Lambda context
        
    Returns:
        Response dictionary with status and details
    """
    try:
        logger.info("Starting data processing job")
        logger.info(f"Event: {json.dumps(event)}")
        
        # Parse S3 event
        s3_info = parse_s3_event(event)
        bucket = s3_info['bucket']
        key = s3_info['key']
        
        # Determine processing type
        processing_type = determine_processing_type(bucket, key)
        logger.info(f"Processing type: {processing_type}")
        
        # Load configuration
        config = load_config()
        
        # Execute appropriate processor
        if processing_type == 'raw-to-curated':
            processor = RawToCuratedProcessor(config)
            result = processor.process(bucket, key)
        elif processing_type == 'curated-to-prod':
            processor = CuratedToProdProcessor(config)
            result = processor.process(bucket, key)
        else:
            raise ValueError(f"Unknown processing type: {processing_type}")
        
        logger.info(f"Processing completed successfully: {result}")
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'Processing completed successfully',
                'processing_type': processing_type,
                'result': result
            })
        }
        
    except Exception as e:
        logger.error(f"Processing failed: {e}", exc_info=True)
        
        return {
            'statusCode': 500,
            'body': json.dumps({
                'message': 'Processing failed',
                'error': str(e)
            })
        }


def main():
    """
    Main entry point for local testing and AWS Batch
    """
    # Get event from environment variable or command line
    event_json = os.environ.get('EVENT_JSON')
    
    if event_json:
        event = json.loads(event_json)
    elif len(sys.argv) > 1:
        with open(sys.argv[1], 'r') as f:
            event = json.load(f)
    else:
        # Default test event
        event = {
            'bucket': 'market-intelligence-hub-raw-123456789012',
            'key': 'ecommerce/customers-raw/year=2025/month=01/day=16/data-001.parquet',
            'event_type': 'manual'
        }
    
    # Execute handler
    result = lambda_handler(event, None)
    
    # Print result
    print(json.dumps(result, indent=2))
    
    # Exit with appropriate code
    sys.exit(0 if result['statusCode'] == 200 else 1)


if __name__ == '__main__':
    main()
