"""
Athena Client for Global Market Pulse

Provides data access methods for market analysis queries.
"""

import boto3
import pandas as pd
import time
import logging
from typing import Optional, List, Dict, Any

logger = logging.getLogger(__name__)


class AthenaClient:
    """
    Client for querying data from AWS Athena.
    """
    
    def __init__(self, database: str, output_location: str, region: str = 'us-east-1'):
        """
        Initialize Athena client.
        
        Args:
            database: Athena database name
            output_location: S3 location for query results
            region: AWS region
        """
        self.database = database
        self.output_location = output_location
        self.region = region
        self.client = boto3.client('athena', region_name=region)
        self.s3_client = boto3.client('s3', region_name=region)
    
    def execute_query(self, query: str, max_wait_time: int = 60) -> pd.DataFrame:
        """
        Execute Athena query and return results as DataFrame.
        
        Args:
            query: SQL query string
            max_wait_time: Maximum time to wait for query completion (seconds)
        
        Returns:
            DataFrame with query results
        """
        try:
            # Start query execution
            response = self.client.start_query_execution(
                QueryString=query,
                QueryExecutionContext={'Database': self.database},
                ResultConfiguration={'OutputLocation': self.output_location}
            )
            
            query_execution_id = response['QueryExecutionId']
            logger.info(f"Started query execution: {query_execution_id}")
            
            # Wait for query to complete
            start_time = time.time()
            while True:
                if time.time() - start_time > max_wait_time:
                    raise TimeoutError(f"Query execution exceeded {max_wait_time} seconds")
                
                status = self.client.get_query_execution(QueryExecutionId=query_execution_id)
                state = status['QueryExecution']['Status']['State']
                
                if state == 'SUCCEEDED':
                    break
                elif state in ['FAILED', 'CANCELLED']:
                    reason = status['QueryExecution']['Status'].get('StateChangeReason', 'Unknown')
                    raise Exception(f"Query {state}: {reason}")
                
                time.sleep(1)
            
            # Get query results
            result = self.client.get_query_results(QueryExecutionId=query_execution_id)
            
            # Parse results into DataFrame
            df = self._parse_query_results(result)
            
            logger.info(f"Query returned {len(df)} rows")
            return df
        
        except Exception as e:
            logger.error(f"Error executing query: {str(e)}")
            raise
    
    def _parse_query_results(self, result: Dict) -> pd.DataFrame:
        """Parse Athena query results into DataFrame."""
        rows = result['ResultSet']['Rows']
        
        if len(rows) == 0:
            return pd.DataFrame()
        
        # Extract column names from first row
        columns = [col['VarCharValue'] for col in rows[0]['Data']]
        
        # Extract data rows
        data = []
        for row in rows[1:]:
            data.append([col.get('VarCharValue', None) for col in row['Data']])
        
        return pd.DataFrame(data, columns=columns)
    
    def get_market_trends(self, region: Optional[str] = None, days: int = 90) -> pd.DataFrame:
        """
        Get market trend data.
        
        Args:
            region: Optional region filter
            days: Number of days of historical data
        
        Returns:
            DataFrame with market trend data
        """
        query = f"""
        SELECT 
            DATE(order_date) as date,
            {'region,' if region else ''}
            COUNT(DISTINCT order_id) as order_count,
            SUM(total_amount) as total_sales,
            AVG(total_amount) as avg_order_value,
            COUNT(DISTINCT customer_id) as unique_customers
        FROM orders
        WHERE order_date >= DATE_ADD('day', -{days}, CURRENT_DATE)
        """
        
        if region:
            query += f" AND region = '{region}'"
        
        query += """
        GROUP BY DATE(order_date)""" + (", region" if region else "") + """
        ORDER BY date
        """
        
        return self.execute_query(query)
    
    def get_regional_prices(self, product_ids: Optional[List[str]] = None, limit: int = 1000) -> pd.DataFrame:
        """
        Get regional pricing data.
        
        Args:
            product_ids: Optional list of product IDs to filter
            limit: Maximum number of records
        
        Returns:
            DataFrame with regional pricing data
        """
        query = f"""
        SELECT 
            p.product_id,
            p.name as product_name,
            p.category_id,
            p.price,
            'USD' as currency,
            o.shipping_country as region,
            COUNT(DISTINCT o.order_id) as order_count,
            SUM(oi.quantity) as total_quantity
        FROM products p
        LEFT JOIN order_items oi ON p.product_id = oi.product_id
        LEFT JOIN orders o ON oi.order_id = o.order_id
        WHERE o.order_date >= DATE_ADD('day', -90, CURRENT_DATE)
        """
        
        if product_ids:
            product_list = "', '".join(product_ids)
            query += f" AND p.product_id IN ('{product_list}')"
        
        query += f"""
        GROUP BY p.product_id, p.name, p.category_id, p.price, o.shipping_country
        LIMIT {limit}
        """
        
        return self.execute_query(query)
    
    def get_competitor_data(self, region: Optional[str] = None, limit: int = 500) -> pd.DataFrame:
        """
        Get competitor data (simulated from product categories).
        
        Args:
            region: Optional region filter
            limit: Maximum number of records
        
        Returns:
            DataFrame with competitor data
        """
        query = f"""
        SELECT 
            c.name as competitor,
            p.product_id,
            p.name as product_name,
            p.price,
            o.shipping_country as region,
            SUM(oi.quantity) as sales_quantity,
            SUM(oi.quantity * oi.price_at_purchase) as sales_revenue
        FROM categories c
        JOIN products p ON c.category_id = p.category_id
        LEFT JOIN order_items oi ON p.product_id = oi.product_id
        LEFT JOIN orders o ON oi.order_id = o.order_id
        WHERE o.order_date >= DATE_ADD('day', -90, CURRENT_DATE)
        """
        
        if region:
            query += f" AND o.shipping_country = '{region}'"
        
        query += f"""
        GROUP BY c.name, p.product_id, p.name, p.price, o.shipping_country
        LIMIT {limit}
        """
        
        return self.execute_query(query)
    
    def get_market_opportunity_data(self, limit: int = 100) -> pd.DataFrame:
        """
        Get data for market opportunity scoring.
        
        Args:
            limit: Maximum number of records
        
        Returns:
            DataFrame with market opportunity data
        """
        query = f"""
        SELECT 
            o.shipping_country as region,
            COUNT(DISTINCT o.order_id) as market_size,
            SUM(o.total_amount) as total_revenue,
            AVG(o.total_amount) as avg_order_value,
            COUNT(DISTINCT o.customer_id) as unique_customers,
            COUNT(DISTINCT p.product_id) as product_variety,
            AVG(p.price) as avg_price
        FROM orders o
        JOIN order_items oi ON o.order_id = oi.order_id
        JOIN products p ON oi.product_id = p.product_id
        WHERE o.order_date >= DATE_ADD('day', -90, CURRENT_DATE)
        GROUP BY o.shipping_country
        HAVING COUNT(DISTINCT o.order_id) > 10
        ORDER BY total_revenue DESC
        LIMIT {limit}
        """
        
        return self.execute_query(query)
    
    def get_regional_growth_rates(self, days: int = 180) -> pd.DataFrame:
        """
        Calculate growth rates by region.
        
        Args:
            days: Number of days for growth calculation
        
        Returns:
            DataFrame with regional growth rates
        """
        query = f"""
        WITH monthly_sales AS (
            SELECT 
                shipping_country as region,
                DATE_TRUNC('month', order_date) as month,
                SUM(total_amount) as monthly_revenue
            FROM orders
            WHERE order_date >= DATE_ADD('day', -{days}, CURRENT_DATE)
            GROUP BY shipping_country, DATE_TRUNC('month', order_date)
        ),
        growth_calc AS (
            SELECT 
                region,
                month,
                monthly_revenue,
                LAG(monthly_revenue) OVER (PARTITION BY region ORDER BY month) as prev_month_revenue
            FROM monthly_sales
        )
        SELECT 
            region,
            AVG(CASE 
                WHEN prev_month_revenue > 0 
                THEN ((monthly_revenue - prev_month_revenue) / prev_month_revenue * 100)
                ELSE 0 
            END) as avg_growth_rate,
            SUM(monthly_revenue) as total_revenue,
            COUNT(DISTINCT month) as months_count
        FROM growth_calc
        WHERE prev_month_revenue IS NOT NULL
        GROUP BY region
        HAVING COUNT(DISTINCT month) >= 2
        ORDER BY avg_growth_rate DESC
        """
        
        return self.execute_query(query)
    
    def get_external_market_data(self, limit: int = 100) -> pd.DataFrame:
        """
        Get external market data (placeholder for external data integration).
        
        Args:
            limit: Maximum number of records
        
        Returns:
            DataFrame with external market data
        """
        # This is a placeholder - in production, this would integrate with external APIs
        query = f"""
        SELECT 
            shipping_country as region,
            COUNT(DISTINCT customer_id) as customer_base,
            AVG(total_amount) as avg_transaction,
            STDDEV(total_amount) as transaction_volatility
        FROM orders
        WHERE order_date >= DATE_ADD('day', -365, CURRENT_DATE)
        GROUP BY shipping_country
        LIMIT {limit}
        """
        
        return self.execute_query(query)
