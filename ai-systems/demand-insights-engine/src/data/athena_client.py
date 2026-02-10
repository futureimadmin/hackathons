"""
Athena Client for Demand Insights Engine

Retrieves customer and sales data from AWS Athena.
"""

import boto3
import pandas as pd
import time
from typing import Dict, List, Optional
import logging

logger = logging.getLogger(__name__)


class AthenaClient:
    """
    Client for querying AWS Athena to retrieve customer and sales data.
    """
    
    def __init__(
        self,
        database: str = None,
        output_location: str = None,
        region: str = None,
        workgroup: str = None
    ):
        import os
        
        # Get from environment variables with fallbacks
        self.database = database or os.getenv('ATHENA_DATABASE', 'demand_insights_db')
        self.region = region or os.getenv('AWS_REGION', 'us-east-2')
        self.workgroup = 'primary'  # Always use primary workgroup for MVP
        
        # Set output location from environment or use default
        if output_location is None:
            self.output_location = os.getenv('ATHENA_OUTPUT_LOCATION')
            if not self.output_location:
                # Fallback to hardcoded value
                self.output_location = 's3://futureim-ecommerce-ai-platform-dev-athena-results-450133579764/'
        else:
            self.output_location = output_location
            
        self.client = boto3.client('athena', region_name=self.region)
    
    def execute_query(self, query: str, max_wait_time: int = 300) -> pd.DataFrame:
        """
        Execute Athena query and return results as DataFrame.
        
        Args:
            query: SQL query to execute
            max_wait_time: Maximum time to wait for query completion (seconds)
            
        Returns:
            DataFrame with query results
        """
        try:
            # Start query execution
            response = self.client.start_query_execution(
                QueryString=query,
                QueryExecutionContext={'Database': self.database},
                ResultConfiguration={'OutputLocation': self.output_location},
                WorkGroup=self.workgroup
            )
            
            query_execution_id = response['QueryExecutionId']
            logger.info(f"Started query execution: {query_execution_id}")
            
            # Wait for query to complete
            start_time = time.time()
            while True:
                if time.time() - start_time > max_wait_time:
                    raise TimeoutError(f"Query exceeded maximum wait time of {max_wait_time}s")
                
                status = self.client.get_query_execution(QueryExecutionId=query_execution_id)
                state = status['QueryExecution']['Status']['State']
                
                if state == 'SUCCEEDED':
                    break
                elif state in ['FAILED', 'CANCELLED']:
                    reason = status['QueryExecution']['Status'].get('StateChangeReason', 'Unknown')
                    raise Exception(f"Query {state}: {reason}")
                
                time.sleep(2)
            
            # Get results
            results = self.client.get_query_results(QueryExecutionId=query_execution_id)
            
            # Parse results into DataFrame
            columns = [col['Label'] for col in results['ResultSet']['ResultSetMetadata']['ColumnInfo']]
            rows = []
            
            for row in results['ResultSet']['Rows'][1:]:  # Skip header row
                rows.append([field.get('VarCharValue', None) for field in row['Data']])
            
            df = pd.DataFrame(rows, columns=columns)
            
            logger.info(f"Query completed: {len(df)} rows returned")
            
            return df
            
        except Exception as e:
            logger.error(f"Error executing Athena query: {str(e)}")
            raise
    
    def get_customer_data(
        self,
        customer_ids: Optional[List[str]] = None,
        limit: Optional[int] = None
    ) -> pd.DataFrame:
        """
        Retrieve customer data with RFM metrics.
        
        Args:
            customer_ids: Optional list of specific customer IDs
            limit: Optional limit on number of customers
            
        Returns:
            DataFrame with customer data
        """
        query = """
        SELECT 
            c.customer_id,
            c.email,
            c.first_name,
            c.last_name,
            c.created_at,
            DATEDIFF(day, MAX(o.order_date), CURRENT_DATE) as recency_days,
            COUNT(DISTINCT o.order_id) as frequency,
            SUM(o.total_amount) as monetary_total,
            AVG(o.total_amount) as avg_order_value,
            DATEDIFF(day, c.created_at, CURRENT_DATE) as customer_age_days,
            COUNT(DISTINCT oi.product_id) as unique_products_purchased,
            COUNT(DISTINCT p.category_id) as unique_categories_purchased,
            AVG(r.rating) as avg_rating,
            SUM(CASE WHEN o.status = 'returned' THEN 1 ELSE 0 END) * 1.0 / COUNT(o.order_id) as return_rate
        FROM customers c
        LEFT JOIN orders o ON c.customer_id = o.customer_id
        LEFT JOIN order_items oi ON o.order_id = oi.order_id
        LEFT JOIN products p ON oi.product_id = p.product_id
        LEFT JOIN reviews r ON c.customer_id = r.customer_id
        """
        
        if customer_ids:
            ids_str = "', '".join(customer_ids)
            query += f" WHERE c.customer_id IN ('{ids_str}')"
        
        query += " GROUP BY c.customer_id, c.email, c.first_name, c.last_name, c.created_at"
        
        if limit:
            query += f" LIMIT {limit}"
        
        return self.execute_query(query)
    
    def get_sales_data(
        self,
        start_date: Optional[str] = None,
        end_date: Optional[str] = None,
        product_ids: Optional[List[str]] = None
    ) -> pd.DataFrame:
        """
        Retrieve sales data for demand forecasting.
        
        Args:
            start_date: Start date (YYYY-MM-DD)
            end_date: End date (YYYY-MM-DD)
            product_ids: Optional list of product IDs
            
        Returns:
            DataFrame with sales data
        """
        query = """
        SELECT 
            DATE(o.order_date) as date,
            oi.product_id,
            p.name as product_name,
            p.category_id,
            c.name as category_name,
            SUM(oi.quantity) as quantity,
            AVG(oi.unit_price) as avg_price,
            SUM(oi.subtotal) as revenue,
            COUNT(DISTINCT o.order_id) as order_count,
            COUNT(DISTINCT o.customer_id) as unique_customers
        FROM orders o
        JOIN order_items oi ON o.order_id = oi.order_id
        JOIN products p ON oi.product_id = p.product_id
        JOIN categories c ON p.category_id = c.category_id
        WHERE o.status NOT IN ('cancelled', 'returned')
        """
        
        if start_date:
            query += f" AND o.order_date >= DATE '{start_date}'"
        if end_date:
            query += f" AND o.order_date <= DATE '{end_date}'"
        if product_ids:
            ids_str = "', '".join(product_ids)
            query += f" AND oi.product_id IN ('{ids_str}')"
        
        query += """
        GROUP BY DATE(o.order_date), oi.product_id, p.name, p.category_id, c.name
        ORDER BY date, product_id
        """
        
        return self.execute_query(query)
    
    def get_price_history(
        self,
        product_id: Optional[str] = None,
        category_id: Optional[str] = None
    ) -> pd.DataFrame:
        """
        Retrieve price history for elasticity analysis.
        
        Args:
            product_id: Optional product ID
            category_id: Optional category ID
            
        Returns:
            DataFrame with price and quantity data
        """
        query = """
        SELECT 
            DATE(o.order_date) as date,
            oi.product_id,
            p.name as product_name,
            p.category_id,
            AVG(oi.unit_price) as price,
            SUM(oi.quantity) as quantity,
            COUNT(DISTINCT o.order_id) as order_count
        FROM orders o
        JOIN order_items oi ON o.order_id = oi.order_id
        JOIN products p ON oi.product_id = p.product_id
        WHERE o.status NOT IN ('cancelled', 'returned')
        """
        
        if product_id:
            query += f" AND oi.product_id = '{product_id}'"
        if category_id:
            query += f" AND p.category_id = '{category_id}'"
        
        query += """
        GROUP BY DATE(o.order_date), oi.product_id, p.name, p.category_id
        HAVING SUM(oi.quantity) > 0
        ORDER BY date
        """
        
        return self.execute_query(query)
    
    def get_customer_segments_data(self) -> pd.DataFrame:
        """
        Retrieve data for customer segmentation analysis.
        
        Returns:
            DataFrame with customer segmentation data
        """
        query = """
        SELECT 
            c.customer_id,
            DATEDIFF(day, MAX(o.order_date), CURRENT_DATE) as recency_days,
            COUNT(DISTINCT o.order_id) as frequency,
            SUM(o.total_amount) as monetary_total,
            DATEDIFF(day, c.created_at, CURRENT_DATE) as customer_age_days,
            MIN(o.order_date) as first_order_date,
            MAX(o.order_date) as last_order_date
        FROM customers c
        LEFT JOIN orders o ON c.customer_id = o.customer_id
        WHERE o.status NOT IN ('cancelled')
        GROUP BY c.customer_id, c.created_at
        HAVING COUNT(o.order_id) > 0
        """
        
        return self.execute_query(query)
    
    def get_product_performance(self, days: int = 90) -> pd.DataFrame:
        """
        Retrieve product performance metrics.
        
        Args:
            days: Number of days to look back
            
        Returns:
            DataFrame with product performance data
        """
        query = f"""
        SELECT 
            p.product_id,
            p.name as product_name,
            p.category_id,
            c.name as category_name,
            SUM(oi.quantity) as total_quantity,
            SUM(oi.subtotal) as total_revenue,
            AVG(oi.unit_price) as avg_price,
            COUNT(DISTINCT o.order_id) as order_count,
            COUNT(DISTINCT o.customer_id) as unique_customers,
            AVG(r.rating) as avg_rating,
            COUNT(r.review_id) as review_count
        FROM products p
        LEFT JOIN order_items oi ON p.product_id = oi.product_id
        LEFT JOIN orders o ON oi.order_id = o.order_id
        LEFT JOIN categories c ON p.category_id = c.category_id
        LEFT JOIN reviews r ON p.product_id = r.product_id
        WHERE o.order_date >= CURRENT_DATE - INTERVAL '{days}' DAY
        AND o.status NOT IN ('cancelled', 'returned')
        GROUP BY p.product_id, p.name, p.category_id, c.name
        ORDER BY total_revenue DESC
        """
        
        return self.execute_query(query)
