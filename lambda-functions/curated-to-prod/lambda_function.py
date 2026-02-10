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
                
                # Copy core ecommerce data to prod bucket
                core_files = copy_core_data_to_prod(system_name, prod_bucket, curated_data)
                print(f"Copied {len(core_files)} core data files")
                
                # Run AI models to generate insights
                analytics = run_ai_models(system_name, curated_data)
                written_files = write_analytics_to_prod(system_name, prod_bucket, analytics)
                print(f"Generated {len(written_files)} AI insight files")
                
                # Trigger Glue Crawler
                trigger_glue_crawler(system_name)
                
                results[system_name] = {
                    'status': 'success',
                    'core_files': len(core_files),
                    'analytics_count': len(analytics),
                    'files_written': len(written_files)
                }
            except Exception as e:
                print(f"Error processing {system_name}: {e}")
                import traceback
                traceback.print_exc()
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


def copy_core_data_to_prod(system_name, prod_bucket, curated_data):
    """Copy core ecommerce data from curated to system-specific prod bucket"""
    written_files = []
    timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
    
    # Define which tables each system needs based on create-all-tables.sql
    system_tables = {
        'market-intelligence-hub': ['orders', 'order_items', 'products', 'categories', 'customers'],
        'demand-insights-engine': ['orders', 'order_items', 'products', 'customers'],
        'compliance-guardian': ['orders', 'payments'],
        'retail-copilot': ['orders', 'order_items', 'products', 'customers', 'inventory'],
        'global-market-pulse': ['orders', 'order_items', 'products']
    }
    
    tables_to_copy = system_tables.get(system_name, [])
    
    for table_name in tables_to_copy:
        if table_name not in curated_data:
            print(f"Table {table_name} not found in curated data")
            continue
        
        df = curated_data[table_name]
        if df.empty:
            print(f"Table {table_name} is empty")
            continue
        
        try:
            # Write to ecommerce/{table}/ to match Athena table LOCATION
            key = f"ecommerce/{table_name}/{table_name}_{timestamp}.parquet"
            write_parquet_to_s3(df, prod_bucket, key)
            written_files.append(key)
            print(f"Copied {table_name}: {len(df)} records")
        except Exception as e:
            print(f"Error copying {table_name}: {e}")
    
    return written_files


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
    
    # Competitive Pricing
    if 'products' in data:
        pricing = generate_competitive_pricing(data['products'])
        analytics['competitive_pricing'] = pricing
    
    return analytics


def run_demand_insights_models(data):
    """Demand Insights Engine: Customer analytics"""
    analytics = {}
    
    # Customer Segmentation
    if 'customers' in data and 'orders' in data:
        segments = segment_customers(data['customers'], data['orders'])
        analytics['customer_segments'] = segments
    
    # Demand Forecasting
    if 'orders' in data and 'order_items' in data:
        forecasts = generate_demand_forecasts(data['orders'], data['order_items'])
        analytics['demand_forecasts'] = forecasts
    
    # Price Elasticity
    if 'products' in data and 'order_items' in data:
        elasticity = calculate_price_elasticity(data['products'], data['order_items'])
        analytics['price_elasticity'] = elasticity
    
    return analytics


def run_compliance_models(data):
    """Compliance Guardian: Risk and fraud detection"""
    analytics = {}
    
    # High Risk Transactions
    if 'orders' in data and 'payments' in data:
        high_risk = detect_high_risk_transactions(data['orders'], data['payments'])
        analytics['high_risk_transactions'] = high_risk
    
    # Fraud Statistics
    if 'orders' in data and 'payments' in data:
        stats = calculate_fraud_statistics(data['orders'], data['payments'])
        analytics['fraud_statistics'] = stats
    
    return analytics


def run_market_pulse_models(data):
    """Global Market Pulse: Market opportunities"""
    analytics = {}
    
    # Market Trends by Region
    if 'orders' in data:
        trends = analyze_regional_market_trends(data['orders'])
        analytics['market_trends'] = trends
    
    # Regional Prices
    if 'products' in data and 'orders' in data:
        prices = calculate_regional_prices(data['products'], data['orders'])
        analytics['regional_prices'] = prices
    
    # Market Opportunities
    if 'products' in data and 'orders' in data:
        opportunities = identify_market_opportunities(data['products'], data['orders'])
        analytics['market_opportunities'] = opportunities
    
    return analytics


def run_copilot_models(data):
    """Retail Copilot: Inventory and sales insights"""
    analytics = {}
    
    # Inventory Insights
    if 'products' in data and 'inventory' in data:
        insights = generate_inventory_insights(data['products'], data['inventory'])
        analytics['inventory_insights'] = insights
    
    # Sales Reports
    if 'orders' in data and 'order_items' in data:
        reports = generate_sales_reports(data['orders'], data['order_items'])
        analytics['sales_reports'] = reports
    
    return analytics


# AI Model Implementations (Simplified MVP versions)

