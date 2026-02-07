"""
AWS Lambda Handler for Retail Copilot

Provides REST API endpoints for AI-powered retail assistance.
"""

import json
import logging
import os
from typing import Dict, Any

from llm.llm_client import LLMClient
from copilot.copilot_engine import RetailCopilotEngine
from conversation.conversation_manager import ConversationManager
from data.athena_client import AthenaClient

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Initialize components
athena_client = AthenaClient(
    database=os.environ.get('ATHENA_DATABASE', 'retail_copilot_db'),
    output_location=os.environ.get('ATHENA_OUTPUT_LOCATION'),
    region=os.environ.get('AWS_REGION', 'us-east-1'),
    workgroup=os.environ.get('ATHENA_WORKGROUP', 'primary')
)

llm_client = LLMClient(
    provider=os.environ.get('LLM_PROVIDER', 'bedrock'),
    model_id=os.environ.get('LLM_MODEL_ID', 'anthropic.claude-v2'),
    region=os.environ.get('AWS_REGION', 'us-east-1'),
    temperature=float(os.environ.get('LLM_TEMPERATURE', '0.7')),
    max_tokens=int(os.environ.get('LLM_MAX_TOKENS', '2000'))
)

conversation_manager = ConversationManager(
    table_name=os.environ.get('CONVERSATION_TABLE', 'retail-copilot-conversations'),
    region=os.environ.get('AWS_REGION', 'us-east-1')
)

# Global copilot engine instance
copilot_engine = RetailCopilotEngine(
    llm_client=llm_client,
    athena_client=athena_client,
    conversation_manager=conversation_manager
)


def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """
    Main Lambda handler for Retail Copilot.
    
    Routes requests to appropriate handlers based on path and method.
    """
    try:
        # Parse request
        path = event.get('path', '')
        method = event.get('httpMethod', 'GET')
        body = json.loads(event.get('body', '{}')) if event.get('body') else {}
        query_params = event.get('queryStringParameters', {}) or {}
        
        # Extract user info from authorizer context
        authorizer_context = event.get('requestContext', {}).get('authorizer', {})
        user_id = authorizer_context.get('userId', 'anonymous')
        
        logger.info(f"Request: {method} {path} from user {user_id}")
        
        # Route to appropriate handler
        if path == '/copilot/chat' and method == 'POST':
            return handle_chat(body, user_id)
        
        elif path == '/copilot/conversations' and method == 'GET':
            return handle_get_conversations(query_params, user_id)
        
        elif path == '/copilot/conversation' and method == 'POST':
            return handle_create_conversation(body, user_id)
        
        elif path == '/copilot/conversation' and method == 'GET':
            return handle_get_conversation(query_params, user_id)
        
        elif path == '/copilot/conversation' and method == 'DELETE':
            return handle_delete_conversation(query_params, user_id)
        
        elif path == '/copilot/inventory' and method == 'GET':
            return handle_inventory_query(query_params)
        
        elif path == '/copilot/orders' and method == 'GET':
            return handle_orders_query(query_params)
        
        elif path == '/copilot/customers' and method == 'GET':
            return handle_customers_query(query_params)
        
        elif path == '/copilot/recommendations' and method == 'POST':
            return handle_recommendations(body)
        
        elif path == '/copilot/sales-report' and method == 'GET':
            return handle_sales_report(query_params)
        
        else:
            return create_response(404, {'error': 'Endpoint not found'})
    
    except Exception as e:
        logger.error(f"Error processing request: {str(e)}", exc_info=True)
        return create_response(500, {'error': str(e)})


def handle_chat(body: Dict, user_id: str) -> Dict:
    """
    Handle chat request.
    
    POST /copilot/chat
    Body: {
        "conversation_id": "conv-123",
        "query": "Show me low stock products",
        "context": {}
    }
    """
    try:
        conversation_id = body.get('conversation_id')
        query = body.get('query')
        context = body.get('context', {})
        
        if not query:
            return create_response(400, {'error': 'Query is required'})
        
        # Create conversation if not provided
        if not conversation_id:
            conversation_id = conversation_manager.create_conversation(
                user_id=user_id,
                metadata={'source': 'chat'}
            )
        
        # Process query
        response = copilot_engine.process_query(
            user_id=user_id,
            conversation_id=conversation_id,
            query=query,
            context=context
        )
        
        # Add conversation_id to response
        response['conversation_id'] = conversation_id
        
        return create_response(200, response)
    
    except Exception as e:
        logger.error(f"Error in chat handler: {str(e)}")
        return create_response(500, {'error': str(e)})


def handle_get_conversations(params: Dict, user_id: str) -> Dict:
    """
    Handle get conversations request.
    
    GET /copilot/conversations?limit=10
    """
    try:
        limit = int(params.get('limit', 10))
        
        conversations = conversation_manager.get_user_conversations(
            user_id=user_id,
            limit=limit
        )
        
        return create_response(200, {
            'conversations': conversations,
            'count': len(conversations)
        })
    
    except Exception as e:
        logger.error(f"Error getting conversations: {str(e)}")
        return create_response(500, {'error': str(e)})


