"""
Lambda function to trigger Glue Crawler when new data arrives in prod bucket
"""
import json
import os
import logging
import boto3
from botocore.exceptions import ClientError

# Configure logging
log_level = os.environ.get('LOG_LEVEL', 'INFO')
logger = logging.getLogger()
logger.setLevel(log_level)

# Initialize Glue client
glue_client = boto3.client('glue')

# Get crawler name from environment
CRAWLER_NAME = os.environ.get('CRAWLER_NAME')


def handler(event, context):
    """
    Lambda handler function
    
    Args:
        event: S3 event notification
        context: Lambda context
        
    Returns:
        dict: Response with status code and message
    """
    logger.info(f"Received event: {json.dumps(event)}")
    
    if not CRAWLER_NAME:
        logger.error("CRAWLER_NAME environment variable not set")
        return {
            'statusCode': 500,
            'body': json.dumps({'error': 'CRAWLER_NAME not configured'})
        }
    
    try:
        # Parse S3 event
        for record in event.get('Records', []):
            bucket = record['s3']['bucket']['name']
            key = record['s3']['object']['key']
            
            logger.info(f"Processing S3 event: bucket={bucket}, key={key}")
            
            # Check if this is a Parquet file in the prod bucket
            if key.endswith('.parquet') and '-prod' in bucket:
                logger.info(f"Triggering Glue Crawler: {CRAWLER_NAME}")
                
                # Check crawler state first
                try:
                    response = glue_client.get_crawler(Name=CRAWLER_NAME)
                    crawler_state = response['Crawler']['State']
                    
                    logger.info(f"Crawler state: {crawler_state}")
                    
                    # Only start if crawler is READY
                    if crawler_state == 'READY':
                        glue_client.start_crawler(Name=CRAWLER_NAME)
                        logger.info(f"Successfully started crawler: {CRAWLER_NAME}")
                        
                        return {
                            'statusCode': 200,
                            'body': json.dumps({
                                'message': f'Crawler {CRAWLER_NAME} started successfully',
                                'bucket': bucket,
                                'key': key
                            })
                        }
                    else:
                        logger.warning(f"Crawler is not ready (state: {crawler_state}). Skipping trigger.")
                        return {
                            'statusCode': 200,
                            'body': json.dumps({
                                'message': f'Crawler {CRAWLER_NAME} is already running',
                                'state': crawler_state
                            })
                        }
                        
                except ClientError as e:
                    error_code = e.response['Error']['Code']
                    
                    if error_code == 'CrawlerRunningException':
                        logger.warning(f"Crawler {CRAWLER_NAME} is already running")
                        return {
                            'statusCode': 200,
                            'body': json.dumps({
                                'message': f'Crawler {CRAWLER_NAME} is already running'
                            })
                        }
                    else:
                        raise
            else:
                logger.info(f"Skipping non-Parquet file or non-prod bucket: {key}")
        
        return {
            'statusCode': 200,
            'body': json.dumps({'message': 'No crawler trigger needed'})
        }
        
    except Exception as e:
        logger.error(f"Error triggering crawler: {str(e)}", exc_info=True)
        return {
            'statusCode': 500,
            'body': json.dumps({
                'error': str(e),
                'crawler': CRAWLER_NAME
            })
        }
