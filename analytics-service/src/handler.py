"""
Analytics Service Lambda Handler

Provides analytics endpoints for querying data via Athena.
Supports all five AI systems with secure query execution.
"""

import json
import os
import logging
from typing import Dict, Any, Optional
from .services.athena_service import AthenaService
from .services.jwt_service import JWTService
from .utils.response import create_response, create_error_response

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize services
athena_service = AthenaService(
    database=os.environ.get('ATHENA_DATABASE', 'ecommerce_db'),
    output_location=os.environ.get('ATHENA_OUTPUT_LOCATION', 's3://ecommerce-platform-athena-results/'),
    workgroup=os.environ.get('ATHENA_WORKGROUP', 'primary')
)
jwt_service = JWTService(secret_name=os.environ.get('JWT_SECRET_NAME', 'ecommerce-platform/jwt-secret'))


def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """
    Main Lambda handler for analytics service.
    
    Routes:
    - GET /analytics/{system}/query - Execute Athena query
    - POST /analytics/{system}/forecast - Generate forecast
    - GET /analytics/{system}/insights - Get insights
    """
    try:
        # Extract request details
        http_method = event.get('httpMethod', '')
        path = event.get('path', '')
        path_parameters = event.get('pathParameters', {})
        query_parameters = event.get('queryStringParameters', {}) or {}
        body = event.get('body', '{}')
        headers = event.get('headers', {})
        
        # Verify JWT token
        auth_header = headers.get('Authorization', '')
        if not auth_header.startswith('Bearer '):
            return create_error_response(401, 'Missing or invalid authorization header')
        
        token = auth_header.replace('Bearer ', '')
        user_claims = jwt_service.verify_token(token)
        if not user_claims:
            return create_error_response(401, 'Invalid or expired token')
        
        user_id = user_claims.get('userId')
        logger.info(f"Request from user: {user_id}, method: {http_method}, path: {path}")
        
        # Parse body if present
        request_body = {}
        if body:
            try:
                request_body = json.loads(body)
            except json.JSONDecodeError:
                return create_error_response(400, 'Invalid JSON in request body')
        
        # Route to appropriate handler
        system = path_parameters.get('system', '')
        
        if http_method == 'GET' and '/query' in path:
            return handle_query(system, query_parameters, user_id)
        elif http_method == 'POST' and '/forecast' in path:
            return handle_forecast(system, request_body, user_id)
        elif http_method == 'GET' and '/insights' in path:
            return handle_insights(system, query_parameters, user_id)
        else:
            return create_error_response(404, 'Endpoint not found')
            
    except Exception as e:
        logger.error(f"Unexpected error: {str(e)}", exc_info=True)
        return create_error_response(500, 'Internal server error')


def handle_query(system: str, params: Dict[str, Any], user_id: str) -> Dict[str, Any]:
    """
    Execute Athena query for specified system.
    
    Query parameters:
    - table: Table name to query
    - limit: Number of rows to return (default: 100, max: 1000)
    - filters: JSON string with filter conditions
    """
    try:
        table = params.get('table')
        if not table:
            return create_error_response(400, 'Missing required parameter: table')
        
        # Validate system name
        valid_systems = ['market-intelligence', 'demand-insights', 'compliance-guardian', 
                        'retail-copilot', 'global-market']
        if system not in valid_systems:
            return create_error_response(400, f'Invalid system: {system}')
        
        # Parse limit
        limit = min(int(params.get('limit', 100)), 1000)
        
        # Parse filters
        filters = {}
        if params.get('filters'):
            try:
                filters = json.loads(params['filters'])
            except json.JSONDecodeError:
                return create_error_response(400, 'Invalid JSON in filters parameter')
        
        # Execute query
        logger.info(f"Executing query for system={system}, table={table}, limit={limit}")
        result = athena_service.query_table(table, limit=limit, filters=filters)
        
        return create_response(200, {
            'system': system,
            'table': table,
            'rowCount': len(result),
            'data': result
        })
        
    except ValueError as e:
        return create_error_response(400, str(e))
    except Exception as e:
        logger.error(f"Error in handle_query: {str(e)}", exc_info=True)
        return create_error_response(500, 'Failed to execute query')


def handle_forecast(system: str, body: Dict[str, Any], user_id: str) -> Dict[str, Any]:
    """
    Generate forecast for specified system.
    
    Request body:
    - metric: Metric to forecast (e.g., 'sales', 'demand')
    - horizon: Forecast horizon in days
    - granularity: Time granularity ('day', 'week', 'month')
    """
    try:
        metric = body.get('metric')
        horizon = body.get('horizon', 30)
        granularity = body.get('granularity', 'day')
        
        if not metric:
            return create_error_response(400, 'Missing required field: metric')
        
        # Validate inputs
        if horizon < 1 or horizon > 365:
            return create_error_response(400, 'Horizon must be between 1 and 365 days')
        
        if granularity not in ['day', 'week', 'month']:
            return create_error_response(400, 'Granularity must be day, week, or month')
        
        logger.info(f"Generating forecast for system={system}, metric={metric}, horizon={horizon}")
        
        # Get historical data
        historical_data = athena_service.get_historical_data(system, metric, granularity)
        
        # For now, return placeholder forecast
        # TODO: Implement actual forecasting models in Tasks 17-21
        forecast = {
            'metric': metric,
            'horizon': horizon,
            'granularity': granularity,
            'forecast': [],
            'confidence_intervals': [],
            'model': 'placeholder',
            'accuracy_metrics': {
                'rmse': 0.0,
                'mae': 0.0,
                'mape': 0.0
            }
        }
        
        return create_response(200, {
            'system': system,
            'forecast': forecast,
            'historical_data_points': len(historical_data)
        })
        
    except Exception as e:
        logger.error(f"Error in handle_forecast: {str(e)}", exc_info=True)
        return create_error_response(500, 'Failed to generate forecast')


def handle_insights(system: str, params: Dict[str, Any], user_id: str) -> Dict[str, Any]:
    """
    Get insights for specified system.
    
    Query parameters:
    - type: Insight type (e.g., 'summary', 'trends', 'anomalies')
    - period: Time period ('day', 'week', 'month', 'year')
    """
    try:
        insight_type = params.get('type', 'summary')
        period = params.get('period', 'week')
        
        if period not in ['day', 'week', 'month', 'year']:
            return create_error_response(400, 'Period must be day, week, month, or year')
        
        logger.info(f"Getting insights for system={system}, type={insight_type}, period={period}")
        
        # Get insights based on system
        insights = athena_service.get_insights(system, insight_type, period)
        
        return create_response(200, {
            'system': system,
            'type': insight_type,
            'period': period,
            'insights': insights,
            'generated_at': athena_service.get_current_timestamp()
        })
        
    except Exception as e:
        logger.error(f"Error in handle_insights: {str(e)}", exc_info=True)
        return create_error_response(500, 'Failed to get insights')
