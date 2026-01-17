# Retail Copilot

AI-powered assistant for retail teams, marketing teams, and small businesses. Provides Microsoft Copilot-like behavior with natural language understanding, SQL generation, and comprehensive guidance.

## Overview

The Retail Copilot is an intelligent assistant that helps retail professionals, marketers, and small business owners with daily tasks through natural language interaction. It provides answers, practical examples, step-by-step guidance, and references to help users work more efficiently.

## Features

### 1. Natural Language Chat Interface
- **Conversational AI**: Interact using natural language questions
- **Context Awareness**: Maintains conversation history and context
- **Multi-turn Conversations**: Supports follow-up questions and clarifications
- **Personalized Responses**: Tailored to retail, marketing, and small business contexts

### 2. Natural Language to SQL
- **Query Generation**: Converts questions to SQL queries automatically
- **Few-Shot Learning**: Uses examples to improve query accuracy
- **Safety Validation**: Prevents dangerous SQL operations
- **Schema Awareness**: Understands database structure and relationships

### 3. Microsoft Copilot-Like Behavior
- **Clear Answers**: Direct, actionable responses to questions
- **Practical Examples**: Real-world examples relevant to retail and eCommerce
- **Step-by-Step Guidance**: Detailed instructions for complex tasks
- **References**: Links to relevant resources and documentation

### 4. Data Access and Analytics
- **Inventory Queries**: Check stock levels, product availability
- **Order Management**: Track orders, analyze order patterns
- **Customer Insights**: Understand customer behavior and preferences
- **Sales Reports**: Generate sales analytics and trends
- **Product Recommendations**: AI-powered product suggestions

### 5. LLM Integration
- **AWS Bedrock**: Claude, Titan models
- **Flexible Provider**: Support for multiple LLM providers
- **Prompt Engineering**: Optimized prompts for retail contexts
- **Response Quality**: High-quality, contextual responses

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    API Gateway                               │
│  /copilot/chat                                               │
│  /copilot/conversations                                      │
│  /copilot/conversation                                       │
│  /copilot/inventory                                          │
│  /copilot/orders                                             │
│  /copilot/customers                                          │
│  /copilot/recommendations                                    │
│  /copilot/sales-report                                       │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│              Lambda Handler (handler.py)                     │
│  - Routes requests to copilot engine                         │
│  - Manages authentication and authorization                  │
│  - Handles error responses                                   │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│         Retail Copilot Engine (copilot_engine.py)           │
│  - Query classification                                      │
│  - Response generation                                       │
│  - Context management                                        │
│  - Microsoft Copilot-like behavior                           │
└────────────────────┬────────────────────────────────────────┘
                     │
        ┌────────────┼────────────┬────────────┐
        │            │            │            │
        ▼            ▼            ▼            ▼
┌──────────────┐ ┌──────────────┐ ┌──────────────┐ ┌──────────────┐
│  LLM Client  │ │  NL to SQL   │ │ Conversation │ │   Athena     │
│              │ │  Converter   │ │   Manager    │ │   Client     │
└──────┬───────┘ └──────┬───────┘ └──────┬───────┘ └──────┬───────┘
       │                │                │                │
       ▼                ▼                ▼                ▼
┌──────────────┐ ┌──────────────┐ ┌──────────────┐ ┌──────────────┐
│ AWS Bedrock  │ │ Few-Shot     │ │  DynamoDB    │ │ AWS Athena   │
│ (Claude/     │ │ Examples     │ │ (History)    │ │ (S3 Queries) │
│  Titan)      │ │              │ │              │ │              │
└──────────────┘ └──────────────┘ └──────────────┘ └──────────────┘
```

## API Endpoints

### Chat
```http
POST /copilot/chat
Authorization: Bearer <jwt_token>
Content-Type: application/json

