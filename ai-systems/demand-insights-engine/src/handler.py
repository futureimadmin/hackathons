"""
AWS Lambda Handler for Demand Insights Engine

Provides REST API endpoints for customer segmentation, demand forecasting,
price elasticity, CLV prediction, and churn analysis.
"""

import json
import logging
import os
from typing import Dict, Any
import pandas as pd

from segmentation.customer_segmentation import CustomerSegmentation
from forecasting.demand_forecaster import DemandForecaster
from pricing.price_elasticity import PriceElasticityAnalyzer
from customer.clv_predictor import CLVPredictor
from customer.churn_predictor import ChurnPredictor
from data.athena_client import AthenaClient

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Initialize components
athena_client = AthenaClient(
    database=os.environ.get('ATHENA_DATABASE', 'demand_insights_db'),
    output_location=os.environ.get('ATHENA_OUTPUT_LOCATION', 's3://ecommerce-athena-results/'),
    region=os.environ.get('AWS_REGION', 'us-east-1')
)

# Global model instances (reused across invocations)
segmentation_model = None
demand_forecaster = None
elasticity_analyzer = None
clv_predictor = None
churn_predictor = None


def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """
    Main Lambda handler for Demand Insights Engine.
    
    Routes requests to appropriate handlers based on path and method.
    """
    try:
        # Parse request
        path = event.get('path', '')
        method = event.get('httpMethod', 'GET')
        body = json.loads(event.get('body', '{}')) if event.get('body') else {}
        query_params = event.get('queryStringParameters', {}) or {}
        
        logger.info(f"Request: {method} {path}")
        
        # Route to appropriate handler
        if path == '/demand-insights/segments' and method == 'GET':
            return handle_customer_segmentation(query_params)
        
        elif path == '/demand-insights/forecast' and method == 'POST':
            return handle_demand_forecast(body)
        
        elif path == '/demand-insights/price-elasticity' and method == 'POST':
            return handle_price_elasticity(body)
        
        elif path == '/demand-insights/price-optimization' and method == 'POST':
            return handle_price_optimization(body)
        
        elif path == '/demand-insights/clv' and method == 'POST':
            return handle_clv_prediction(body)
        
        elif path == '/demand-insights/churn' and method == 'POST':
            return handle_churn_prediction(body)
        
        elif path == '/demand-insights/at-risk-customers' and method == 'GET':
            return handle_at_risk_customers(query_params)
        
        else:
            return create_response(404, {'error': 'Endpoint not found'})
    
    except Exception as e:
        logger.error(f"Error processing request: {str(e)}", exc_info=True)
        return create_response(500, {'error': str(e)})


def handle_customer_segmentation(params: Dict) -> Dict:
    """
    Handle customer segmentation request.
    
    GET /demand-insights/segments?n_clusters=5
    """
    try:
        global segmentation_model
        
        # Get parameters
        n_clusters = int(params.get('n_clusters', 0))
        
        # Fetch customer data
        logger.info("Fetching customer data from Athena...")
        customer_data = athena_client.get_customer_segments_data()
        
        if customer_data.empty:
            return create_response(404, {'error': 'No customer data found'})
        
        # Convert string columns to numeric
        for col in ['recency_days', 'frequency', 'monetary_total', 'customer_age_days']:
            customer_data[col] = pd.to_numeric(customer_data[col], errors='coerce')
        
        customer_data = customer_data.dropna()
        
        # Initialize or reuse segmentation model
        if segmentation_model is None:
            segmentation_model = CustomerSegmentation()
        
        # Perform segmentation
        logger.info("Performing customer segmentation...")
        segments = segmentation_model.segment_customers(
            customer_data,
            n_clusters=n_clusters if n_clusters > 0 else None
        )
        
        # Get segment profiles
        profiles = segmentation_model.get_segment_profiles(segments)
        
        return create_response(200, {
            'segments': profiles,
            'total_customers': len(segments),
            'n_clusters': segmentation_model.optimal_clusters
        })
    
    except Exception as e:
        logger.error(f"Error in customer segmentation: {str(e)}")
        return create_response(500, {'error': str(e)})


def handle_demand_forecast(body: Dict) -> Dict:
    """
    Handle demand forecasting request.
    
    POST /demand-insights/forecast
    Body: {
        "product_id": "optional",
        "category_id": "optional",
        "forecast_days": 30
    }
    """
    try:
        global demand_forecaster
        
        # Get parameters
        product_id = body.get('product_id')
        category_id = body.get('category_id')
        forecast_days = body.get('forecast_days', 30)
        
        # Fetch sales data
        logger.info("Fetching sales data from Athena...")
        sales_data = athena_client.get_sales_data(
            product_ids=[product_id] if product_id else None
        )
        
        if sales_data.empty:
            return create_response(404, {'error': 'No sales data found'})
        
        # Convert columns to appropriate types
        sales_data['date'] = pd.to_datetime(sales_data['date'])
        for col in ['quantity', 'avg_price', 'revenue']:
            sales_data[col] = pd.to_numeric(sales_data[col], errors='coerce')
        
        sales_data = sales_data.dropna()
        
        # Initialize or reuse forecaster
        if demand_forecaster is None:
            demand_forecaster = DemandForecaster()
        
        # Train and forecast
        logger.info("Training demand forecasting model...")
        demand_forecaster.train(sales_data, target_column='quantity')
        
        logger.info(f"Generating {forecast_days}-day forecast...")
        forecast = demand_forecaster.forecast(forecast_days)
        
        # Get feature importance
        importance = demand_forecaster.get_feature_importance()
        
        return create_response(200, {
            'forecast': forecast.to_dict('records'),
            'feature_importance': importance.head(10).to_dict('records'),
            'forecast_days': forecast_days
        })
    
    except Exception as e:
        logger.error(f"Error in demand forecasting: {str(e)}")
        return create_response(500, {'error': str(e)})


