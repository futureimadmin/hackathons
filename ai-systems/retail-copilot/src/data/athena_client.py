"""
AWS Athena Client for Retail Copilot

Provides data access through AWS Athena for querying S3 data lake.
"""

import time
import logging
from typing import Optional, List, Dict
import boto3
import pandas as pd
from botocore.exceptions import ClientError

logger = logging.getLogger(__name__)


class AthenaClient:
    """
    Client for executing queries against AWS Athena.
    """
    
    def __init__(
        self,
        database: str,
        output_location: str,
        region: str = 'us-east-1',
        max_execution_time: int = 300
    ):
        """
        Initialize Athena client.
        
        Args:
            database: Athena database name
            output_location: S3 location for query results
            region: AWS region
            max_execution_time: Maximum query execution time in seconds
        """
        self.database = database
        self.output_location = output_location
        self.max_execution_time = max_execution_time
        self.client = boto3.client('athena', region_name=region)
        self.s3_client = boto3.client('s3', region_name=region)
    
    def execute_query(
        self,
        query: str,
        parameters: Optional[Dict] = None
    ) -> pd.DataFrame:
        """
        Execute SQL query and return results as DataFrame.
        
        Args:
            query: SQL query string
            parameters: Query parameters for parameterized queries
            
        Returns:
            Query results as pandas DataFrame
        """
        try:
            # Start query execution
            execution_id = self._start_query_execution(query)
            
            # Wait for query to complete
            self._wait_for_query_completion(execution_id)
            
            # Get query results
            results = self._get_query_results(execution_id)
            
            return results
        
        except Exception as e:
            logger.error(f"Error executing Athena query: {str(e)}")
            raise
    
    def _start_query_execution(self, query: str) -> str:
        """Start query execution and return execution ID."""
        try:
            response = self.client.start_query_execution(
                QueryString=query,
                QueryExecutionContext={'Database': self.database},
                ResultConfiguration={'OutputLocation': self.output_location}
            )
            
            execution_id = response['QueryExecutionId']
            logger.info(f"Started query execution: {execution_id}")
            
            return execution_id
        
        except ClientError as e:
            logger.error(f"Error starting query execution: {str(e)}")
            raise
    
    def _wait_for_query_completion(self, execution_id: str) -> None:
        """Wait for query to complete."""
        start_time = time.time()
        
        while True:
            # Check if max execution time exceeded
            if time.time() - start_time > self.max_execution_time:
                raise TimeoutError(f"Query execution exceeded {self.max_execution_time} seconds")
            
            # Get query execution status
            try:
                response = self.client.get_query_execution(QueryExecutionId=execution_id)
                status = response['QueryExecution']['Status']['State']
                
                if status == 'SUCCEEDED':
                    logger.info(f"Query {execution_id} succeeded")
                    return
                
                elif status == 'FAILED':
                    reason = response['QueryExecution']['Status'].get('StateChangeReason', 'Unknown')
                    raise Exception(f"Query failed: {reason}")
                
                elif status == 'CANCELLED':
                    raise Exception("Query was cancelled")
                
                # Query still running, wait and retry
                time.sleep(1)
            
            except ClientError as e:
                logger.error(f"Error checking query status: {str(e)}")
                raise
    
    def _get_query_results(self, execution_id: str) -> pd.DataFrame:
        """Get query results and convert to DataFrame."""
        try:
            # Get results
            results = []
            next_token = None
            
            while True:
                if next_token:
                    response = self.client.get_query_results(
                        QueryExecutionId=execution_id,
                        NextToken=next_token
                    )
                else:
                    response = self.client.get_query_results(QueryExecutionId=execution_id)
                
                # Extract rows
                rows = response['ResultSet']['Rows']
                
                # First row is header
                if not results:
                    headers = [col['VarCharValue'] for col in rows[0]['Data']]
                    rows = rows[1:]  # Skip header row
                
                # Extract data
                for row in rows:
                    row_data = []
                    for col in row['Data']:
                        row_data.append(col.get('VarCharValue'))
                    results.append(row_data)
                
                # Check for more results
                next_token = response.get('NextToken')
                if not next_token:
                    break
            
            # Convert to DataFrame
            if results:
                df = pd.DataFrame(results, columns=headers)
                return df
            else:
                return pd.DataFrame()
        
        except ClientError as e:
            logger.error(f"Error getting query results: {str(e)}")
            raise
    
    def get_inventory_data(self, limit: int = 100) -> pd.DataFrame:
        """Get inventory data."""
        query = f"""
        SELECT 
            p.product_id,
            p.name,
            p.category_id,
            p.price,
            i.quantity_available,
            i.quantity_reserved,
            i.warehouse_location,
            i.last_updated
        FROM products p
        JOIN inventory i ON p.product_id = i.product_id
        WHERE p.is_active = true
        ORDER BY i.last_updated DESC
        LIMIT {limit}
        """
        
        return self.execute_query(query)
    
    def get_order_data(self, limit: int = 100, status: Optional[str] = None) -> pd.DataFrame:
        """Get order data."""
        query = f"""
        SELECT 
            o.order_id,
            o.customer_id,
            o.order_date,
            o.status,
            o.total_amount,
            o.payment_method,
            c.first_name,
            c.last_name,
            c.email
        FROM orders o
        JOIN customers c ON o.customer_id = c.customer_id
        """
        
        if status:
            query += f" WHERE o.status = '{status}'"
        
        query += f" ORDER BY o.order_date DESC LIMIT {limit}"
        
        return self.execute_query(query)
    
    def get_customer_data(self, limit: int = 100) -> pd.DataFrame:
        """Get customer data."""
        query = f"""
        SELECT 
            customer_id,
            email,
            first_name,
            last_name,
            phone,
            country,
            city,
            total_orders,
            total_spent,
            created_at
        FROM customers
        ORDER BY total_spent DESC
        LIMIT {limit}
        """
        
        return self.execute_query(query)
    
    def get_product_recommendations(self, customer_id: str, limit: int = 10) -> pd.DataFrame:
        """Get product recommendations for a customer."""
        query = f"""
        SELECT 
            p.product_id,
            p.name,
            p.category_id,
            p.price,
            COUNT(DISTINCT oi.order_id) as purchase_count,
            AVG(r.rating) as avg_rating
        FROM products p
        LEFT JOIN order_items oi ON p.product_id = oi.product_id
        LEFT JOIN orders o ON oi.order_id = o.order_id
        LEFT JOIN reviews r ON p.product_id = r.product_id
        WHERE o.customer_id != '{customer_id}'
        AND p.is_active = true
        GROUP BY p.product_id, p.name, p.category_id, p.price
        ORDER BY purchase_count DESC, avg_rating DESC
        LIMIT {limit}
        """
        
        return self.execute_query(query)
    
    def get_sales_report(self, days: int = 30) -> pd.DataFrame:
        """Get sales report for specified days."""
        query = f"""
        SELECT 
            DATE_TRUNC('day', o.order_date) as date,
            COUNT(DISTINCT o.order_id) as total_orders,
            COUNT(DISTINCT o.customer_id) as unique_customers,
            SUM(o.total_amount) as total_revenue,
            AVG(o.total_amount) as avg_order_value
        FROM orders o
        WHERE o.order_date >= CURRENT_DATE - INTERVAL '{days}' DAY
        GROUP BY DATE_TRUNC('day', o.order_date)
        ORDER BY date DESC
        """
        
        return self.execute_query(query)
