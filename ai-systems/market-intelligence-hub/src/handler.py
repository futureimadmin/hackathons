"""
Market Intelligence Hub Lambda Handler

Main entry point for Market Intelligence Hub forecasting and analytics.
"""

import json
import logging
import os
from datetime import datetime, timedelta
import pandas as pd
from typing import Dict, Any

from forecasting import ModelSelector, ARIMAForecaster, ProphetForecaster, LSTMForecaster
from data import AthenaClient
from utils.metrics import calculate_all_metrics

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


def create_response(status_code: int, body: Dict[Any, Any]) -> Dict:
    """Create API Gateway response."""
    return {
        'statusCode': status_code,
        'headers': {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Headers': 'Content-Type,Authorization',
            'Access-Control-Allow-Methods': 'GET,POST,OPTIONS'
        },
        'body': json.dumps(body, default=str)
    }


def lambda_handler(event: Dict, context: Any) -> Dict:
    """
    Main Lambda handler for Market Intelligence Hub.
    
    Endpoints:
    - POST /market-intelligence/forecast - Generate sales forecast
    - GET /market-intelligence/trends - Get market trends
    - GET /market-intelligence/competitive-pricing - Get competitive pricing
    - POST /market-intelligence/compare-models - Compare forecasting models
    """
    try:
        logger.info(f"Received event: {json.dumps(event)}")
        
        # Extract path and method
        path = event.get('path', '')
        method = event.get('httpMethod', '')
        
        # Route to appropriate handler
        if '/forecast' in path and method == 'POST':
            return handle_forecast(event)
        elif '/trends' in path and method == 'GET':
            return handle_trends(event)
        elif '/competitive-pricing' in path and method == 'GET':
            return handle_competitive_pricing(event)
        elif '/compare-models' in path and method == 'POST':
            return handle_compare_models(event)
        else:
            return create_response(404, {'error': 'Endpoint not found'})
            
    except Exception as e:
        logger.error(f"Error processing request: {str(e)}", exc_info=True)
        return create_response(500, {'error': str(e)})


def handle_forecast(event: Dict) -> Dict:
    """
    Generate sales forecast.
    
    Request body:
    {
        "metric": "sales",
        "horizon": 30,
        "model": "auto",  // or "arima", "prophet", "lstm"
        "product_id": "optional",
        "category_id": "optional",
        "start_date": "2024-01-01",
        "end_date": "2025-01-15"
    }
    """
    try:
        body = json.loads(event.get('body', '{}'))
        
        # Extract parameters
        metric = body.get('metric', 'sales')
        horizon = body.get('horizon', 30)
        model_type = body.get('model', 'auto')
        product_id = body.get('product_id')
        category_id = body.get('category_id')
        
        # Default date range: last 365 days
        end_date = body.get('end_date', datetime.now().strftime('%Y-%m-%d'))
        start_date = body.get('start_date', (datetime.now() - timedelta(days=365)).strftime('%Y-%m-%d'))
        
        logger.info(f"Generating {horizon}-day forecast using {model_type} model")
        
        # Initialize Athena client
        athena = AthenaClient(
            workgroup=os.environ.get('ATHENA_WORKGROUP', 'primary')
        )
        
        # Fetch historical data
        sales_data = athena.get_sales_data(
            start_date=start_date,
            end_date=end_date,
            product_id=product_id,
            category_id=category_id
        )
        
        if sales_data.empty:
            return create_response(400, {'error': 'No data found for specified criteria'})
        
        # Extract time series
        series = sales_data[metric]
        
        # Generate forecast based on model type
        if model_type == 'auto':
            # Use model selector to find best model
            selector = ModelSelector(test_size=0.2)
            selector.evaluate_models(series)
            forecast_result = selector.forecast_with_best_model(series, horizon)
            
            # Add model comparison
            comparison = selector.get_model_comparison()
            forecast_result['model_comparison'] = comparison.to_dict('records')
            
        elif model_type == 'arima':
            model = ARIMAForecaster()
            model.fit(series)
            forecast_result = model.forecast(horizon)
            
        elif model_type == 'prophet':
            model = ProphetForecaster()
            model.fit(series)
            forecast_result = model.forecast(horizon)
            
        elif model_type == 'lstm':
            model = LSTMForecaster()
            model.fit(series)
            forecast_result = model.forecast(series, horizon)
            
        else:
            return create_response(400, {'error': f'Invalid model type: {model_type}'})
        
        # Add metadata
        forecast_result['metadata'] = {
            'metric': metric,
            'horizon': horizon,
            'data_points': len(series),
            'start_date': start_date,
            'end_date': end_date,
            'product_id': product_id,
            'category_id': category_id,
            'generated_at': datetime.now().isoformat()
        }
        
        return create_response(200, forecast_result)
        
    except Exception as e:
        logger.error(f"Error in handle_forecast: {str(e)}", exc_info=True)
        return create_response(500, {'error': str(e)})