def handle_price_elasticity(body: Dict) -> Dict:
    """
    Handle price elasticity calculation request.
    
    POST /demand-insights/price-elasticity
    Body: {
        "product_id": "optional",
        "category": "optional"
    }
    """
    try:
        global elasticity_analyzer
        
        # Get parameters
        product_id = body.get('product_id')
        category = body.get('category')
        
        # Fetch price history
        logger.info("Fetching price history from Athena...")
        price_data = athena_client.get_price_history(
            product_id=product_id,
            category_id=category
        )
        
        if price_data.empty:
            return create_response(404, {'error': 'No price data found'})
        
        # Convert columns
        price_data['date'] = pd.to_datetime(price_data['date'])
        for col in ['price', 'quantity']:
            price_data[col] = pd.to_numeric(price_data[col], errors='coerce')
        
        price_data = price_data.dropna()
        
        # Initialize or reuse analyzer
        if elasticity_analyzer is None:
            elasticity_analyzer = PriceElasticityAnalyzer()
        
        # Calculate elasticity
        logger.info("Calculating price elasticity...")
        elasticity = elasticity_analyzer.calculate_elasticity(
            price_data,
            product_id=product_id,
            category=category
        )
        
        return create_response(200, elasticity)
    
    except Exception as e:
        logger.error(f"Error calculating price elasticity: {str(e)}")
        return create_response(500, {'error': str(e)})


def handle_price_optimization(body: Dict) -> Dict:
    """
    Handle price optimization request.
    
    POST /demand-insights/price-optimization
    Body: {
        "product_id": "required",
        "current_price": 100.0,
        "current_quantity": 1000,
        "cost_per_unit": 60.0
    }
    """
    try:
        global elasticity_analyzer
        
        # Get parameters
        product_id = body.get('product_id')
        current_price = float(body.get('current_price'))
        current_quantity = float(body.get('current_quantity'))
        cost_per_unit = float(body.get('cost_per_unit'))
        
        if not all([product_id, current_price, current_quantity, cost_per_unit]):
            return create_response(400, {'error': 'Missing required parameters'})
        
        # Initialize analyzer if needed
        if elasticity_analyzer is None:
            elasticity_analyzer = PriceElasticityAnalyzer()
            
            # Calculate elasticity first
            price_data = athena_client.get_price_history(product_id=product_id)
            if not price_data.empty:
                price_data['date'] = pd.to_datetime(price_data['date'])
                for col in ['price', 'quantity']:
                    price_data[col] = pd.to_numeric(price_data[col], errors='coerce')
                price_data = price_data.dropna()
                elasticity_analyzer.calculate_elasticity(price_data, product_id=product_id)
        
        # Optimize price
        logger.info("Optimizing price...")
        optimization = elasticity_analyzer.optimize_price(
            current_price=current_price,
            current_quantity=current_quantity,
            cost_per_unit=cost_per_unit,
            product_id=product_id
        )
        
        return create_response(200, optimization)
    
    except Exception as e:
        logger.error(f"Error optimizing price: {str(e)}")
        return create_response(500, {'error': str(e)})


def handle_clv_prediction(body: Dict) -> Dict:
    """
    Handle CLV prediction request.
    
    POST /demand-insights/clv
    Body: {
        "customer_ids": ["optional", "list"]
    }
    """
    try:
        global clv_predictor
        
        # Get parameters
        customer_ids = body.get('customer_ids')
        
        # Fetch customer data
        logger.info("Fetching customer data from Athena...")
        customer_data = athena_client.get_customer_data(customer_ids=customer_ids)
        
        if customer_data.empty:
            return create_response(404, {'error': 'No customer data found'})
        
        # Convert columns
        numeric_cols = ['recency_days', 'frequency', 'monetary_total', 'customer_age_days',
                       'unique_products_purchased', 'unique_categories_purchased', 'avg_rating', 'return_rate']
        for col in numeric_cols:
            if col in customer_data.columns:
                customer_data[col] = pd.to_numeric(customer_data[col], errors='coerce')
        
        customer_data = customer_data.fillna(0)
        
        # Initialize predictor if needed
        if clv_predictor is None:
            clv_predictor = CLVPredictor()
            
            # Train model (in production, load pre-trained model)
            # For now, calculate simple CLV
            logger.info("Calculating CLV...")
            customer_data['predicted_clv'] = customer_data.apply(
                lambda row: clv_predictor.calculate_clv_simple(
                    avg_order_value=row['monetary_total'] / max(row['frequency'], 1),
                    purchase_frequency=row['frequency'] / max(row['customer_age_days'] / 365, 0.1),
                    customer_lifespan_years=3.0,
                    profit_margin=0.2
                ),
                axis=1
            )
        else:
            # Use trained model
            customer_data = clv_predictor.predict(customer_data)
        
        # Segment by CLV
        segments = clv_predictor.segment_by_clv(customer_data)
        
        return create_response(200, {
            'predictions': customer_data[['customer_id', 'predicted_clv', 'clv_segment']].to_dict('records'),
            'segments': segments
        })
    
    except Exception as e:
        logger.error(f"Error predicting CLV: {str(e)}")
        return create_response(500, {'error': str(e)})


