"""
Raw to Curated data processor

This processor:
1. Reads raw data from S3
2. Validates schema and data quality
3. Deduplicates records
4. Checks compliance (PCI DSS)
5. Writes validated data to curated bucket
"""

from typing import Dict, Any
import pandas as pd
from datetime import datetime

from src.utils.logger import setup_logger
from src.utils.s3_utils import S3Client
from src.validators.schema_validator import SchemaValidator, get_default_schema
from src.validators.business_rules import BusinessRuleValidator
from src.validators.compliance_checker import ComplianceChecker

logger = setup_logger(__name__)


class RawToCuratedProcessor:
    """Processes raw data to curated format"""
    
    def __init__(self, config: Any):
        self.config = config
        self.s3_client = S3Client(region=config.get('aws.region'))
        self.schema_validator = SchemaValidator()
        self.business_validator = BusinessRuleValidator()
        self.compliance_checker = ComplianceChecker(config)
    
    def process(self, bucket: str, key: str) -> Dict[str, Any]:
        """
        Process raw data file to curated format
        
        Args:
            bucket: S3 bucket name
            key: S3 object key
            
        Returns:
            Processing result dictionary
        """
        start_time = datetime.now()
        
        logger.info(f"Starting raw-to-curated processing: s3://{bucket}/{key}")
        
        try:
            # Extract metadata from key
            metadata = self.s3_client.extract_metadata_from_key(key)
            schema = metadata['schema']
            table = metadata.get('table', '')
            
            logger.info(f"Processing table: {schema}.{table}")
            
            # Read raw data
            df = self.s3_client.read_parquet(bucket, key)
            initial_count = len(df)
            
            logger.info(f"Read {initial_count} records from raw bucket")
            
            # Validate schema
            table_schema = get_default_schema(table)
            if table_schema:
                self.schema_validator.expected_schema = table_schema
                schema_result = self.schema_validator.validate(df)
                
                if not schema_result.passed:
                    logger.error(f"Schema validation failed: {schema_result.errors}")
                    self._handle_validation_failure(bucket, key, df, schema_result)
                    return {
                        'status': 'failed',
                        'reason': 'schema_validation_failed',
                        'errors': schema_result.errors
                    }
            
            # Validate business rules
            business_result = self.business_validator.validate(df, table)
            
            if not business_result.passed:
                logger.error(f"Business rule validation failed: {business_result.errors}")
                self._handle_validation_failure(bucket, key, df, business_result)
                return {
                    'status': 'failed',
                    'reason': 'business_rule_validation_failed',
                    'errors': business_result.errors
                }
            
            # Deduplicate records
            if self.config.get('deduplication.enabled', True):
                df = self._deduplicate_records(df, metadata)
                dedup_count = initial_count - len(df)
                logger.info(f"Removed {dedup_count} duplicate records")
            else:
                dedup_count = 0
            
            # Check compliance
            compliance_result = self.compliance_checker.check_compliance(df, table)
            
            if not compliance_result.passed:
                logger.warning(f"Compliance issues found: {compliance_result.errors}")
                # Mask sensitive fields instead of failing
                df = self.compliance_checker.mask_sensitive_fields(df, table)
            
            # Determine curated bucket and key
            curated_bucket = bucket.replace('-raw-', '-curated-')
            curated_key = self.s3_client.construct_target_key(
                schema=schema,
                table=table,
                bucket_type='curated',
                year=metadata.get('year', ''),
                month=metadata.get('month', ''),
                day=metadata.get('day', ''),
                filename=metadata['filename']
            )
            
            # Write to curated bucket
            self.s3_client.write_parquet(df, curated_bucket, curated_key)
            
            # Calculate processing time
            processing_time = (datetime.now() - start_time).total_seconds()
            
            result = {
                'status': 'success',
                'input_bucket': bucket,
                'input_key': key,
                'output_bucket': curated_bucket,
                'output_key': curated_key,
                'initial_records': initial_count,
                'final_records': len(df),
                'duplicates_removed': dedup_count,
                'processing_time_seconds': processing_time,
                'schema': schema,
                'table': table
            }
            
            logger.info(f"Raw-to-curated processing completed successfully: {result}")
            
            return result
            
        except Exception as e:
            logger.error(f"Raw-to-curated processing failed: {e}", exc_info=True)
            raise
    
    def _deduplicate_records(self, df: pd.DataFrame, metadata: Dict[str, str]) -> pd.DataFrame:
        """
        Deduplicate records keeping the most recent
        
        Args:
            df: DataFrame to deduplicate
            metadata: Metadata with table information
            
        Returns:
            Deduplicated DataFrame
        """
        # Determine primary key columns
        primary_keys = self._get_primary_keys(metadata.get('table', ''))
        
        if not primary_keys:
            logger.warning(f"No primary keys defined for table {metadata.get('table')}, skipping deduplication")
            return df
        
        # Check if primary key columns exist
        missing_keys = [k for k in primary_keys if k not in df.columns]
        if missing_keys:
            logger.warning(f"Primary key columns {missing_keys} not found, skipping deduplication")
            return df
        
        # Get timestamp column
        timestamp_col = self.config.get('deduplication.timestamp_column', 'dms_timestamp')
        
        if timestamp_col not in df.columns:
            logger.warning(f"Timestamp column '{timestamp_col}' not found, using first occurrence")
            # Keep first occurrence
            df_deduped = df.drop_duplicates(subset=primary_keys, keep='first')
        else:
            # Sort by timestamp descending and keep first (most recent)
            df_sorted = df.sort_values(by=timestamp_col, ascending=False)
            df_deduped = df_sorted.drop_duplicates(subset=primary_keys, keep='first')
        
        return df_deduped
    
    def _get_primary_keys(self, table_name: str) -> list:
        """Get primary key columns for a table"""
        primary_keys = {
            'customers': ['customer_id'],
            'orders': ['order_id'],
            'order_items': ['order_item_id'],
            'products': ['product_id'],
            'categories': ['category_id'],
            'inventory': ['inventory_id'],
            'payments': ['payment_id'],
            'shipments': ['shipment_id'],
            'reviews': ['review_id'],
            'promotions': ['promotion_id']
        }
        
        return primary_keys.get(table_name, [])
    
    def _handle_validation_failure(
        self,
        bucket: str,
        key: str,
        df: pd.DataFrame,
        validation_result: Any
    ):
        """
        Handle validation failure by logging and optionally writing to error bucket
        
        Args:
            bucket: Source bucket
            key: Source key
            df: DataFrame that failed validation
            validation_result: Validation result with errors
        """
        # Log errors
        logger.error(f"Validation failed for s3://{bucket}/{key}")
        logger.error(f"Errors: {validation_result.errors}")
        logger.error(f"Warnings: {validation_result.warnings}")
        
        # Write failed records to error bucket (optional)
        error_bucket = bucket.replace('-raw-', '-errors-')
        error_key = f"validation-failures/{key}"
        
        try:
            self.s3_client.write_parquet(df, error_bucket, error_key)
            logger.info(f"Wrote failed records to s3://{error_bucket}/{error_key}")
        except Exception as e:
            logger.warning(f"Failed to write error records: {e}")
        
        # TODO: Send SNS notification to data engineering team