def handle_trends(event: Dict) -> Dict:
    """
    Get market trends.
    
    Query parameters:
    - start_date: Start date (YYYY-MM-DD)
    - end_date: End date (YYYY-MM-DD)
    """
    try:
        params = event.get('queryStringParameters', {}) or {}
        
        # Default date range: last 90 days
        end_date = params.get('end_date', datetime.now().strftime('%Y-%m-%d'))
        start_date = params.get('start_date', (datetime.now() - timedelta(days=90)).strftime('%Y-%m-%d'))
        
        logger.info(f"Fetching market trends from {start_date} to {end_date}")
        
        # Initialize Athena client
        athena = AthenaClient(
            workgroup=os.environ.get('ATHENA_WORKGROUP', 'primary')
        )
        
        # Fetch trends
        trends = athena.get_market_trends(start_date, end_date)
        
        if trends.empty:
            return create_response(200, {
                'trends': [],
                'message': 'No trends found for specified period'
            })
        
        # Convert to dict
        result = {
            'trends': trends.to_dict('records'),
            'count': len(trends),
            'start_date': start_date,
            'end_date': end_date
        }
        
        return create_response(200, result)
        
    except Exception as e:
        logger.error(f"Error in handle_trends: {str(e)}", exc_info=True)
        return create_response(500, {'error': str(e)})


def handle_competitive_pricing(event: Dict) -> Dict:
    """
    Get competitive pricing data.
    
    Query parameters:
    - product_id: Optional product ID filter
    """
    try:
        params = event.get('queryStringParameters', {}) or {}
        product_id = params.get('product_id')
        
        logger.info(f"Fetching competitive pricing for product: {product_id or 'all'}")
        
        # Initialize Athena client
        athena = AthenaClient(
            workgroup=os.environ.get('ATHENA_WORKGROUP', 'primary')
        )
        
        # Fetch competitive pricing
        pricing = athena.get_competitive_pricing(product_id)
        
        if pricing.empty:
            return create_response(200, {
                'pricing': [],
                'message': 'No pricing data found'
            })
        
        # Convert to dict
        result = {
            'pricing': pricing.to_dict('records'),
            'count': len(pricing)
        }
        
        return create_response(200, result)
        
    except Exception as e:
        logger.error(f"Error in handle_competitive_pricing: {str(e)}", exc_info=True)
        return create_response(500, {'error': str(e)})


def handle_compare_models(event: Dict) -> Dict:
    """
    Compare forecasting models.
    
    Request body:
    {
        "models": ["arima", "prophet", "lstm"],
        "product_id": "optional",
        "category_id": "optional",
        "start_date": "2024-01-01",
        "end_date": "2025-01-15"
    }
    """
    try:
        body = json.loads(event.get('body', '{}'))
        
        # Extract parameters
        models_to_test = body.get('models', ['arima', 'prophet', 'lstm'])
        product_id = body.get('product_id')
        category_id = body.get('category_id')
        
        # Default date range: last 365 days
        end_date = body.get('end_date', datetime.now().strftime('%Y-%m-%d'))
        start_date = body.get('start_date', (datetime.now() - timedelta(days=365)).strftime('%Y-%m-%d'))
        
        logger.info(f"Comparing models: {models_to_test}")
        
        # Initialize Athena client
        athena = AthenaClient(
            workgroup=os.environ.get('ATHENA_WORKGROUP', 'primary')
        )
        
        # Fetch historical data
        sales_data = athena.get_sales_data(
            start_date=start_date,
            end_date=end_date,
            product_id=product_id,
            category_id=category_id
        )
        
        if sales_data.empty:
            return create_response(400, {'error': 'No data found for specified criteria'})
        
        # Extract time series
        series = sales_data['sales']
        
        # Compare models
        selector = ModelSelector(test_size=0.2)
        evaluation_results = selector.evaluate_models(series, models_to_test)
        
        # Get comparison table
        comparison = selector.get_model_comparison()
        
        # Get best model info
        best_model_name, _ = selector.get_best_model()
        
        result = {
            'evaluation_results': evaluation_results,
            'comparison': comparison.to_dict('records'),
            'best_model': best_model_name,
            'metadata': {
                'data_points': len(series),
                'start_date': start_date,
                'end_date': end_date,
                'product_id': product_id,
                'category_id': category_id
            }
        }
        
        return create_response(200, result)
        
    except Exception as e:
        logger.error(f"Error in handle_compare_models: {str(e)}", exc_info=True)
        return create_response(500, {'error': str(e)})
