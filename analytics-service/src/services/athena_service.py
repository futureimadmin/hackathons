"""
Athena Service

Handles all Athena query execution and data retrieval.
Implements SQL injection prevention and query optimization.
"""

import boto3
import logging
import time
from typing import Dict, List, Any, Optional
from datetime import datetime, timedelta
from pyathena import connect
from pyathena.pandas.cursor import PandasCursor

logger = logging.getLogger(__name__)


class AthenaService:
    """Service for executing Athena queries and retrieving analytics data."""
    
    # Whitelist of allowed table names to prevent SQL injection
    ALLOWED_TABLES = {
        'customers', 'products', 'categories', 'orders', 'order_items',
        'inventory', 'payments', 'shipments', 'reviews', 'promotions',
        'market_forecasts', 'market_trends', 'competitive_pricing',
        'customer_segments', 'demand_forecasts', 'price_elasticity', 'customer_lifetime_value',
        'fraud_detections', 'compliance_checks', 'risk_scores',
        'copilot_conversations', 'copilot_messages', 'product_recommendations',
        'regional_market_data', 'market_opportunities', 'competitor_analysis'
    }
    
    # Whitelist of allowed column names for filtering
    ALLOWED_COLUMNS = {
        'customer_id', 'product_id', 'order_id', 'category_id',
        'order_date', 'created_at', 'updated_at',
        'status', 'region', 'country', 'state',
        'price', 'quantity', 'total_amount',
        'risk_score', 'fraud_probability'
    }
    
    def __init__(self, database: str, output_location: str, workgroup: str = 'primary'):
        """
        Initialize Athena service.
        
        Args:
            database: Athena database name
            output_location: S3 location for query results
            workgroup: Athena workgroup name
        """
        self.database = database
        self.output_location = output_location
        self.workgroup = workgroup
        self.athena_client = boto3.client('athena')
        
    def _get_connection(self):
        """Get PyAthena connection."""
        return connect(
            s3_staging_dir=self.output_location,
            region_name=boto3.Session().region_name,
            cursor_class=PandasCursor,
            work_group=self.workgroup
        )
    
    def _validate_table_name(self, table: str) -> str:
        """
        Validate and sanitize table name to prevent SQL injection.
        
        Args:
            table: Table name to validate
            
        Returns:
            Validated table name
            
        Raises:
            ValueError: If table name is invalid
        """
        if table not in self.ALLOWED_TABLES:
            raise ValueError(f"Invalid table name: {table}")
        return table
    
    def _validate_column_name(self, column: str) -> str:
        """
        Validate and sanitize column name to prevent SQL injection.
        
        Args:
            column: Column name to validate
            
        Returns:
            Validated column name
            
        Raises:
            ValueError: If column name is invalid
        """
        if column not in self.ALLOWED_COLUMNS:
            raise ValueError(f"Invalid column name: {column}")
        return column
    
    def _build_where_clause(self, filters: Dict[str, Any]) -> str:
        """
        Build WHERE clause from filters with SQL injection prevention.
        
        Args:
            filters: Dictionary of column: value pairs
            
        Returns:
            WHERE clause string
        """
        if not filters:
            return ""
        
        conditions = []
        for column, value in filters.items():
            # Validate column name
            validated_column = self._validate_column_name(column)
            
            # Handle different value types
            if isinstance(value, str):
                # Escape single quotes
                escaped_value = value.replace("'", "''")
                conditions.append(f"{validated_column} = '{escaped_value}'")
            elif isinstance(value, (int, float)):
                conditions.append(f"{validated_column} = {value}")
            elif isinstance(value, list):
                # IN clause
                if all(isinstance(v, str) for v in value):
                    escaped_values = [v.replace("'", "''") for v in value]
                    values_str = "', '".join(escaped_values)
                    conditions.append(f"{validated_column} IN ('{values_str}')")
                else:
                    values_str = ", ".join(str(v) for v in value)
                    conditions.append(f"{validated_column} IN ({values_str})")
        
        return " WHERE " + " AND ".join(conditions) if conditions else ""
    
    def query_table(self, table: str, limit: int = 100, filters: Optional[Dict[str, Any]] = None) -> List[Dict[str, Any]]:
        """
        Query a table with optional filters.
        
        Args:
            table: Table name
            limit: Maximum number of rows to return
            filters: Optional dictionary of filters
            
        Returns:
            List of rows as dictionaries
        """
        try:
            # Validate table name
            validated_table = self._validate_table_name(table)
            
            # Build query
            where_clause = self._build_where_clause(filters or {})
            query = f"SELECT * FROM {self.database}.{validated_table}{where_clause} LIMIT {limit}"
            
            logger.info(f"Executing query: {query}")
            
            # Execute query
            conn = self._get_connection()
            cursor = conn.cursor()
            df = cursor.execute(query).as_pandas()
            
            # Convert to list of dictionaries
            result = df.to_dict('records')
            
            logger.info(f"Query returned {len(result)} rows")
            return result
            
        except Exception as e:
            logger.error(f"Error executing query: {str(e)}", exc_info=True)
            raise
    
    def execute_query(self, query: str) -> List[Dict[str, Any]]:
        """
        Execute a custom Athena query.
        
        WARNING: This method should only be used with pre-validated queries.
        Do not pass user input directly to this method.
        
        Args:
            query: SQL query to execute
            
        Returns:
            List of rows as dictionaries
        """
        try:
            logger.info(f"Executing custom query: {query[:100]}...")
            
            conn = self._get_connection()
            cursor = conn.cursor()
            df = cursor.execute(query).as_pandas()
            
            result = df.to_dict('records')
            logger.info(f"Query returned {len(result)} rows")
            return result
            
        except Exception as e:
            logger.error(f"Error executing custom query: {str(e)}", exc_info=True)
            raise
    
    def get_historical_data(self, system: str, metric: str, granularity: str, days: int = 90) -> List[Dict[str, Any]]:
        """
        Get historical data for forecasting.
        
        Args:
            system: System name
            metric: Metric to retrieve (e.g., 'sales', 'demand')
            granularity: Time granularity ('day', 'week', 'month')
            days: Number of days of history to retrieve
            
        Returns:
            List of historical data points
        """
        try:
            # Map system to appropriate table
            table_map = {
                'market-intelligence': 'orders',
                'demand-insights': 'orders',
                'compliance-guardian': 'fraud_detections',
                'retail-copilot': 'orders',
                'global-market': 'regional_market_data'
            }
            
            table = table_map.get(system, 'orders')
            validated_table = self._validate_table_name(table)
            
            # Build query based on metric and granularity
            date_trunc = {
                'day': 'day',
                'week': 'week',
                'month': 'month'
            }.get(granularity, 'day')
            
            query = f"""
            SELECT 
                date_trunc('{date_trunc}', order_date) as period,
                COUNT(*) as count,
                SUM(total_amount) as total
            FROM {self.database}.{validated_table}
            WHERE order_date >= date_add('day', -{days}, current_date)
            GROUP BY date_trunc('{date_trunc}', order_date)
            ORDER BY period
            """
            
            return self.execute_query(query)
            
        except Exception as e:
            logger.error(f"Error getting historical data: {str(e)}", exc_info=True)
            return []
    
    def get_insights(self, system: str, insight_type: str, period: str) -> Dict[str, Any]:
        """
        Get insights for a system.
        
        Args:
            system: System name
            insight_type: Type of insight ('summary', 'trends', 'anomalies')
            period: Time period ('day', 'week', 'month', 'year')
            
        Returns:
            Dictionary of insights
        """
        try:
            # Calculate date range
            days_map = {'day': 1, 'week': 7, 'month': 30, 'year': 365}
            days = days_map.get(period, 7)
            
            # Get summary statistics
            if insight_type == 'summary':
                query = f"""
                SELECT 
                    COUNT(DISTINCT customer_id) as unique_customers,
                    COUNT(*) as total_orders,
                    SUM(total_amount) as total_revenue,
                    AVG(total_amount) as avg_order_value
                FROM {self.database}.orders
                WHERE order_date >= date_add('day', -{days}, current_date)
                """
                
                result = self.execute_query(query)
                return result[0] if result else {}
            
            # Get trends
            elif insight_type == 'trends':
                query = f"""
                SELECT 
                    date_trunc('day', order_date) as date,
                    COUNT(*) as orders,
                    SUM(total_amount) as revenue
                FROM {self.database}.orders
                WHERE order_date >= date_add('day', -{days}, current_date)
                GROUP BY date_trunc('day', order_date)
                ORDER BY date
                """
                
                return {'trend_data': self.execute_query(query)}
            
            # Placeholder for anomalies
            else:
                return {'anomalies': []}
                
        except Exception as e:
            logger.error(f"Error getting insights: {str(e)}", exc_info=True)
            return {}
    
    def get_current_timestamp(self) -> str:
        """Get current timestamp in ISO format."""
        return datetime.utcnow().isoformat() + 'Z'
