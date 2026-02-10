"""
Athena Client for Compliance Guardian

Retrieves transaction and compliance data from AWS Athena.
"""

import boto3
import pandas as pd
import time
from typing import Dict, List, Optional
import logging

logger = logging.getLogger(__name__)


class AthenaClient:
    """
    Client for querying AWS Athena to retrieve transaction and compliance data.
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
        self.database = database or os.getenv('ATHENA_DATABASE', 'compliance_db')
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
    
    def get_transaction_data(
        self,
        start_date: Optional[str] = None,
        end_date: Optional[str] = None,
        limit: Optional[int] = None
    ) -> pd.DataFrame:
        """
        Retrieve transaction data for fraud detection and risk scoring.
        
        Args:
            start_date: Start date (YYYY-MM-DD)
            end_date: End date (YYYY-MM-DD)
            limit: Optional limit on number of transactions
            
        Returns:
            DataFrame with transaction data
        """
        query = """
        SELECT 
            t.transaction_id,
            t.customer_id,
            t.amount,
            t.transaction_time,
            t.merchant_id,
            t.payment_method,
            t.is_online,
            t.is_international,
            t.status,
            c.created_at as customer_created_at,
            DATEDIFF(day, c.created_at, t.transaction_time) as customer_age_days,
            COUNT(DISTINCT t2.transaction_id) as previous_transactions,
            AVG(t2.amount) as avg_transaction_amount,
            SUM(CASE WHEN t2.transaction_time >= t.transaction_time - INTERVAL '1' HOUR 
                THEN 1 ELSE 0 END) as transactions_last_hour,
            SUM(CASE WHEN t2.transaction_time >= t.transaction_time - INTERVAL '1' DAY 
                THEN 1 ELSE 0 END) as transactions_last_day,
            SUM(CASE WHEN t2.status = 'failed' AND 
                t2.transaction_time >= t.transaction_time - INTERVAL '1' DAY 
                THEN 1 ELSE 0 END) as failed_attempts_last_day
        FROM transactions t
        LEFT JOIN customers c ON t.customer_id = c.customer_id
        LEFT JOIN transactions t2 ON t.customer_id = t2.customer_id 
            AND t2.transaction_time < t.transaction_time
        WHERE t.status IN ('completed', 'pending')
        """
        
        if start_date:
            query += f" AND t.transaction_time >= DATE '{start_date}'"
        if end_date:
            query += f" AND t.transaction_time <= DATE '{end_date}'"
        
        query += """
        GROUP BY t.transaction_id, t.customer_id, t.amount, t.transaction_time,
                 t.merchant_id, t.payment_method, t.is_online, t.is_international,
                 t.status, c.created_at
        ORDER BY t.transaction_time DESC
        """
        
        if limit:
            query += f" LIMIT {limit}"
        
        return self.execute_query(query)
    
    def get_payment_data(
        self,
        transaction_ids: Optional[List[str]] = None
    ) -> pd.DataFrame:
        """
        Retrieve payment data for PCI DSS compliance checking.
        
        Args:
            transaction_ids: Optional list of transaction IDs
            
        Returns:
            DataFrame with payment data (with masked sensitive fields)
        """
        query = """
        SELECT 
            p.payment_id,
            p.transaction_id,
            p.payment_method,
            p.card_type,
            CONCAT(SUBSTRING(p.card_number, 1, 6), '******', 
                   SUBSTRING(p.card_number, -4)) as card_number,
            p.cardholder_name,
            p.billing_address,
            p.payment_status,
            p.created_at
        FROM payments p
        WHERE p.payment_status IN ('completed', 'pending')
        """
        
        if transaction_ids:
            ids_str = "', '".join(transaction_ids)
            query += f" AND p.transaction_id IN ('{ids_str}')"
        
        query += " ORDER BY p.created_at DESC LIMIT 1000"
        
        return self.execute_query(query)
    
    def get_high_risk_transactions(
        self,
        days: int = 7,
        min_amount: float = 1000.0
    ) -> pd.DataFrame:
        """
        Retrieve potentially high-risk transactions.
        
        Args:
            days: Number of days to look back
            min_amount: Minimum transaction amount
            
        Returns:
            DataFrame with high-risk transactions
        """
        query = f"""
        SELECT 
            t.transaction_id,
            t.customer_id,
            t.amount,
            t.transaction_time,
            t.is_international,
            t.is_online,
            c.created_at as customer_created_at,
            DATEDIFF(day, c.created_at, t.transaction_time) as customer_age_days,
            COUNT(DISTINCT t2.transaction_id) as previous_transactions
        FROM transactions t
        LEFT JOIN customers c ON t.customer_id = c.customer_id
        LEFT JOIN transactions t2 ON t.customer_id = t2.customer_id 
            AND t2.transaction_time < t.transaction_time
        WHERE t.transaction_time >= CURRENT_DATE - INTERVAL '{days}' DAY
        AND t.amount >= {min_amount}
        AND t.status IN ('completed', 'pending')
        GROUP BY t.transaction_id, t.customer_id, t.amount, t.transaction_time,
                 t.is_international, t.is_online, c.created_at
        ORDER BY t.amount DESC
        LIMIT 1000
        """
        
        return self.execute_query(query)
    
    def get_access_logs(
        self,
        days: int = 30
    ) -> pd.DataFrame:
        """
        Retrieve access logs for compliance monitoring.
        
        Args:
            days: Number of days to look back
            
        Returns:
            DataFrame with access logs
        """
        query = f"""
        SELECT 
            log_id,
            user_id,
            access_time,
            resource_accessed,
            action,
            ip_address,
            CASE WHEN status = 'denied' THEN 1 ELSE 0 END as access_denied,
            status
        FROM access_logs
        WHERE access_time >= CURRENT_DATE - INTERVAL '{days}' DAY
        ORDER BY access_time DESC
        LIMIT 10000
        """
        
        return self.execute_query(query)
    
    def get_fraud_statistics(self, days: int = 30) -> pd.DataFrame:
        """
        Retrieve fraud statistics for analysis.
        
        Args:
            days: Number of days to look back
            
        Returns:
            DataFrame with fraud statistics
        """
        query = f"""
        SELECT 
            DATE(transaction_time) as date,
            COUNT(*) as total_transactions,
            SUM(amount) as total_amount,
            COUNT(CASE WHEN is_flagged_fraud = 1 THEN 1 END) as flagged_transactions,
            SUM(CASE WHEN is_flagged_fraud = 1 THEN amount ELSE 0 END) as flagged_amount,
            AVG(risk_score) as avg_risk_score
        FROM transactions
        WHERE transaction_time >= CURRENT_DATE - INTERVAL '{days}' DAY
        GROUP BY DATE(transaction_time)
        ORDER BY date DESC
        """
        
        return self.execute_query(query)