{
  "conversation_id": "conv-123",
  "query": "Show me products with low stock",
  "context": {}
}
```

**Response:**
```json
{
  "conversation_id": "conv-123",
  "answer": "I found 15 products with low stock. Here's what I found:\n\n- Product: Widget A, Stock: 5 units\n- Product: Gadget B, Stock: 3 units\n...",
  "data": [
    {
      "product_id": "PROD-001",
      "name": "Widget A",
      "quantity_available": 5
    }
  ],
  "sql": "SELECT p.product_id, p.name, i.quantity_available FROM products p JOIN inventory i ON p.product_id = i.product_id WHERE i.quantity_available < 10 ORDER BY i.quantity_available ASC LIMIT 50;",
  "explanation": "This query finds products with less than 10 units in stock.",
  "query_type": "data_query",
  "examples": [
    {
      "title": "View Full Results",
      "description": "The complete dataset is available in the data section below."
    }
  ],
  "references": [
    {
      "title": "Data Query Guide",
      "url": "/docs/data-queries",
      "description": "Learn how to query and analyze your data"
    }
  ]
}
```

### Get Conversations
```http
GET /copilot/conversations?limit=10
Authorization: Bearer <jwt_token>
```

**Response:**
```json
{
  "conversations": [
    {
      "conversation_id": "conv-123",
      "user_id": "user-456",
      "created_at": "2026-01-16T10:00:00Z",
      "updated_at": "2026-01-16T10:30:00Z",
      "messages": []
    }
  ],
  "count": 1
}
```

### Create Conversation
```http
POST /copilot/conversation
Authorization: Bearer <jwt_token>
Content-Type: application/json

{
  "metadata": {
    "source": "dashboard"
  }
}
```

**Response:**
```json
{
  "conversation_id": "conv-789",
  "user_id": "user-456"
}
```

### Get Conversation
```http
GET /copilot/conversation?conversation_id=conv-123
Authorization: Bearer <jwt_token>
```

**Response:**
```json
{
  "conversation_id": "conv-123",
  "user_id": "user-456",
  "created_at": "2026-01-16T10:00:00Z",
  "updated_at": "2026-01-16T10:30:00Z",
  "messages": [
    {
      "role": "user",
      "content": "Show me low stock products",
      "timestamp": "2026-01-16T10:00:00Z"
    },
    {
      "role": "assistant",
      "content": "I found 15 products with low stock...",
      "timestamp": "2026-01-16T10:00:05Z"
    }
  ]
}
```

### Delete Conversation
```http
DELETE /copilot/conversation?conversation_id=conv-123
Authorization: Bearer <jwt_token>
```

**Response:**
```json
{
  "message": "Conversation deleted"
}
```

### Inventory Query
```http
GET /copilot/inventory?limit=100
Authorization: Bearer <jwt_token>
```

**Response:**
```json
{
  "inventory": [
    {
      "product_id": "PROD-001",
      "name": "Widget A",
      "category_id": "CAT-001",
      "price": 29.99,
      "quantity_available": 50,
      "quantity_reserved": 10,
      "warehouse_location": "WH-01",
      "last_updated": "2026-01-16T09:00:00Z"
    }
  ],
  "count": 100
}
```

### Orders Query
```http
GET /copilot/orders?limit=100&status=pending
Authorization: Bearer <jwt_token>
```

**Response:**
```json
{
  "orders": [
    {
      "order_id": "ORD-001",
      "customer_id": "CUST-001",
      "order_date": "2026-01-16T08:00:00Z",
      "status": "pending",
      "total_amount": 149.99,
      "payment_method": "credit_card",
      "first_name": "John",
      "last_name": "Doe",
      "email": "john@example.com"
    }
  ],
  "count": 25
}
```

### Customers Query
```http
GET /copilot/customers?limit=100
Authorization: Bearer <jwt_token>
```

**Response:**
```json
{
  "customers": [
    {
      "customer_id": "CUST-001",
      "email": "john@example.com",
      "first_name": "John",
      "last_name": "Doe",
      "phone": "+1234567890",
      "country": "USA",
      "city": "New York",
      "total_orders": 15,
      "total_spent": 2499.85,
      "created_at": "2025-01-01T00:00:00Z"
    }
  ],
  "count": 100
}
```

### Product Recommendations
```http
POST /copilot/recommendations
Authorization: Bearer <jwt_token>
Content-Type: application/json

