"""
AWS Lambda Handler for Compliance Guardian

Provides REST API endpoints for fraud detection, risk scoring, and PCI DSS compliance.
"""

import json
import logging
import os
from typing import Dict, Any
import pandas as pd

from fraud.fraud_detector import FraudDetector
from risk.risk_scorer import RiskScorer
from compliance.pci_compliance import PCIComplianceChecker
from data.athena_client import AthenaClient

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Initialize components
athena_client = AthenaClient(
    database=os.environ.get('ATHENA_DATABASE', 'compliance_db'),
    output_location=os.environ.get('ATHENA_OUTPUT_LOCATION'),
    region=os.environ.get('AWS_REGION', 'us-east-1'),
    workgroup=os.environ.get('ATHENA_WORKGROUP', 'primary')
)

# Global model instances (reused across invocations)
fraud_detector = None
risk_scorer = None
pci_checker = PCIComplianceChecker()


def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """
    Main Lambda handler for Compliance Guardian.
    
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
        if path == '/compliance/fraud-detection' and method == 'POST':
            return handle_fraud_detection(body)
        
        elif path == '/compliance/risk-score' and method == 'POST':
            return handle_risk_scoring(body)
        
        elif path == '/compliance/high-risk-transactions' and method == 'GET':
            return handle_high_risk_transactions(query_params)
        
        elif path == '/compliance/pci-compliance' and method == 'POST':
            return handle_pci_compliance(body)
        
        elif path == '/compliance/compliance-report' and method == 'GET':
            return handle_compliance_report(query_params)
        
        elif path == '/compliance/fraud-statistics' and method == 'GET':
            return handle_fraud_statistics(query_params)
        
        else:
            return create_response(404, {'error': 'Endpoint not found'})
    
    except Exception as e:
        logger.error(f"Error processing request: {str(e)}", exc_info=True)
        return create_response(500, {'error': str(e)})


def handle_fraud_detection(body: Dict) -> Dict:
    """
    Handle fraud detection request.
    
    POST /compliance/fraud-detection
    Body: {
        "transaction_ids": ["optional", "list"],
        "days": 7
    }
    """
    try:
        global fraud_detector
        
        # Get parameters
        transaction_ids = body.get('transaction_ids')
        days = body.get('days', 7)
        
        # Fetch transaction data
        logger.info("Fetching transaction data from Athena...")
        if transaction_ids:
            # Fetch specific transactions
            transaction_data = athena_client.get_transaction_data(limit=len(transaction_ids))
        else:
            # Fetch recent transactions
            transaction_data = athena_client.get_high_risk_transactions(days=days)
        
        if transaction_data.empty:
            return create_response(404, {'error': 'No transaction data found'})
        
        # Convert columns to appropriate types
        numeric_cols = ['amount', 'customer_age_days', 'previous_transactions', 
                       'avg_transaction_amount', 'transactions_last_hour', 
                       'transactions_last_day', 'failed_attempts_last_day']
        for col in numeric_cols:
            if col in transaction_data.columns:
                transaction_data[col] = pd.to_numeric(transaction_data[col], errors='coerce')
        
        transaction_data = transaction_data.fillna(0)
        
        # Initialize fraud detector if needed
        if fraud_detector is None:
            fraud_detector = FraudDetector()
            # Train with current data (in production, load pre-trained model)
            logger.info("Training fraud detection model...")
            fraud_detector.train(transaction_data)
        
        # Detect fraud
        logger.info("Detecting fraudulent transactions...")
        predictions = fraud_detector.predict(transaction_data)
        
        # Identify high-risk transactions
        fraudulent = fraud_detector.identify_fraudulent_transactions(predictions, threshold=0.7)
        
        # Analyze patterns
        patterns = fraud_detector.analyze_fraud_patterns(predictions)
        
        return create_response(200, {
            'predictions': predictions[['transaction_id', 'fraud_probability', 
                                       'fraud_risk_level', 'is_anomaly']].to_dict('records'),
            'fraudulent_transactions': fraudulent[['transaction_id', 'fraud_probability', 
                                                   'amount']].head(50).to_dict('records'),
            'patterns': patterns
        })
    
    except Exception as e:
        logger.error(f"Error in fraud detection: {str(e)}")
        return create_response(500, {'error': str(e)})


def handle_risk_scoring(body: Dict) -> Dict:
    """
    Handle risk scoring request.
    
    POST /compliance/risk-score
    Body: {
        "transaction_ids": ["optional", "list"],
        "days": 7
    }
    """
    try:
        global risk_scorer
        
        # Get parameters
        transaction_ids = body.get('transaction_ids')
        days = body.get('days', 7)
        
        # Fetch transaction data
        logger.info("Fetching transaction data from Athena...")
        if transaction_ids:
            transaction_data = athena_client.get_transaction_data(limit=len(transaction_ids))
        else:
            transaction_data = athena_client.get_high_risk_transactions(days=days)
        
        if transaction_data.empty:
            return create_response(404, {'error': 'No transaction data found'})
        
        # Convert columns
        numeric_cols = ['amount', 'customer_age_days', 'previous_transactions', 
                       'avg_transaction_amount', 'transactions_last_hour', 
                       'transactions_last_day', 'failed_attempts_last_day']
        for col in numeric_cols:
            if col in transaction_data.columns:
                transaction_data[col] = pd.to_numeric(transaction_data[col], errors='coerce')
        
        transaction_data = transaction_data.fillna(0)
        
        # Initialize risk scorer if needed
        if risk_scorer is None:
            risk_scorer = RiskScorer()
        
        # Calculate risk scores
        logger.info("Calculating risk scores...")
        scored = risk_scorer.calculate_risk_score(transaction_data)
        
        # Flag high-risk transactions
        high_risk = risk_scorer.flag_high_risk_transactions(scored, threshold=70)
        
        # Analyze risk distribution
        distribution = risk_scorer.analyze_risk_distribution(scored)
        
        return create_response(200, {
            'risk_scores': scored[['transaction_id', 'risk_score', 'risk_level', 
                                  'is_high_risk']].to_dict('records'),
            'high_risk_transactions': high_risk[['transaction_id', 'risk_score', 
                                                'amount']].head(50).to_dict('records'),
            'distribution': distribution
        })
    
    except Exception as e:
        logger.error(f"Error in risk scoring: {str(e)}")
        return create_response(500, {'error': str(e)})


def handle_high_risk_transactions(params: Dict) -> Dict:
    """
    Handle high-risk transactions request.
    
    GET /compliance/high-risk-transactions?days=7&threshold=70&limit=100
    """
    try:
        # Get parameters
        days = int(params.get('days', 7))
        threshold = int(params.get('threshold', 70))
        limit = int(params.get('limit', 100))
        
        # Fetch transaction data
        logger.info("Fetching high-risk transactions from Athena...")
        transaction_data = athena_client.get_high_risk_transactions(days=days)
        
        if transaction_data.empty:
            return create_response(404, {'error': 'No transaction data found'})
        
        # Convert columns
        numeric_cols = ['amount', 'customer_age_days', 'previous_transactions']
        for col in numeric_cols:
            if col in transaction_data.columns:
                transaction_data[col] = pd.to_numeric(transaction_data[col], errors='coerce')
        
        transaction_data = transaction_data.fillna(0)
        
        # Calculate risk scores
        if risk_scorer is None:
            global risk_scorer
            risk_scorer = RiskScorer()
        
        scored = risk_scorer.calculate_risk_score(transaction_data)
        
        # Filter high-risk transactions
        high_risk = scored[scored['risk_score'] >= threshold]
        high_risk = high_risk.sort_values('risk_score', ascending=False).head(limit)
        
        return create_response(200, {
            'high_risk_transactions': high_risk[['transaction_id', 'customer_id', 
                                                'amount', 'risk_score', 'risk_level']].to_dict('records'),
            'count': len(high_risk),
            'threshold': threshold
        })
    
    except Exception as e:
        logger.error(f"Error fetching high-risk transactions: {str(e)}")
        return create_response(500, {'error': str(e)})


def handle_pci_compliance(body: Dict) -> Dict:
    """
    Handle PCI DSS compliance check request.
    
    POST /compliance/pci-compliance
    Body: {
        "transaction_ids": ["optional", "list"]
    }
    """
    try:
        # Get parameters
        transaction_ids = body.get('transaction_ids')
        
        # Fetch payment data
        logger.info("Fetching payment data from Athena...")
        payment_data = athena_client.get_payment_data(transaction_ids=transaction_ids)
        
        if payment_data.empty:
            return create_response(404, {'error': 'No payment data found'})
        
        # Check PCI DSS compliance
        logger.info("Checking PCI DSS compliance...")
        compliance_report = pci_checker.generate_compliance_report(payment_data)
        
        # Sanitize data for response
        sanitized_data = pci_checker.sanitize_payment_data(payment_data)
        
        return create_response(200, {
            'compliance_report': compliance_report,
            'sample_data': sanitized_data.head(10).to_dict('records')
        })
    
    except Exception as e:
        logger.error(f"Error checking PCI compliance: {str(e)}")
        return create_response(500, {'error': str(e)})


def handle_compliance_report(params: Dict) -> Dict:
    """
    Handle comprehensive compliance report request.
    
    GET /compliance/compliance-report?days=30
    """
    try:
        # Get parameters
        days = int(params.get('days', 30))
        
        # Fetch data
        logger.info("Generating comprehensive compliance report...")
        transaction_data = athena_client.get_transaction_data(limit=1000)
        payment_data = athena_client.get_payment_data()
        access_logs = athena_client.get_access_logs(days=days)
        
        # PCI DSS compliance
        pci_report = pci_checker.generate_compliance_report(
            payment_data,
            access_logs if not access_logs.empty else None
        )
        
        # Fraud statistics
        if not transaction_data.empty:
            numeric_cols = ['amount', 'customer_age_days', 'previous_transactions']
            for col in numeric_cols:
                if col in transaction_data.columns:
                    transaction_data[col] = pd.to_numeric(transaction_data[col], errors='coerce')
            transaction_data = transaction_data.fillna(0)
            
            # Initialize fraud detector if needed
            global fraud_detector
            if fraud_detector is None:
                fraud_detector = FraudDetector()
                fraud_detector.train(transaction_data)
            
            predictions = fraud_detector.predict(transaction_data)
            fraud_patterns = fraud_detector.analyze_fraud_patterns(predictions)
        else:
            fraud_patterns = {'error': 'No transaction data available'}
        
        # Risk distribution
        if not transaction_data.empty:
            global risk_scorer
            if risk_scorer is None:
                risk_scorer = RiskScorer()
            
            scored = risk_scorer.calculate_risk_score(transaction_data)
            risk_distribution = risk_scorer.analyze_risk_distribution(scored)
        else:
            risk_distribution = {'error': 'No transaction data available'}
        
        return create_response(200, {
            'pci_compliance': pci_report,
            'fraud_analysis': fraud_patterns,
            'risk_analysis': risk_distribution,
            'report_period_days': days
        })
    
    except Exception as e:
        logger.error(f"Error generating compliance report: {str(e)}")
        return create_response(500, {'error': str(e)})


def handle_fraud_statistics(params: Dict) -> Dict:
    """
    Handle fraud statistics request.
    
    GET /compliance/fraud-statistics?days=30
    """
    try:
        # Get parameters
        days = int(params.get('days', 30))
        
        # Fetch fraud statistics
        logger.info("Fetching fraud statistics from Athena...")
        stats = athena_client.get_fraud_statistics(days=days)
        
        if stats.empty:
            return create_response(404, {'error': 'No fraud statistics found'})
        
        # Convert columns
        numeric_cols = ['total_transactions', 'total_amount', 'flagged_transactions', 
                       'flagged_amount', 'avg_risk_score']
        for col in numeric_cols:
            if col in stats.columns:
                stats[col] = pd.to_numeric(stats[col], errors='coerce')
        
        # Calculate summary metrics
        summary = {
            'total_transactions': int(stats['total_transactions'].sum()),
            'total_amount': float(stats['total_amount'].sum()),
            'total_flagged': int(stats['flagged_transactions'].sum()),
            'total_flagged_amount': float(stats['flagged_amount'].sum()),
            'fraud_rate': float(stats['flagged_transactions'].sum() / stats['total_transactions'].sum() * 100),
            'avg_risk_score': float(stats['avg_risk_score'].mean())
        }
        
        return create_response(200, {
            'summary': summary,
            'daily_statistics': stats.to_dict('records')
        })
    
    except Exception as e:
        logger.error(f"Error fetching fraud statistics: {str(e)}")
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
