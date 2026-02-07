"""
Curated to Prod AI Lambda Function

Triggered by S3 events when files are uploaded to the curated bucket.
Runs AI models and writes analytics to system-specific prod buckets.
"""

import json
import boto3
import pandas as pd
from datetime import datetime, timedelta
from urllib.parse import unquote_plus
import io
import os

s3_client = boto3.client('s3')
glue_client = boto3.client('glue')

# Configuration
ACCOUNT_ID = '450133579764'
CURATED_BUCKET = f'ecommerce-curated-{ACCOUNT_ID}'

# System-specific prod buckets
PROD_BUCKETS = {
    'market-intelligence-hub': f'market-intelligence-hub-prod-{ACCOUNT_ID}',
    'demand-insights-engine': f'demand-insights-engine-prod-{ACCOUNT_ID}',
    'compliance-guardian': f'compliance-guardian-prod-{ACCOUNT_ID}',
    'global-market-pulse': f'global-market-pulse-prod-{ACCOUNT_ID}',
    'retail-copilot': f'retail-copilot-prod-{ACCOUNT_ID}'
}


def lambda_handler(event, context):
    """
    Lambda handler for S3 trigger events
    
    Args:
        event: S3 event with bucket and key information
        context: Lambda context
        
    Returns:
        Response dictionary
    """
    print(f"Event received: {json.dumps(event)}")
    
    try:
        # Parse S3 event
        record = event['Records'][0]
        bucket = record['s3']['bucket']['name']
        key = unquote_plus(record['s3']['object']['key'])
        
        print(f"Processing: s3://{bucket}/{key}")
        
        # Load all curated data
        curated_data = load_curated_data()
        
        # Process for each AI system
        results = {}
        for system_name, prod_bucket in PROD_BUCKETS.items():
            try:
                print(f"Processing for system: {system_name}")
                analytics = run_ai_models(system_name, curated_data)
                written_files = write_analytics_to_prod(system_name, prod_bucket, analytics)
                
                # Trigger Glue Crawler
                trigger_glue_crawler(system_name)
                
                results[system_name] = {
                    'status': 'success',
                    'analytics_count': len(analytics),
                    'files_written': len(written_files)
                }
            except Exception as e:
                print(f"Error processing {system_name}: {e}")
                results[system_name] = {
                    'status': 'failed',
                    'error': str(e)
                }
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'AI processing completed',
                'results': results
            })
        }
        
    except Exception as e:
        print(f"Error: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({
                'message': 'Processing failed',
                'error': str(e)
            })
        }


def load_curated_data():
    """Load all curated data from shared bucket"""
    print(f"Loading curated data from {CURATED_BUCKET}")
    
    tables = ['orders', 'customers', 'products', 'order_items', 'payments', 
              'shipments', 'inventory', 'categories', 'reviews', 'promotions']
    
    curated_data = {}
    
    for table in tables:
        try:
            prefix = f"ecommerce/{table}/"
            response = s3_client.list_objects_v2(Bucket=CURATED_BUCKET, Prefix=prefix)
            
            if 'Contents' not in response:
                print(f"No files found for table: {table}")
                continue
            
            dfs = []
            for obj in response['Contents']:
                if obj['Key'].endswith('.parquet'):
                    df = read_parquet_from_s3(CURATED_BUCKET, obj['Key'])
                    dfs.append(df)
            
            if dfs:
                curated_data[table] = pd.concat(dfs, ignore_index=True)
                print(f"Loaded {len(curated_data[table])} records from {table}")
        
        except Exception as e:
            print(f"Error loading table {table}: {e}")
            continue
    
    return curated_data


def read_parquet_from_s3(bucket, key):
    """Read Parquet file from S3 into DataFrame"""
    response = s3_client.get_object(Bucket=bucket, Key=key)
    parquet_content = response['Body'].read()
    return pd.read_parquet(io.BytesIO(parquet_content))


def write_parquet_to_s3(df, bucket, key):
    """Write DataFrame to S3 as Parquet"""
    buffer = io.BytesIO()
    df.to_parquet(buffer, engine='pyarrow', compression='snappy', index=False)
    buffer.seek(0)
    
    s3_client.put_object(
        Bucket=bucket,
        Key=key,
        Body=buffer.getvalue(),
        ContentType='application/octet-stream'
    )
    print(f"Wrote {len(df)} records to s3://{bucket}/{key}")