def handle_churn_prediction(body: Dict) -> Dict:
    """
    Handle churn prediction request.
    
    POST /demand-insights/churn
    Body: {
        "customer_ids": ["optional", "list"]
    }
    """
    try:
        global churn_predictor
        
        # Get parameters
        customer_ids = body.get('customer_ids')
        
        # Fetch customer data
        logger.info("Fetching customer data from Athena...")
        customer_data = athena_client.get_customer_data(customer_ids=customer_ids)
        
        if customer_data.empty:
            return create_response(404, {'error': 'No customer data found'})
        
        # Convert columns
        numeric_cols = ['recency_days', 'frequency', 'monetary_total', 'customer_age_days',
                       'unique_products_purchased', 'unique_categories_purchased', 'avg_rating', 'return_rate']
        for col in numeric_cols:
            if col in customer_data.columns:
                customer_data[col] = pd.to_numeric(customer_data[col], errors='coerce')
        
        customer_data = customer_data.fillna(0)
        
        # Initialize predictor if needed (in production, load pre-trained model)
        if churn_predictor is None:
            churn_predictor = ChurnPredictor()
            
            # Simple rule-based churn prediction for demo
            logger.info("Calculating churn probability...")
            customer_data['churn_probability'] = customer_data.apply(
                lambda row: min(1.0, (row['recency_days'] / 180) * 0.7 + 
                               (1 / max(row['frequency'], 1)) * 0.3),
                axis=1
            )
            customer_data['risk_level'] = pd.cut(
                customer_data['churn_probability'],
                bins=[0, 0.3, 0.6, 0.8, 1.0],
                labels=['Low', 'Medium', 'High', 'Critical']
            )
        else:
            # Use trained model
            customer_data = churn_predictor.predict(customer_data)
        
        # Analyze churn factors
        at_risk_count = len(customer_data[customer_data['churn_probability'] >= 0.6])
        
        return create_response(200, {
            'predictions': customer_data[['customer_id', 'churn_probability', 'risk_level']].to_dict('records'),
            'summary': {
                'total_customers': len(customer_data),
                'at_risk_count': at_risk_count,
                'at_risk_percentage': float(at_risk_count / len(customer_data) * 100),
                'avg_churn_probability': float(customer_data['churn_probability'].mean())
            }
        })
    
    except Exception as e:
        logger.error(f"Error predicting churn: {str(e)}")
        return create_response(500, {'error': str(e)})


def handle_at_risk_customers(params: Dict) -> Dict:
    """
    Handle at-risk customers request.
    
    GET /demand-insights/at-risk-customers?threshold=0.6&limit=100
    """
    try:
        # Get parameters
        threshold = float(params.get('threshold', 0.6))
        limit = int(params.get('limit', 100))
        
        # Fetch customer data
        logger.info("Fetching customer data from Athena...")
        customer_data = athena_client.get_customer_data(limit=limit * 2)  # Fetch more to filter
        
        if customer_data.empty:
            return create_response(404, {'error': 'No customer data found'})
        
        # Convert columns
        numeric_cols = ['recency_days', 'frequency', 'monetary_total']
        for col in numeric_cols:
            if col in customer_data.columns:
                customer_data[col] = pd.to_numeric(customer_data[col], errors='coerce')
        
        customer_data = customer_data.fillna(0)
        
        # Calculate simple churn risk
        customer_data['churn_probability'] = customer_data.apply(
            lambda row: min(1.0, (row['recency_days'] / 180) * 0.7 + 
                           (1 / max(row['frequency'], 1)) * 0.3),
            axis=1
        )
        
        # Filter at-risk customers
        at_risk = customer_data[customer_data['churn_probability'] >= threshold]
        at_risk = at_risk.sort_values('churn_probability', ascending=False).head(limit)
        
        return create_response(200, {
            'at_risk_customers': at_risk[['customer_id', 'email', 'churn_probability', 
                                         'recency_days', 'frequency', 'monetary_total']].to_dict('records'),
            'count': len(at_risk),
            'threshold': threshold
        })
    
    except Exception as e:
        logger.error(f"Error fetching at-risk customers: {str(e)}")
        return create_response(500, {'error': str(e)})


def create_response(status_code: int, body: Dict) -> Dict:
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