def handle_create_conversation(body: Dict, user_id: str) -> Dict:
    """
    Handle create conversation request.
    
    POST /copilot/conversation
    Body: {
        "metadata": {}
    }
    """
    try:
        metadata = body.get('metadata', {})
        
        conversation_id = conversation_manager.create_conversation(
            user_id=user_id,
            metadata=metadata
        )
        
        return create_response(200, {
            'conversation_id': conversation_id,
            'user_id': user_id
        })
    
    except Exception as e:
        logger.error(f"Error creating conversation: {str(e)}")
        return create_response(500, {'error': str(e)})


def handle_get_conversation(params: Dict, user_id: str) -> Dict:
    """
    Handle get conversation request.
    
    GET /copilot/conversation?conversation_id=conv-123
    """
    try:
        conversation_id = params.get('conversation_id')
        
        if not conversation_id:
            return create_response(400, {'error': 'conversation_id is required'})
        
        conversation = conversation_manager.get_conversation(conversation_id)
        
        if not conversation:
            return create_response(404, {'error': 'Conversation not found'})
        
        # Verify user owns conversation
        if conversation.get('user_id') != user_id:
            return create_response(403, {'error': 'Access denied'})
        
        return create_response(200, conversation)
    
    except Exception as e:
        logger.error(f"Error getting conversation: {str(e)}")
        return create_response(500, {'error': str(e)})


def handle_delete_conversation(params: Dict, user_id: str) -> Dict:
    """
    Handle delete conversation request.
    
    DELETE /copilot/conversation?conversation_id=conv-123
    """
    try:
        conversation_id = params.get('conversation_id')
        
        if not conversation_id:
            return create_response(400, {'error': 'conversation_id is required'})
        
        # Verify user owns conversation
        conversation = conversation_manager.get_conversation(conversation_id)
        if conversation and conversation.get('user_id') != user_id:
            return create_response(403, {'error': 'Access denied'})
        
        success = conversation_manager.delete_conversation(conversation_id)
        
        if success:
            return create_response(200, {'message': 'Conversation deleted'})
        else:
            return create_response(500, {'error': 'Failed to delete conversation'})
    
    except Exception as e:
        logger.error(f"Error deleting conversation: {str(e)}")
        return create_response(500, {'error': str(e)})


def handle_inventory_query(params: Dict) -> Dict:
    """
    Handle inventory query request.
    
    GET /copilot/inventory?limit=100
    """
    try:
        limit = int(params.get('limit', 100))
        
        data = athena_client.get_inventory_data(limit=limit)
        
        return create_response(200, {
            'inventory': data.to_dict('records'),
            'count': len(data)
        })
    
    except Exception as e:
        logger.error(f"Error querying inventory: {str(e)}")
        return create_response(500, {'error': str(e)})


def handle_orders_query(params: Dict) -> Dict:
    """
    Handle orders query request.
    
    GET /copilot/orders?limit=100&status=pending
    """
    try:
        limit = int(params.get('limit', 100))
        status = params.get('status')
        
        data = athena_client.get_order_data(limit=limit, status=status)
        
        return create_response(200, {
            'orders': data.to_dict('records'),
            'count': len(data)
        })
    
    except Exception as e:
        logger.error(f"Error querying orders: {str(e)}")
        return create_response(500, {'error': str(e)})


def handle_customers_query(params: Dict) -> Dict:
    """
    Handle customers query request.
    
    GET /copilot/customers?limit=100
    """
    try:
        limit = int(params.get('limit', 100))
        
        data = athena_client.get_customer_data(limit=limit)
        
        return create_response(200, {
            'customers': data.to_dict('records'),
            'count': len(data)
        })
    
    except Exception as e:
        logger.error(f"Error querying customers: {str(e)}")
        return create_response(500, {'error': str(e)})


def handle_recommendations(body: Dict) -> Dict:
    """
    Handle product recommendations request.
    
    POST /copilot/recommendations
    Body: {
        "customer_id": "CUST-123",
        "limit": 10
    }
    """
    try:
        customer_id = body.get('customer_id')
        limit = body.get('limit', 10)
        
        if not customer_id:
            return create_response(400, {'error': 'customer_id is required'})
        
        data = athena_client.get_product_recommendations(
            customer_id=customer_id,
            limit=limit
        )
        
        return create_response(200, {
            'recommendations': data.to_dict('records'),
            'count': len(data),
            'customer_id': customer_id
        })
    
    except Exception as e:
        logger.error(f"Error generating recommendations: {str(e)}")
        return create_response(500, {'error': str(e)})


def handle_sales_report(params: Dict) -> Dict:
    """
    Handle sales report request.
    
    GET /copilot/sales-report?days=30
    """
    try:
        days = int(params.get('days', 30))
        
        data = athena_client.get_sales_report(days=days)
        
        return create_response(200, {
            'report': data.to_dict('records'),
            'period_days': days,
            'count': len(data)
        })
    
    except Exception as e:
        logger.error(f"Error generating sales report: {str(e)}")
        return create_response(500, {'error': str(e)})


def create_response(status_code: int, body: Dict) -> Dict:
    """Create API Gateway response."""
    return {
        'statusCode': status_code,
        'headers': {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Headers': 'Content-Type,Authorization',
            'Access-Control-Allow-Methods': 'GET,POST,DELETE,OPTIONS'
        },
        'body': json.dumps(body, default=str)
    }