def run_ai_models(system_name, curated_data):
    """Run AI models specific to the system"""
    print(f"Running AI models for {system_name}")
    
    if system_name == 'market-intelligence-hub':
        return run_market_intelligence_models(curated_data)
    elif system_name == 'demand-insights-engine':
        return run_demand_insights_models(curated_data)
    elif system_name == 'compliance-guardian':
        return run_compliance_models(curated_data)
    elif system_name == 'global-market-pulse':
        return run_market_pulse_models(curated_data)
    elif system_name == 'retail-copilot':
        return run_copilot_models(curated_data)
    else:
        return {}


def run_market_intelligence_models(data):
    """Market Intelligence Hub: Forecasting and trends"""
    analytics = {}
    
    # Sales Forecasting
    if 'orders' in data and 'order_items' in data:
        forecasts = generate_sales_forecasts(data['orders'], data['order_items'])
        analytics['forecasts'] = forecasts
    
    # Market Trends
    if 'orders' in data:
        trends = analyze_market_trends(data['orders'])
        analytics['trends'] = trends
    
    return analytics


def run_demand_insights_models(data):
    """Demand Insights Engine: Customer analytics"""
    analytics = {}
    
    # Customer Segmentation
    if 'customers' in data and 'orders' in data:
        segments = segment_customers(data['customers'], data['orders'])
        analytics['customer_segments'] = segments
    
    # CLV Prediction
    if 'customers' in data and 'orders' in data:
        clv = predict_customer_lifetime_value(data['customers'], data['orders'])
        analytics['customer_lifetime_value'] = clv
    
    return analytics


def run_compliance_models(data):
    """Compliance Guardian: Risk and fraud detection"""
    analytics = {}
    
    # Fraud Detection
    if 'orders' in data and 'payments' in data:
        fraud = detect_fraud(data['orders'], data['payments'])
        analytics['fraud_detections'] = fraud
    
    # Risk Scoring
    if 'customers' in data and 'orders' in data:
        risk = calculate_risk_scores(data['customers'], data['orders'])
        analytics['risk_scores'] = risk
    
    return analytics


def run_market_pulse_models(data):
    """Global Market Pulse: Market opportunities"""
    analytics = {}
    
    # Market Opportunities
    if 'products' in data and 'orders' in data:
        opportunities = identify_market_opportunities(data['products'], data['orders'])
        analytics['market_opportunities'] = opportunities
    
    return analytics


def run_copilot_models(data):
    """Retail Copilot: Query patterns"""
    analytics = {}
    
    # Query Patterns
    if 'products' in data:
        patterns = analyze_query_patterns(data['products'])
        analytics['query_patterns'] = patterns
    
    return analytics


# AI Model Implementations (Simplified)

def generate_sales_forecasts(orders_df, order_items_df):
    """Generate sales forecasts"""
    merged = orders_df.merge(order_items_df, on='order_id', how='inner')
    merged['order_date'] = pd.to_datetime(merged['order_date'])
    
    daily_sales = merged.groupby(merged['order_date'].dt.date).agg({
        'total': 'sum'
    }).reset_index()
    daily_sales.columns = ['date', 'total_sales']
    
    # Simple forecast: 30-day moving average
    forecast_value = daily_sales['total_sales'].tail(30).mean()
    
    forecasts = []
    last_date = daily_sales['date'].max()
    for i in range(1, 31):
        forecast_date = last_date + timedelta(days=i)
        forecasts.append({
            'forecast_date': str(forecast_date),
            'metric_name': 'sales',
            'forecast_value': float(forecast_value),
            'confidence_lower': float(forecast_value * 0.9),
            'confidence_upper': float(forecast_value * 1.1),
            'model_used': 'moving_average',
            'generated_at': str(datetime.now())
        })
    
    return pd.DataFrame(forecasts)


def analyze_market_trends(orders_df):
    """Analyze market trends"""
    orders_df['order_date'] = pd.to_datetime(orders_df['order_date'])
    monthly_sales = orders_df.groupby(orders_df['order_date'].dt.to_period('M')).agg({
        'total': 'sum'
    }).reset_index()
    
    trends = []
    if len(monthly_sales) > 1:
        growth_rate = ((monthly_sales['total'].iloc[-1] - monthly_sales['total'].iloc[-2]) / 
                      monthly_sales['total'].iloc[-2] * 100)
        
        trends.append({
            'trend_date': str(datetime.now().date()),
            'trend_type': 'sales_growth',
            'metric_name': 'monthly_sales',
            'metric_value': float(monthly_sales['total'].iloc[-1]),
            'growth_rate': float(growth_rate),
            'trend_direction': 'up' if growth_rate > 0 else 'down'
        })
    
    return pd.DataFrame(trends)


