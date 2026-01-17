"""
S3 utility functions for data processing
"""

import io
from typing import Optional, Dict, Any
import pandas as pd
import boto3
from botocore.exceptions import ClientError

from src.utils.logger import setup_logger

logger = setup_logger(__name__)


class S3Client:
    """Wrapper for S3 operations"""
    
    def __init__(self, region: Optional[str] = None):
        self.s3_client = boto3.client('s3', region_name=region)
        self.s3_resource = boto3.resource('s3', region_name=region)
    
    def read_parquet(self, bucket: str, key: str) -> pd.DataFrame:
        """
        Read Parquet file from S3
        
        Args:
            bucket: S3 bucket name
            key: S3 object key
            
        Returns:
            DataFrame with data
        """
        try:
            logger.info(f"Reading Parquet file: s3://{bucket}/{key}")
            
            # Get object from S3
            obj = self.s3_client.get_object(Bucket=bucket, Key=key)
            
            # Read Parquet data
            df = pd.read_parquet(io.BytesIO(obj['Body'].read()))
            
            logger.info(f"Read {len(df)} records from Parquet file")
            return df
            
        except ClientError as e:
            logger.error(f"Failed to read Parquet file: {e}")
            raise
        except Exception as e:
            logger.error(f"Error reading Parquet file: {e}")
            raise
    
    def write_parquet(
        self,
        df: pd.DataFrame,
        bucket: str,
        key: str,
        compression: str = 'snappy'
    ) -> Dict[str, Any]:
        """
        Write DataFrame to S3 as Parquet
        
        Args:
            df: DataFrame to write
            bucket: S3 bucket name
            key: S3 object key
            compression: Compression algorithm (snappy, gzip, none)
            
        Returns:
            S3 put_object response
        """
        try:
            logger.info(f"Writing {len(df)} records to s3://{bucket}/{key}")
            
            # Write DataFrame to bytes buffer
            buffer = io.BytesIO()
            df.to_parquet(
                buffer,
                engine='pyarrow',
                compression=compression,
                index=False
            )
            buffer.seek(0)
            
            # Upload to S3
            response = self.s3_client.put_object(
                Bucket=bucket,
                Key=key,
                Body=buffer.getvalue(),
                ContentType='application/octet-stream'
            )
            
            logger.info(f"Successfully wrote Parquet file to S3")
            return response
            
        except ClientError as e:
            logger.error(f"Failed to write Parquet file: {e}")
            raise
        except Exception as e:
            logger.error(f"Error writing Parquet file: {e}")
            raise
    
    def parse_s3_path(self, s3_path: str) -> tuple:
        """
        Parse S3 path into bucket and key
        
        Args:
            s3_path: S3 path (s3://bucket/key or bucket/key)
            
        Returns:
            Tuple of (bucket, key)
        """
        if s3_path.startswith('s3://'):
            s3_path = s3_path[5:]
        
        parts = s3_path.split('/', 1)
        bucket = parts[0]
        key = parts[1] if len(parts) > 1 else ''
        
        return bucket, key
    
    def extract_metadata_from_key(self, key: str) -> Dict[str, str]:
        """
        Extract metadata from S3 key path
        
        Expected format: {schema}/{table}-{type}/year={year}/month={month}/day={day}/file.parquet
        
        Args:
            key: S3 object key
            
        Returns:
            Dictionary with metadata
        """
        parts = key.split('/')
        
        metadata = {
            'schema': parts[0] if len(parts) > 0 else '',
            'table_type': parts[1] if len(parts) > 1 else '',
            'year': '',
            'month': '',
            'day': '',
            'filename': parts[-1] if len(parts) > 0 else ''
        }
        
        # Extract table name and type
        if metadata['table_type']:
            if '-' in metadata['table_type']:
                table_parts = metadata['table_type'].rsplit('-', 1)
                metadata['table'] = table_parts[0]
                metadata['type'] = table_parts[1]
            else:
                metadata['table'] = metadata['table_type']
                metadata['type'] = ''
        
        # Extract partition values
        for part in parts:
            if '=' in part:
                k, v = part.split('=', 1)
                if k in ['year', 'month', 'day']:
                    metadata[k] = v
        
        return metadata
    
    def construct_target_key(
        self,
        schema: str,
        table: str,
        bucket_type: str,
        year: str,
        month: str,
        day: str,
        filename: str
    ) -> str:
        """
        Construct target S3 key with partitioning
        
        Args:
            schema: Database schema name
            table: Table name
            bucket_type: Bucket type (curated, prod)
            year: Year partition
            month: Month partition
            day: Day partition
            filename: Output filename
            
        Returns:
            S3 key path
        """
        key = f"{schema}/{table}-{bucket_type}"
        
        if year:
            key += f"/year={year}"
        if month:
            key += f"/month={month}"
        if day:
            key += f"/day={day}"
        
        key += f"/{filename}"
        
        return key
    
    def list_objects(self, bucket: str, prefix: str) -> list:
        """
        List objects in S3 bucket with prefix
        
        Args:
            bucket: S3 bucket name
            prefix: Object key prefix
            
        Returns:
            List of object keys
        """
        try:
            logger.info(f"Listing objects in s3://{bucket}/{prefix}")
            
            paginator = self.s3_client.get_paginator('list_objects_v2')
            pages = paginator.paginate(Bucket=bucket, Prefix=prefix)
            
            keys = []
            for page in pages:
                if 'Contents' in page:
                    keys.extend([obj['Key'] for obj in page['Contents']])
            
            logger.info(f"Found {len(keys)} objects")
            return keys
            
        except ClientError as e:
            logger.error(f"Failed to list objects: {e}")
            raise
