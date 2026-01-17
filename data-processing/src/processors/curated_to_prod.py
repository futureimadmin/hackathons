"""
Curated to Production data processor

This processor:
1. Reads curated data from S3
2. Applies transformations (denormalization, aggregations)
3. Calculates derived columns
4. Optimizes for Athena (partitioning, compression)
5. Writes to production bucket
6. Triggers Glue Crawler
"""

from typing import Dict, Any
import pandas as pd
from datetime import datetime
import boto3

from src.utils.logger import setup_logger
from src.utils.s3_utils import S3Client

logger = setup_logger(__name__)


class CuratedToProdProcessor:
    """Processes curated data to production format"""
    
    def __init__(self, config: Any):
        self.config = config
        self.s3_client = S3Client(region=config.get('aws.region'))
        self.glue_client = boto3.client('glue', region_name=config.get('aws.region'))
    
    def process(self, bucket: str, key: str) -> Dict[str, Any]:
        """
        Process curated data file to production format
        
        Args:
            bucket: S3 bucket name
            key: S3 object key
            
        Returns:
            Processing result dictionary
        """
        start_time = datetime.now()
        
        logger.info(f"Starting curated-to-prod processing: s3://{bucket}/{key}")
        
        try:
            # Extract metadata from key
            metadata = self.s3_client.extract_metadata_from_key(key)
            schema = metadata['schema']
            table = metadata.get('table', '')
            
            logger.info(f"Processing table: {schema}.{table}")
            
            # Read curated data
            df = self.s3_client.read_parquet(bucket, key)
            initial_count = len(df)
            
            logger.info(f"Read {initial_count} records from curated bucket")
            
            # Apply transformations
            df = self._apply_transformations(df, table)
            
            # Optimize for Athena
            df = self._optimize_for_athena(df)
            
            # Determine prod bucket and key
            prod_bucket = bucket.replace('-curated-', '-prod-')
            prod_key = self.s3_client.construct_target_key(
                schema=schema,
                table=table,
                bucket_type='prod',
                year=metadata.get('year', ''),
                month=metadata.get('month', ''),
                day=metadata.get('day', ''),
                filename=metadata['filename']
            )
            
            # Write to prod bucket
            self.s3_client.write_parquet(df, prod_bucket, prod_key, compression='snappy')
            
            # Trigger Glue Crawler
            if self.config.get('glue.trigger_crawler', True):
                self._trigger_glue_crawler(schema, table)
            
            # Calculate processing time
            processing_time = (datetime.now() - start_time).total_seconds()
            
            result = {
                'status': 'success',
                'input_bucket': bucket,
                'input_key': key,
                'output_bucket': prod_bucket,
                'output_key': prod_key,
                'records': len(df),
                'processing_time_seconds': processing_time,
                'schema': schema,
                'table': table
            }
            
            logger.info(f"Curated-to-prod processing completed successfully: {result}")
            
            return result
            
        except Exception as e:
            logger.error(f"Curated-to-prod processing failed: {e}", exc_info=True)
            raise
    
    def _apply_transformations(self, df: pd.DataFrame, table_name: str) -> pd.DataFrame:
        """
        Apply table-specific transformations
        
        Args:
            df: DataFrame to transform
            table_name: Name of the table
            
        Returns:
            Transformed DataFrame
        """
        # Apply table-specific transformations
        if table_name == 'orders':
            df = self._transform_orders(df)
        elif table_name == 'customers':
            df = self._transform_customers(df)
        elif table_name == 'products':
            df = self._transform_products(df)
        elif table_name == 'order_items':
            df = self._transform_order_items(df)
        
        logger.info(f"Applied transformations for {table_name}")
        return df
    
    def _transform_orders(self, df: pd.DataFrame) -> pd.DataFrame:
        """Transform orders table"""
        # Calculate derived columns
        if 'order_date' in df.columns:
            df['order_date'] = pd.to_datetime(df['order_date'])
            df['order_year'] = df['order_date'].dt.year
            df['order_month'] = df['order_date'].dt.month
            df['order_day'] = df['order_date'].dt.day
            df['order_day_of_week'] = df['order_date'].dt.dayofweek
            
            # Calculate order age in days
            df['order_age_days'] = (datetime.now() - df['order_date']).dt.days
        
        return df
    
    def _transform_customers(self, df: pd.DataFrame) -> pd.DataFrame:
        """Transform customers table"""
        # Calculate customer lifetime metrics
        if 'signup_date' in df.columns:
            df['signup_date'] = pd.to_datetime(df['signup_date'])
            df['customer_age_days'] = (datetime.now() - df['signup_date']).dt.days
        
        # Placeholder for customer lifetime value calculation
        # This would typically join with orders data
        if 'total_spent' not in df.columns:
            df['total_spent'] = 0.0
        
        return df
    
    def _transform_products(self, df: pd.DataFrame) -> pd.DataFrame:
        """Transform products table"""
        # Calculate product metrics
        if 'price' in df.columns and 'cost' in df.columns:
            df['profit_margin'] = ((df['price'] - df['cost']) / df['price'] * 100).round(2)
        
        # Categorize products by price range
        if 'price' in df.columns:
            df['price_category'] = pd.cut(
                df['price'],
                bins=[0, 10, 50, 100, 500, float('inf')],
                labels=['budget', 'economy', 'standard', 'premium', 'luxury']
            )
        
        return df
    
    def _transform_order_items(self, df: pd.DataFrame) -> pd.DataFrame:
        """Transform order_items table"""
        # Calculate line item totals
        if 'quantity' in df.columns and 'unit_price' in df.columns:
            df['line_total'] = df['quantity'] * df['unit_price']
        
        # Calculate discount amount
        if 'discount_percent' in df.columns and 'line_total' in df.columns:
            df['discount_amount'] = (df['line_total'] * df['discount_percent'] / 100).round(2)
            df['final_amount'] = df['line_total'] - df['discount_amount']
        
        return df
    
    def _optimize_for_athena(self, df: pd.DataFrame) -> pd.DataFrame:
        """
        Optimize DataFrame for Athena queries
        
        Args:
            df: DataFrame to optimize
            
        Returns:
            Optimized DataFrame
        """
        # Convert datetime columns to proper format
        for col in df.select_dtypes(include=['datetime64']).columns:
            df[col] = pd.to_datetime(df[col])
        
        # Ensure proper data types for numeric columns
        for col in df.select_dtypes(include=['object']).columns:
            # Try to convert to numeric if all values are numeric strings
            try:
                if df[col].str.match(r'^\d+$').all():
                    df[col] = pd.to_numeric(df[col])
            except (AttributeError, TypeError):
                # Column is not string type or conversion failed
                pass
        
        # Sort by frequently filtered columns for better compression
        if 'order_date' in df.columns:
            df = df.sort_values('order_date')
        elif 'created_date' in df.columns:
            df = df.sort_values('created_date')
        elif 'timestamp' in df.columns:
            df = df.sort_values('timestamp')
        
        logger.info("Optimized DataFrame for Athena")
        return df
    
    def _trigger_glue_crawler(self, schema: str, table: str):
        """
        Trigger Glue Crawler to update catalog
        
        Args:
            schema: Database schema name
            table: Table name
        """
        try:
            # Determine crawler name based on schema
            # Crawler names follow pattern: {system}-{schema}-crawler
            crawler_name = f"{schema}-crawler"
            
            logger.info(f"Triggering Glue Crawler: {crawler_name}")
            
            # Start the crawler
            response = self.glue_client.start_crawler(Name=crawler_name)
            
            logger.info(f"Glue Crawler {crawler_name} triggered successfully")
            
        except self.glue_client.exceptions.CrawlerRunningException:
            logger.warning(f"Crawler {crawler_name} is already running")
        except self.glue_client.exceptions.EntityNotFoundException:
            logger.error(f"Crawler {crawler_name} not found")
        except Exception as e:
            logger.error(f"Failed to trigger Glue Crawler: {e}", exc_info=True)
            # Don't fail the entire job if crawler trigger fails