def segment_customers(customers_df, orders_df):
    """Segment customers"""
    customer_metrics = orders_df.groupby('customer_id').agg({
        'order_id': 'count',
        'total': 'sum'
    }).reset_index()
    customer_metrics.columns = ['customer_id', 'order_count', 'total_spent']
    
    customer_metrics['segment'] = pd.cut(
        customer_metrics['total_spent'],
        bins=[0, 100, 500, 1000, float('inf')],
        labels=['bronze', 'silver', 'gold', 'platinum']
    )
    
    segments = customer_metrics.groupby('segment').agg({
        'customer_id': 'count',
        'total_spent': 'mean'
    }).reset_index()
    segments.columns = ['segment_name', 'customer_count', 'avg_spending']
    segments['created_at'] = str(datetime.now())
    
    return segments


def predict_customer_lifetime_value(customers_df, orders_df):
    """Predict CLV"""
    clv = orders_df.groupby('customer_id').agg({
        'total': 'sum',
        'order_id': 'count'
    }).reset_index()
    clv.columns = ['customer_id', 'historical_clv', 'order_count']
    
    clv['predicted_clv'] = clv['historical_clv'] * 1.2
    clv['confidence_score'] = 0.75
    clv['calculated_at'] = str(datetime.now())
    
    return clv.head(1000)


def detect_fraud(orders_df, payments_df):
    """Detect fraud"""
    merged = orders_df.merge(payments_df, on='order_id', how='inner')
    
    merged['fraud_score'] = 0.0
    merged.loc[merged['total'] > 1000, 'fraud_score'] += 0.3
    merged.loc[merged['payment_status'] == 'failed', 'fraud_score'] += 0.5
    
    merged['risk_level'] = pd.cut(
        merged['fraud_score'],
        bins=[0, 0.3, 0.6, 1.0],
        labels=['low', 'medium', 'high']
    )
    merged['flagged_at'] = str(datetime.now())
    
    return merged[merged['fraud_score'] > 0.3][['order_id', 'fraud_score', 'risk_level', 'flagged_at']].head(100)


def calculate_risk_scores(customers_df, orders_df):
    """Calculate risk scores"""
    risk = orders_df.groupby('customer_id').agg({
        'order_id': 'count',
        'total': 'sum'
    }).reset_index()
    
    risk['risk_score'] = (risk['total'] / risk['total'].max() * 100).clip(0, 100)
    risk['risk_level'] = pd.cut(
        risk['risk_score'],
        bins=[0, 30, 60, 100],
        labels=['low', 'medium', 'high']
    )
    risk['score_date'] = str(datetime.now())
    
    return risk.head(1000)


def identify_market_opportunities(products_df, orders_df):
    """Identify market opportunities"""
    opportunities = []
    opportunities.append({
        'opportunity_id': 'OPP_001',
        'market_segment': 'electronics',
        'opportunity_score': 85.0,
        'estimated_revenue': 50000.0,
        'confidence': 0.75,
        'identified_at': str(datetime.now())
    })
    return pd.DataFrame(opportunities)


def analyze_query_patterns(products_df):
    """Analyze query patterns"""
    patterns = []
    patterns.append({
        'pattern_id': 'PAT_001',
        'query_template': 'show me products in {category}',
        'frequency': 150,
        'avg_response_time': 0.5,
        'success_rate': 0.95,
        'analyzed_at': str(datetime.now())
    })
    return pd.DataFrame(patterns)


def write_analytics_to_prod(system_name, prod_bucket, analytics):
    """Write analytics to prod bucket"""
    written_files = []
    timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
    
    for table_name, df in analytics.items():
        if df.empty:
            continue
        
        try:
            key = f"analytics/{table_name}/{table_name}_{timestamp}.parquet"
            write_parquet_to_s3(df, prod_bucket, key)
            written_files.append(key)
        except Exception as e:
            print(f"Error writing {table_name}: {e}")
    
    return written_files


def trigger_glue_crawler(system_name):
    """Trigger Glue Crawler"""
    try:
        crawler_name = f"{system_name}-prod-crawler"
        glue_client.start_crawler(Name=crawler_name)
        print(f"Triggered Glue Crawler: {crawler_name}")
    except glue_client.exceptions.CrawlerRunningException:
        print(f"Crawler {crawler_name} is already running")
    except glue_client.exceptions.EntityNotFoundException:
        print(f"Crawler {crawler_name} not found")
    except Exception as e:
        print(f"Failed to trigger crawler: {e}")