def generate_sales_forecasts(orders_df, order_items_df):
    """Generate sales forecasts"""
    merged = orders_df.merge(order_items_df, on='order_id', how='inner')
    merged['order_date'] = pd.to_datetime(merged['order_date'])
    
    daily_sales = merged.groupby(merged['order_date'].dt.date).agg({
        'total_amount': 'sum'
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
        'total_amount': 'sum'
    }).reset_index()
    
    trends = []
    if len(monthly_sales) > 1:
        growth_rate = ((monthly_sales['total_amount'].iloc[-1] - monthly_sales['total_amount'].iloc[-2]) / 
                      monthly_sales['total_amount'].iloc[-2] * 100)
        
        trends.append({
            'trend_date': str(datetime.now().date()),
            'trend_type': 'sales_growth',
            'metric_name': 'monthly_sales',
            'metric_value': float(monthly_sales['total_amount'].iloc[-1]),
            'growth_rate': float(growth_rate),
            'trend_direction': 'up' if growth_rate > 0 else 'down'
        })
    
    return pd.DataFrame(trends)


def generate_competitive_pricing(products_df):
    """Generate competitive pricing data (simulated)"""
    pricing = []
    for _, product in products_df.head(10).iterrows():
        our_price = float(product['price'])
        competitor_price = our_price * (0.9 + 0.2 * pd.np.random.random())
        pricing.append({
            'product_id': product['product_id'],
            'product_name': product['name'],
            'our_price': our_price,
            'competitor_name': 'Competitor A',
            'competitor_price': competitor_price,
            'price_difference': competitor_price - our_price,
            'price_difference_pct': ((competitor_price - our_price) / our_price * 100),
            'last_updated': str(datetime.now())
        })
    return pd.DataFrame(pricing)