{
  "customer_id": "CUST-001",
  "limit": 10
}
```

**Response:**
```json
{
  "recommendations": [
    {
      "product_id": "PROD-123",
      "name": "Premium Widget",
      "category_id": "CAT-001",
      "price": 49.99,
      "purchase_count": 150,
      "avg_rating": 4.5
    }
  ],
  "count": 10,
  "customer_id": "CUST-001"
}
```

### Sales Report
```http
GET /copilot/sales-report?days=30
Authorization: Bearer <jwt_token>
```

**Response:**
```json
{
  "report": [
    {
      "date": "2026-01-16",
      "total_orders": 125,
      "unique_customers": 98,
      "total_revenue": 15234.50,
      "avg_order_value": 121.88
    }
  ],
  "period_days": 30,
  "count": 30
}
```

## Query Types

### Data Queries
Questions that require database access:
- "Show me products with low stock"
- "How many orders are pending?"
- "Who are my top customers?"
- "What are the best-selling products this month?"

### How-To Queries
Questions requesting step-by-step guidance:
- "How do I process a return?"
- "How can I set up a promotion?"
- "Steps to onboard a new product"

### Recommendation Queries
Questions seeking advice:
- "What's the best way to reduce cart abandonment?"
- "Should I offer free shipping?"
- "Recommend a pricing strategy for new products"

### Explanation Queries
Questions requesting explanations:
- "What is customer lifetime value?"
- "Explain the difference between gross and net profit"
- "What does 'conversion rate' mean?"

## Dependencies

```
boto3>=1.34.0
pandas>=2.0.0
numpy>=1.24.0
```

## Deployment

### Build Deployment Package

```powershell
# Windows
.\build.ps1
```

```bash
# Linux/Mac
chmod +x build.sh
./build.sh
```

### Deploy with Terraform

```bash
cd ../../terraform
terraform init
terraform plan
terraform apply
```

### Manual Deployment

```bash
aws lambda update-function-code \
  --function-name retail-copilot \
  --zip-file fileb://deployment.zip
```

## Configuration

### Environment Variables

- `ATHENA_DATABASE`: Athena database name (default: `retail_copilot_db`)
- `ATHENA_OUTPUT_LOCATION`: S3 location for query results
- `AWS_REGION`: AWS region (default: `us-east-1`)
- `LLM_PROVIDER`: LLM provider ('bedrock', 'openai') (default: `bedrock`)
- `LLM_MODEL_ID`: Model identifier (default: `anthropic.claude-v2`)
- `LLM_TEMPERATURE`: Sampling temperature (default: `0.7`)
- `LLM_MAX_TOKENS`: Maximum tokens in response (default: `2000`)
- `CONVERSATION_TABLE`: DynamoDB table for conversations (default: `retail-copilot-conversations`)
- `LOG_LEVEL`: Logging level (default: `INFO`)

### Lambda Configuration

- **Runtime**: Python 3.11
- **Memory**: 2048 MB (2 GB)
- **Timeout**: 300 seconds (5 minutes)
- **Handler**: `handler.lambda_handler`

## LLM Providers

### AWS Bedrock (Default)
- **Models**: Claude (anthropic.claude-v2), Titan
- **Setup**: Requires AWS Bedrock access
- **Cost**: Pay per token

### OpenAI
- **Models**: GPT-4, GPT-3.5-turbo
- **Setup**: Requires OpenAI API key in Secrets Manager
- **Cost**: Pay per token

## Best Practices

1. **Conversation Management**: Create new conversations for different topics
2. **Query Clarity**: Ask specific, clear questions for better results
3. **Context**: Provide relevant context in follow-up questions
4. **Data Limits**: Use reasonable limits for data queries
5. **Security**: Never expose sensitive data in queries

## Troubleshooting

### Common Issues

**Issue**: LLM not responding
- **Solution**: Check AWS Bedrock access and model availability

**Issue**: SQL generation fails
- **Solution**: Rephrase question more clearly, check schema availability

**Issue**: Conversation not found
- **Solution**: Verify conversation_id, check DynamoDB table

**Issue**: Athena query timeout
- **Solution**: Optimize query, reduce data volume, check partitioning

**Issue**: Lambda timeout
- **Solution**: Increase timeout, optimize query complexity

## Requirements Validation

This implementation satisfies the following requirements:

- **18.1**: Natural language query interface ✓
- **18.2**: Answers questions about inventory, orders, and customers ✓
- **18.3**: Product recommendations ✓
- **18.4**: Sales reports on demand ✓
- **18.5**: Order status updates ✓
- **18.6**: LLM integration (AWS Bedrock) ✓
- **18.7**: Integration with all other systems ✓
- **18.8**: Learns from user interactions (conversation history) ✓

## Additional Features

- **Microsoft Copilot-like behavior**: Answers, examples, step-by-step guidance, references
- **Retail/Marketing/Small Business focus**: Tailored responses for these audiences
- **Conversation persistence**: DynamoDB storage for history
- **Multi-turn conversations**: Context-aware follow-ups
- **Safety validation**: Prevents dangerous SQL operations
- **Query classification**: Routes to appropriate handlers
- **Comprehensive API**: 8 REST endpoints for various use cases

## License

Copyright © 2026 eCommerce AI Platform. All rights reserved.
