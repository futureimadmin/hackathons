"""
Athena Client

Handles data retrieval from AWS Athena for Market Intelligence Hub.
"""

import boto3
import pandas as pd
import time
import logging
from typing import Dict, List, Optional
from pyathena import connect
from pyathena.pandas.cursor import PandasCursor

logger = logging.getLogger(__name__)


class AthenaClient:
    """Client for querying data from AWS Athena."""
    
    def __init__(
        self,
        database: str = 'market_intelligence_hub',
        s3_staging_dir: str = None,
        region_name: str = 'us-east-1',
        workgroup: str = 'primary'
    ):
        """
        Initialize Athena client.
        
        Args:
            database: Athena database name
            s3_staging_dir: S3 location for query results
            region_name: AWS region
            workgroup: Athena workgroup name
        """
        self.database = database
        self.region_name = region_name
        self.workgroup = workgroup
        
        if s3_staging_dir is None:
            # Get from environment - use ATHENA_OUTPUT_LOCATION which is set by Lambda
            import os
            self.s3_staging_dir = os.getenv('ATHENA_OUTPUT_LOCATION')
            if not self.s3_staging_dir:
                # Fallback to hardcoded value
                self.s3_staging_dir = 's3://futureim-ecommerce-ai-platform-dev-athena-results-450133579764/'
        else:
            self.s3_staging_dir = s3_staging_dir
        
        self.athena_client = boto3.client('athena', region_name=region_name)
        
    def execute_query(self, query: str, timeout: int = 300) -> pd.DataFrame:
        """
        Execute Athena query and return results as DataFrame.
        
        Args:
            query: SQL query to execute
            timeout: Query timeout in seconds
            
        Returns:
            DataFrame with query results
        """
        logger.info(f"Executing Athena query: {query[:100]}...")
        
        try:
            # Use pyathena for easier DataFrame conversion
            conn = connect(
                s3_staging_dir=self.s3_staging_dir,
                region_name=self.region_name,
                cursor_class=PandasCursor,
                work_group=self.workgroup
            )
            
            df = pd.read_sql(query, conn)
            logger.info(f"Query returned {len(df)} rows")
            
            return df
            
        except Exception as e:
            logger.error(f"Error executing query: {str(e)}")
            raise
    
    def get_sales_data(
        self,
        start_date: str,
        end_date: str,
        product_id: Optional[str] = None,
        category_id: Optional[str] = None
    ) -> pd.DataFrame:
        """
        Get sales data for forecasting.
        
        Args:
            start_date: Start date (YYYY-MM-DD)
            end_date: End date (YYYY-MM-DD)
            product_id: Optional product ID filter
            category_id: Optional category ID filter
            
        Returns:
            DataFrame with date and sales columns
        """
        query = f"""
        SELECT 
            DATE(o.order_date) as date,
            SUM(oi.total) as sales,
            COUNT(DISTINCT o.order_id) as order_count,
            SUM(oi.quantity) as quantity_sold
        FROM {self.database}.ecommerce_orders_prod o
        JOIN {self.database}.ecommerce_order_items_prod oi 
            ON o.order_id = oi.order_id
        WHERE o.order_date >= DATE '{start_date}'
            AND o.order_date <= DATE '{end_date}'
            AND o.order_status = 'completed'
        """
        
        if product_id:
            query += f" AND oi.product_id = '{product_id}'"
        if category_id:
            query += f" AND oi.product_id IN (SELECT product_id FROM {self.database}.ecommerce_products_prod WHERE category_id = '{category_id}')"
        
        query += """
        GROUP BY DATE(o.order_date)
        ORDER BY date
        """
        
        df = self.execute_query(query)
        
        # Convert date column to datetime
        if not df.empty:
            df['date'] = pd.to_datetime(df['date'])
            df = df.set_index('date')
        
        return df
    
    def get_product_sales_by_category(
        self,
        start_date: str,
        end_date: str
    ) -> pd.DataFrame:
        """
        Get sales aggregated by product category.
        
        Args:
            start_date: Start date (YYYY-MM-DD)
            end_date: End date (YYYY-MM-DD)
            
        Returns:
            DataFrame with category sales
        """
        query = f"""
        SELECT 
            c.name as category_name,
            c.category_id,
            SUM(oi.total) as total_sales,
            COUNT(DISTINCT o.order_id) as order_count,
            SUM(oi.quantity) as quantity_sold,
            AVG(oi.unit_price) as avg_price
        FROM {self.database}.ecommerce_orders_prod o
        JOIN {self.database}.ecommerce_order_items_prod oi 
            ON o.order_id = oi.order_id
        JOIN {self.database}.ecommerce_products_prod p 
            ON oi.product_id = p.product_id
        JOIN {self.database}.ecommerce_categories_prod c 
            ON p.category_id = c.category_id
        WHERE o.order_date >= DATE '{start_date}'
            AND o.order_date <= DATE '{end_date}'
            AND o.order_status = 'completed'
        GROUP BY c.name, c.category_id
        ORDER BY total_sales DESC
        """
        
        return self.execute_query(query)
    
    def get_market_trends(
        self,
        start_date: str,
        end_date: str
    ) -> pd.DataFrame:
        """
        Get market trend data from market_intelligence schema.
        
        Args:
            start_date: Start date (YYYY-MM-DD)
            end_date: End date (YYYY-MM-DD)
            
        Returns:
            DataFrame with market trends
        """
        query = f"""
        SELECT 
            trend_date,
            trend_type,
            metric_name,
            metric_value,
            growth_rate
        FROM {self.database}.market_intelligence_trends_prod
        WHERE trend_date >= DATE '{start_date}'
            AND trend_date <= DATE '{end_date}'
        ORDER BY trend_date
        """
        
        df = self.execute_query(query)
        
        if not df.empty:
            df['trend_date'] = pd.to_datetime(df['trend_date'])
        
        return df
    
    def get_competitive_pricing(
        self,
        product_id: Optional[str] = None
    ) -> pd.DataFrame:
        """
        Get competitive pricing data.
        
        Args:
            product_id: Optional product ID filter
            
        Returns:
            DataFrame with competitive pricing
        """
        query = f"""
        SELECT 
            product_id,
            competitor_name,
            competitor_price,
            our_price,
            price_difference,
            price_difference_pct,
            last_updated
        FROM {self.database}.market_intelligence_competitive_pricing_prod
        """
        
        if product_id:
            query += f" WHERE product_id = '{product_id}'"
        
        query += " ORDER BY last_updated DESC"
        
        return self.execute_query(query)
    
    def get_forecast_history(
        self,
        metric: str,
        limit: int = 100
    ) -> pd.DataFrame:
        """
        Get historical forecasts for comparison.
        
        Args:
            metric: Metric name (e.g., 'sales', 'demand')
            limit: Maximum number of records
            
        Returns:
            DataFrame with forecast history
        """
        query = f"""
        SELECT 
            forecast_date,
            metric_name,
            forecast_value,
            actual_value,
            model_used,
            confidence_lower,
            confidence_upper
        FROM {self.database}.market_intelligence_forecasts_prod
        WHERE metric_name = '{metric}'
        ORDER BY forecast_date DESC
        LIMIT {limit}
        """
        
        df = self.execute_query(query)
        
        if not df.empty:
            df['forecast_date'] = pd.to_datetime(df['forecast_date'])
        
        return df