def segment_customers(customers_df, orders_df):
    """Segment customers"""
    customer_metrics = orders_df.groupby('customer_id').agg({
        'order_id': 'count',
        'total_amount': 'sum'
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
    segments['avg_clv'] = segments['avg_spending'] * 1.5
    segments['characteristics'] = segments['segment_name'].apply(
        lambda x: f'{x.capitalize()} tier customers'
    )
    segments['created_at'] = str(datetime.now())
    
    return segments


def generate_demand_forecasts(orders_df, order_items_df):
    """Generate demand forecasts"""
    merged = orders_df.merge(order_items_df, on='order_id', how='inner')
    merged['order_date'] = pd.to_datetime(merged['order_date'])
    
    product_demand = merged.groupby(['product_id', merged['order_date'].dt.date]).agg({
        'quantity': 'sum'
    }).reset_index()
    
    forecasts = []
    for product_id in product_demand['product_id'].unique()[:10]:
        product_data = product_demand[product_demand['product_id'] == product_id]
        avg_demand = product_data['quantity'].mean()
        
        for i in range(1, 31):
            forecast_date = product_data['order_date'].max() + timedelta(days=i)
            forecasts.append({
                'date': str(forecast_date),
                'product_id': product_id,
                'forecast_demand': float(avg_demand),
                'lower_bound': float(avg_demand * 0.8),
                'upper_bound': float(avg_demand * 1.2),
                'confidence': 0.85,
                'generated_at': str(datetime.now())
            })
    
    return pd.DataFrame(forecasts)


def calculate_price_elasticity(products_df, order_items_df):
    """Calculate price elasticity"""
    elasticity = []
    for _, product in products_df.head(10).iterrows():
        current_price = float(product['price'])
        # Simulated elasticity
        elasticity_value = -1.5 + pd.np.random.random()
        optimal_price = current_price * 1.1
        
        elasticity.append({
            'product_id': product['product_id'],
            'product_name': product['name'],
            'elasticity': elasticity_value,
            'optimal_price': optimal_price,
            'current_price': current_price,
            'calculated_at': str(datetime.now())
        })
    
    return pd.DataFrame(elasticity)


def detect_high_risk_transactions(orders_df, payments_df):
    """Detect high risk transactions"""
    merged = orders_df.merge(payments_df, on='order_id', how='inner')
    
    merged['risk_score'] = 0.0
    merged.loc[merged['total_amount'] > 1000, 'risk_score'] += 0.3
    merged.loc[merged['payment_status'] == 'failed', 'risk_score'] += 0.5
    
    high_risk = merged[merged['risk_score'] > 0.3].copy()
    high_risk['risk_factors'] = high_risk.apply(
        lambda x: 'High amount' if x['total_amount'] > 1000 else 'Payment failed',
        axis=1
    )
    high_risk['timestamp'] = high_risk['created_at'].astype(str)
    high_risk['flagged_at'] = str(datetime.now())
    
    return high_risk[['order_id', 'customer_id', 'total_amount', 'risk_score', 'risk_factors', 'timestamp', 'flagged_at']].head(100).rename(columns={'order_id': 'transaction_id', 'total_amount': 'amount'})


def calculate_fraud_statistics(orders_df, payments_df):
    """Calculate fraud statistics"""
    merged = orders_df.merge(payments_df, on='order_id', how='inner')
    
    total_transactions = len(merged)
    fraud_detected = len(merged[merged['payment_status'] == 'failed'])
    fraud_rate = fraud_detected / total_transactions if total_transactions > 0 else 0
    total_loss_prevented = merged[merged['payment_status'] == 'failed']['total_amount'].sum()
    
    stats = [{
        'period': 'last_30_days',
        'total_transactions': total_transactions,
        'fraud_detected': fraud_detected,
        'fraud_rate': fraud_rate,
        'total_loss_prevented': float(total_loss_prevented),
        'calculated_at': str(datetime.now())
    }]
    
    return pd.DataFrame(stats)


def generate_inventory_insights(products_df, inventory_df):
    """Generate inventory insights"""
    merged = products_df.merge(inventory_df, on='product_id', how='inner')
    
    insights = []
    for _, row in merged.head(20).iterrows():
        stock_level = int(row['quantity_available'])
        reorder_point = 50
        
        if stock_level < reorder_point:
            status = 'Low Stock'
            recommendation = 'Reorder immediately'
        elif stock_level < reorder_point * 2:
            status = 'Medium Stock'
            recommendation = 'Monitor closely'
        else:
            status = 'Good Stock'
            recommendation = 'No action needed'
        
        insights.append({
            'product_id': row['product_id'],
            'product_name': row['name'],
            'stock_level': stock_level,
            'reorder_point': reorder_point,
            'status': status,
            'recommendation': recommendation,
            'last_updated': str(datetime.now())
        })
    
    return pd.DataFrame(insights)


def generate_sales_reports(orders_df, order_items_df):
    """Generate sales reports"""
    merged = orders_df.merge(order_items_df, on='order_id', how='inner')
    
    total_sales = merged['total_amount'].sum()
    total_orders = len(orders_df)
    avg_order_value = total_sales / total_orders if total_orders > 0 else 0
    
    top_products = merged.groupby('product_id')['quantity'].sum().nlargest(5).index.tolist()
    
    report = [{
        'period': 'last_30_days',
        'total_sales': float(total_sales),
        'total_orders': total_orders,
        'avg_order_value': float(avg_order_value),
        'top_products': ','.join(top_products),
        'generated_at': str(datetime.now())
    }]
    
    return pd.DataFrame(report)


def analyze_regional_market_trends(orders_df):
    """Analyze regional market trends"""
    regional_sales = orders_df.groupby('shipping_country').agg({
        'total_amount': 'sum',
        'order_id': 'count'
    }).reset_index()
    
    trends = []
    for _, row in regional_sales.head(10).iterrows():
        trend_score = float(row['total_amount'] / regional_sales['total_amount'].max() * 100)
        growth_rate = 5.0 + pd.np.random.random() * 10
        
        trends.append({
            'region': row['shipping_country'],
            'trend_score': trend_score,
            'growth_rate': growth_rate,
            'market_size': float(row['total_amount']),
            'trend_direction': 'up' if growth_rate > 7 else 'stable',
            'calculated_at': str(datetime.now())
        })
    
    return pd.DataFrame(trends)


def calculate_regional_prices(products_df, orders_df):
    """Calculate regional prices"""
    prices = []
    regions = orders_df['shipping_country'].unique()[:5]
    
    for _, product in products_df.head(10).iterrows():
        for region in regions:
            avg_price = float(product['price']) * (0.9 + 0.2 * pd.np.random.random())
            
            prices.append({
                'region': region,
                'product_id': product['product_id'],
                'product_name': product['name'],
                'avg_price': avg_price,
                'currency': 'USD',
                'price_trend': 'stable',
                'last_updated': str(datetime.now())
            })
    
    return pd.DataFrame(prices)


def identify_market_opportunities(products_df, orders_df):
    """Identify market opportunities"""
    opportunities = []
    regions = orders_df['shipping_country'].unique()[:5]
    categories = ['electronics', 'clothing', 'home', 'sports', 'books']
    
    for region in regions:
        for category in categories[:3]:
            opportunity_score = 60 + pd.np.random.random() * 40
            
            opportunities.append({
                'region': region,
                'product_category': category,
                'opportunity_score': opportunity_score,
                'estimated_revenue': float(10000 + pd.np.random.random() * 50000),
                'recommendation': 'Expand product line' if opportunity_score > 80 else 'Monitor market',
                'confidence': 0.75,
                'identified_at': str(datetime.now())
            })
    
    return pd.DataFrame(opportunities)


def write_analytics_to_prod(system_name, prod_bucket, analytics):
    """Write analytics to prod bucket"""
    written_files = []
    timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
    
    for table_name, df in analytics.items():
        if df.empty:
            continue
        
        try:
            # Write to ecommerce/ prefix to match Athena table locations
            key = f"ecommerce/{table_name}/{table_name}_{timestamp}.parquet"
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
