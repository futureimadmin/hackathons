"""
AWS Lambda Handler for Global Market Pulse

Provides REST API endpoints for global and regional market analysis.
"""

import json
import logging
import os
from typing import Dict, Any
import pandas as pd

from market.trend_analyzer import TrendAnalyzer
from pricing.regional_comparator import RegionalComparator
from opportunity.opportunity_scorer import OpportunityScorer
from competitor.competitor_analyzer import CompetitorAnalyzer
from data.athena_client import AthenaClient

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Initialize components
athena_client = AthenaClient(
    database=os.environ.get('ATHENA_DATABASE', 'global_market_db'),
    output_location=os.environ.get('ATHENA_OUTPUT_LOCATION'),
    region=os.environ.get('AWS_REGION', 'us-east-1'),
    workgroup=os.environ.get('ATHENA_WORKGROUP', 'primary')
)

# Global instances (reused across invocations)
trend_analyzer = TrendAnalyzer()
regional_comparator = RegionalComparator()
opportunity_scorer = OpportunityScorer()
competitor_analyzer = CompetitorAnalyzer()


def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """
    Main Lambda handler for Global Market Pulse.
    
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
        if path == '/global-market/trends' and method == 'GET':
            return handle_market_trends(query_params)
        
        elif path == '/global-market/regional-prices' and method == 'GET':
            return handle_regional_prices(query_params)
        
        elif path == '/global-market/price-comparison' and method == 'POST':
            return handle_price_comparison(body)
        
        elif path == '/global-market/opportunities' and method == 'POST':
            return handle_market_opportunities(body)
        
        elif path == '/global-market/competitor-analysis' and method == 'POST':
            return handle_competitor_analysis(body)
        
        elif path == '/global-market/market-share' and method == 'GET':
            return handle_market_share(query_params)
        
        elif path == '/global-market/growth-rates' and method == 'GET':
            return handle_growth_rates(query_params)
        
        elif path == '/global-market/trend-changes' and method == 'POST':
            return handle_trend_changes(body)
        
        else:
            return create_response(404, {'error': 'Endpoint not found'})
    
    except Exception as e:
        logger.error(f"Error processing request: {str(e)}", exc_info=True)
        return create_response(500, {'error': str(e)})


def handle_market_trends(params: Dict) -> Dict:
    """
    Handle market trends request.
    
    GET /global-market/trends?region=USA&days=90
    """
    try:
        # Get parameters
        region = params.get('region')
        days = int(params.get('days', 90))
        
        # Fetch trend data
        logger.info(f"Fetching market trends for region={region}, days={days}")
        trend_data = athena_client.get_market_trends(region=region, days=days)
        
        if trend_data.empty:
            return create_response(404, {'error': 'No trend data found'})
        
        # Analyze trends
        logger.info("Analyzing market trends...")
        analysis = trend_analyzer.analyze_trends(
            trend_data,
            date_column='date',
            value_column='total_sales',
            region_column='region' if region is None else None
        )
        
        return create_response(200, {
            'analysis': analysis,
            'data_points': len(trend_data),
            'region': region,
            'period_days': days
        })
    
    except Exception as e:
        logger.error(f"Error analyzing market trends: {str(e)}")
        return create_response(500, {'error': str(e)})


def handle_regional_prices(params: Dict) -> Dict:
    """
    Handle regional prices request.
    
    GET /global-market/regional-prices?limit=1000
    """
    try:
        # Get parameters
        limit = int(params.get('limit', 1000))
        
        # Fetch regional pricing data
        logger.info(f"Fetching regional prices (limit={limit})")
        price_data = athena_client.get_regional_prices(limit=limit)
        
        if price_data.empty:
            return create_response(404, {'error': 'No pricing data found'})
        
        return create_response(200, {
            'prices': price_data.to_dict('records'),
            'count': len(price_data)
        })
    
    except Exception as e:
        logger.error(f"Error fetching regional prices: {str(e)}")
        return create_response(500, {'error': str(e)})


def handle_price_comparison(body: Dict) -> Dict:
    """
    Handle price comparison request.
    
    POST /global-market/price-comparison
    Body: {
        "product_ids": ["optional", "list"],
        "regions": ["optional", "list"]
    }
    """
    try:
        # Get parameters
        product_ids = body.get('product_ids')
        
        # Fetch pricing data
        logger.info("Fetching pricing data for comparison...")
        price_data = athena_client.get_regional_prices(product_ids=product_ids)
        
        if price_data.empty:
            return create_response(404, {'error': 'No pricing data found'})
        
        # Convert numeric columns
        numeric_cols = ['price', 'order_count', 'total_quantity']
        for col in numeric_cols:
            if col in price_data.columns:
                price_data[col] = pd.to_numeric(price_data[col], errors='coerce')
        
        price_data = price_data.fillna(0)
        
        # Perform comparison
        logger.info("Comparing regional prices...")
        comparison = regional_comparator.compare_regional_prices(
            price_data,
            region_column='region',
            price_column='price',
            currency_column='currency',
            product_column='product_id'
        )
        
        return create_response(200, comparison)
    
    except Exception as e:
        logger.error(f"Error comparing prices: {str(e)}")
        return create_response(500, {'error': str(e)})


def handle_market_opportunities(body: Dict) -> Dict:
    """
    Handle market opportunities request.
    
    POST /global-market/opportunities
    Body: {
        "weights": {
            "market_size": 0.25,
            "growth_rate": 0.25,
            "competition_level": 0.20,
            "price_premium": 0.15,
            "market_maturity": 0.15
        },
        "top_n": 10
    }
    """
    try:
        # Get parameters
        weights = body.get('weights')
        top_n = body.get('top_n', 10)
        
        # Fetch opportunity data
        logger.info("Fetching market opportunity data...")
        opp_data = athena_client.get_market_opportunity_data()
        
        if opp_data.empty:
            return create_response(404, {'error': 'No opportunity data found'})
        
        # Convert numeric columns
        numeric_cols = ['market_size', 'total_revenue', 'avg_order_value', 
                       'unique_customers', 'product_variety', 'avg_price']
        for col in numeric_cols:
            if col in opp_data.columns:
                opp_data[col] = pd.to_numeric(opp_data[col], errors='coerce')
        
        opp_data = opp_data.fillna(0)
        
        # Fetch growth rates
        growth_data = athena_client.get_regional_growth_rates()
        if not growth_data.empty:
            growth_data['avg_growth_rate'] = pd.to_numeric(growth_data['avg_growth_rate'], errors='coerce')
            opp_data = opp_data.merge(
                growth_data[['region', 'avg_growth_rate']],
                on='region',
                how='left'
            )
            opp_data['growth_rate'] = opp_data['avg_growth_rate'].fillna(0)
        else:
            opp_data['growth_rate'] = 0
        
        # Add synthetic metrics for scoring
        opp_data['competition_level'] = 50  # Placeholder
        opp_data['price_premium'] = opp_data['avg_price'] / opp_data['avg_price'].mean() * 100
        opp_data['market_maturity'] = 50  # Placeholder
        
        # Score opportunities
        logger.info("Scoring market opportunities...")
        scored_data = opportunity_scorer.score_opportunities(
            opp_data,
            region_column='region',
            weights=weights
        )
        
        # Get top opportunities
        top_opportunities = opportunity_scorer.rank_opportunities(
            scored_data,
            region_column='region',
            top_n=top_n
        )
        
        return create_response(200, {
            'opportunities': top_opportunities,
            'total_regions': len(scored_data),
            'weights_used': weights if weights else opportunity_scorer.default_weights
        })
    
    except Exception as e:
        logger.error(f"Error scoring opportunities: {str(e)}")
        return create_response(500, {'error': str(e)})


def handle_competitor_analysis(body: Dict) -> Dict:
    """
    Handle competitor analysis request.
    
    POST /global-market/competitor-analysis
    Body: {
        "region": "optional",
        "analysis_type": "pricing" | "market_share"
    }
    """
    try:
        # Get parameters
        region = body.get('region')
        analysis_type = body.get('analysis_type', 'pricing')
        
        # Fetch competitor data
        logger.info(f"Fetching competitor data for region={region}")
        comp_data = athena_client.get_competitor_data(region=region)
        
        if comp_data.empty:
            return create_response(404, {'error': 'No competitor data found'})
        
        # Convert numeric columns
        numeric_cols = ['price', 'sales_quantity', 'sales_revenue']
        for col in numeric_cols:
            if col in comp_data.columns:
                comp_data[col] = pd.to_numeric(comp_data[col], errors='coerce')
        
        comp_data = comp_data.fillna(0)
        
        if analysis_type == 'pricing':
            # Analyze competitor pricing
            logger.info("Analyzing competitor pricing...")
            analysis = competitor_analyzer.analyze_competitor_pricing(
                comp_data,
                competitor_column='competitor',
                price_column='price',
                region_column='region',
                product_column='product_id'
            )
        elif analysis_type == 'market_share':
            # Analyze market share
            logger.info("Analyzing market share...")
            analysis = competitor_analyzer.analyze_market_share(
                comp_data,
                competitor_column='competitor',
                sales_column='sales_revenue',
                region_column='region'
            )
        else:
            return create_response(400, {'error': f'Invalid analysis_type: {analysis_type}'})
        
        return create_response(200, analysis)
    
    except Exception as e:
        logger.error(f"Error analyzing competitors: {str(e)}")
        return create_response(500, {'error': str(e)})


def handle_market_share(params: Dict) -> Dict:
    """
    Handle market share request.
    
    GET /global-market/market-share?region=USA
    """
    try:
        # Get parameters
        region = params.get('region')
        
        # Fetch competitor data
        logger.info(f"Fetching market share data for region={region}")
        comp_data = athena_client.get_competitor_data(region=region)
        
        if comp_data.empty:
            return create_response(404, {'error': 'No competitor data found'})
        
        # Convert numeric columns
        comp_data['sales_revenue'] = pd.to_numeric(comp_data['sales_revenue'], errors='coerce')
        comp_data = comp_data.fillna(0)
        
        # Analyze market share
        logger.info("Analyzing market share...")
        analysis = competitor_analyzer.analyze_market_share(
            comp_data,
            competitor_column='competitor',
            sales_column='sales_revenue',
            region_column='region'
        )
        
        return create_response(200, analysis)
    
    except Exception as e:
        logger.error(f"Error analyzing market share: {str(e)}")
        return create_response(500, {'error': str(e)})


def handle_growth_rates(params: Dict) -> Dict:
    """
    Handle growth rates request.
    
    GET /global-market/growth-rates?days=180
    """
    try:
        # Get parameters
        days = int(params.get('days', 180))
        
        # Fetch growth rates
        logger.info(f"Fetching growth rates (days={days})")
        growth_data = athena_client.get_regional_growth_rates(days=days)
        
        if growth_data.empty:
            return create_response(404, {'error': 'No growth data found'})
        
        # Convert numeric columns
        numeric_cols = ['avg_growth_rate', 'total_revenue', 'months_count']
        for col in numeric_cols:
            if col in growth_data.columns:
                growth_data[col] = pd.to_numeric(growth_data[col], errors='coerce')
        
        return create_response(200, {
            'growth_rates': growth_data.to_dict('records'),
            'count': len(growth_data),
            'period_days': days
        })
    
    except Exception as e:
        logger.error(f"Error fetching growth rates: {str(e)}")
        return create_response(500, {'error': str(e)})


def handle_trend_changes(body: Dict) -> Dict:
    """
    Handle trend changes detection request.
    
    POST /global-market/trend-changes
    Body: {
        "region": "optional",
        "days": 90,
        "window": 7
    }
    """
    try:
        # Get parameters
        region = body.get('region')
        days = body.get('days', 90)
        window = body.get('window', 7)
        
        # Fetch trend data
        logger.info(f"Fetching trend data for change detection...")
        trend_data = athena_client.get_market_trends(region=region, days=days)
        
        if trend_data.empty:
            return create_response(404, {'error': 'No trend data found'})
        
        # Convert numeric columns
        trend_data['total_sales'] = pd.to_numeric(trend_data['total_sales'], errors='coerce')
        trend_data = trend_data.fillna(0)
        
        # Detect trend changes
        logger.info("Detecting trend changes...")
        changes = trend_analyzer.detect_trend_changes(
            trend_data,
            date_column='date',
            value_column='total_sales',
            window=window
        )
        
        return create_response(200, {
            'trend_changes': changes,
            'changes_detected': len(changes),
            'region': region,
            'period_days': days,
            'window_size': window
        })
    
    except Exception as e:
        logger.error(f"Error detecting trend changes: {str(e)}")
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
