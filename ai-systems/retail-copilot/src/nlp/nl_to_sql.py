"""
Natural Language to SQL Converter

Converts natural language questions to SQL queries using LLM and few-shot learning.
"""

import logging
from typing import Dict, Optional, List
from llm.llm_client import LLMClient

logger = logging.getLogger(__name__)


class NLToSQLConverter:
    """
    Converts natural language questions to SQL queries.
    
    Uses few-shot learning with example queries to guide the LLM.
    """
    
    def __init__(self, llm_client: LLMClient):
        """
        Initialize NL to SQL converter.
        
        Args:
            llm_client: LLM client for query generation
        """
        self.llm_client = llm_client
        self.schema_info = self._get_schema_info()
        self.few_shot_examples = self._get_few_shot_examples()
    
    def convert(self, question: str, context: Optional[Dict] = None) -> Dict:
        """
        Convert natural language question to SQL query.
        
        Args:
            question: Natural language question
            context: Additional context (user info, filters, etc.)
            
        Returns:
            Dictionary with 'sql', 'explanation', and 'confidence'
        """
        try:
            # Build prompt with schema and examples
            prompt = self._build_prompt(question, context)
            
            # Generate SQL using LLM
            response = self.llm_client.generate_response(
                prompt=prompt,
                system_prompt=self._get_system_prompt()
            )
            
            # Extract SQL from response
            sql = self.llm_client.extract_sql_from_response(response)
            
            if not sql:
                return {
                    'sql': None,
                    'explanation': "I couldn't generate a SQL query for that question. Could you rephrase it?",
                    'confidence': 0.0
                }
            
            # Validate SQL safety
            if not self.llm_client.validate_sql_safety(sql):
                return {
                    'sql': None,
                    'explanation': "The generated query contains unsafe operations. Please try a different question.",
                    'confidence': 0.0
                }
            
            # Extract explanation
            explanation = self._extract_explanation(response)
            
            return {
                'sql': sql,
                'explanation': explanation,
                'confidence': 0.85  # Could be improved with confidence scoring
            }
        
        except Exception as e:
            logger.error(f"Error converting NL to SQL: {str(e)}")
            return {
                'sql': None,
                'explanation': f"Error generating query: {str(e)}",
                'confidence': 0.0
            }
    
    def _get_system_prompt(self) -> str:
        """Get system prompt for SQL generation."""
        return """You are an expert SQL query generator for an eCommerce analytics platform.

Your role is to:
1. Convert natural language questions to SQL queries
2. Use the provided database schema
3. Generate safe, read-only SELECT queries
4. Provide clear explanations of what the query does
5. Follow best practices for query optimization

IMPORTANT RULES:
- Only generate SELECT queries (no INSERT, UPDATE, DELETE, DROP, etc.)
- Use proper JOINs when querying multiple tables
- Include appropriate WHERE clauses for filtering
- Use LIMIT to prevent large result sets
- Format SQL clearly with proper indentation
- Explain the query in simple terms

Always respond with:
1. The SQL query in a ```sql code block
2. A clear explanation of what the query does
3. Any assumptions or limitations"""
    
    def _build_prompt(self, question: str, context: Optional[Dict]) -> str:
        """Build prompt for LLM."""
        prompt_parts = [
            "# Database Schema",
            self.schema_info,
            "",
            "# Example Queries",
            self.few_shot_examples,
            "",
            "# User Question",
            f"Question: {question}",
            ""
        ]
        
        if context:
            prompt_parts.extend([
                "# Additional Context",
                json.dumps(context, indent=2),
                ""
            ])
        
        prompt_parts.append("Generate a SQL query to answer this question:")
        
        return "\n".join(prompt_parts)
    
    def _extract_explanation(self, response: str) -> str:
        """Extract explanation from LLM response."""
        # Remove SQL code block
        if '```sql' in response.lower():
            parts = response.split('```')
            # Get text after SQL block
            for i, part in enumerate(parts):
                if 'sql' in part.lower():
                    if i + 2 < len(parts):
                        return parts[i + 2].strip()
        
        # Return full response if no code block
        return response.strip()
    
    def _get_schema_info(self) -> str:
        """Get database schema information."""
        return """
## Main eCommerce Tables

### customers
- customer_id (STRING, PRIMARY KEY)
- email (STRING)
- first_name (STRING)
- last_name (STRING)
- phone (STRING)
- created_at (TIMESTAMP)
- country (STRING)
- city (STRING)
- total_orders (INT)
- total_spent (DECIMAL)

### products
- product_id (STRING, PRIMARY KEY)
- name (STRING)
- category_id (STRING, FOREIGN KEY)
- price (DECIMAL)
- cost (DECIMAL)
- stock_quantity (INT)
- created_at (TIMESTAMP)
- is_active (BOOLEAN)

### categories
- category_id (STRING, PRIMARY KEY)
- name (STRING)
- parent_category_id (STRING)

### orders
- order_id (STRING, PRIMARY KEY)
- customer_id (STRING, FOREIGN KEY)
- order_date (TIMESTAMP)
- status (STRING) -- 'pending', 'processing', 'shipped', 'delivered', 'cancelled'
- total_amount (DECIMAL)
- shipping_address (STRING)
- payment_method (STRING)

### order_items
- order_item_id (STRING, PRIMARY KEY)
- order_id (STRING, FOREIGN KEY)
- product_id (STRING, FOREIGN KEY)
- quantity (INT)
- unit_price (DECIMAL)
- discount (DECIMAL)
- subtotal (DECIMAL)

### inventory
- inventory_id (STRING, PRIMARY KEY)
- product_id (STRING, FOREIGN KEY)
- warehouse_location (STRING)
- quantity_available (INT)
- quantity_reserved (INT)
- last_updated (TIMESTAMP)

### payments
- payment_id (STRING, PRIMARY KEY)
- order_id (STRING, FOREIGN KEY)
- amount (DECIMAL)
- payment_method (STRING)
- payment_status (STRING)
- transaction_date (TIMESTAMP)

### reviews
- review_id (STRING, PRIMARY KEY)
- product_id (STRING, FOREIGN KEY)
- customer_id (STRING, FOREIGN KEY)
- rating (INT) -- 1-5
- review_text (STRING)
- created_at (TIMESTAMP)
"""
    
    def _get_few_shot_examples(self) -> str:
        """Get few-shot learning examples."""
        return """
## Example 1: Inventory Query
Question: "Show me products with low stock"
SQL:
```sql
SELECT p.product_id, p.name, p.category_id, i.quantity_available
FROM products p
JOIN inventory i ON p.product_id = i.product_id
WHERE i.quantity_available < 10
ORDER BY i.quantity_available ASC
LIMIT 50;
```
Explanation: This query finds products with less than 10 units in stock, ordered by quantity.

## Example 2: Order Status Query
Question: "How many orders are pending?"
SQL:
```sql
SELECT COUNT(*) as pending_orders
FROM orders
WHERE status = 'pending';
```
Explanation: This counts all orders with 'pending' status.

## Example 3: Customer Analysis
Question: "Who are my top 10 customers by total spending?"
SQL:
```sql
SELECT customer_id, first_name, last_name, email, total_spent
FROM customers
ORDER BY total_spent DESC
LIMIT 10;
```
Explanation: This retrieves the top 10 customers ranked by their total spending.

## Example 4: Product Performance
Question: "What are the best-selling products this month?"
SQL:
```sql
SELECT p.product_id, p.name, SUM(oi.quantity) as units_sold, SUM(oi.subtotal) as revenue
FROM products p
JOIN order_items oi ON p.product_id = oi.product_id
JOIN orders o ON oi.order_id = o.order_id
WHERE o.order_date >= DATE_TRUNC('month', CURRENT_DATE)
GROUP BY p.product_id, p.name
ORDER BY units_sold DESC
LIMIT 20;
```
Explanation: This shows products with the most units sold this month, with revenue totals.

## Example 5: Customer Orders
Question: "Show me recent orders for customer CUST-12345"
SQL:
```sql
SELECT o.order_id, o.order_date, o.status, o.total_amount
FROM orders o
WHERE o.customer_id = 'CUST-12345'
ORDER BY o.order_date DESC
LIMIT 10;
```
Explanation: This retrieves the 10 most recent orders for a specific customer.
"""


import json

