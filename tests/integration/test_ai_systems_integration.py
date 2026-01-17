"""
Integration Tests for All AI Systems
Tests end-to-end functionality of all 5 AI systems
Validates: Requirements 15.1-15.9, 16.1-16.8, 17.1-17.8, 18.1-18.8, 19.1-19.8
"""

import pytest
import requests
import json
from typing import Dict, Any
import time

# Configuration
API_BASE_URL = "https://api.example.com"  # Replace with actual API URL
JWT_TOKEN = None  # Will be set during authentication


class TestAISystemsIntegration:
    """Integration tests for all AI systems"""
    
    @pytest.fixture(scope="class", autouse=True)
    def authenticate(self):
        """Authenticate and get JWT token"""
        global JWT_TOKEN
        
        response = requests.post(
            f"{API_BASE_URL}/auth/login",
            json={
                "email": "test@example.com",
                "password": "TestPassword123!"
            }
        )
        
        assert response.status_code == 200, "Authentication failed"
        JWT_TOKEN = response.json()['token']
    
    def _make_request(self, method: str, endpoint: str, data: Dict[str, Any] = None) -> requests.Response:
        """Helper: Make authenticated API request"""
        headers = {
            "Authorization": f"Bearer {JWT_TOKEN}",
            "Content-Type": "application/json"
        }
        
        url = f"{API_BASE_URL}{endpoint}"
        
        if method == "GET":
            return requests.get(url, headers=headers, params=data)
        elif method == "POST":
            return requests.post(url, headers=headers, json=data)
        else:
            raise ValueError(f"Unsupported method: {method}")
    
    # ===== Market Intelligence Hub Tests =====
    
    def test_market_intelligence_forecast(self):
        """Test: Market Intelligence Hub - Generate forecast"""
        response = self._make_request("POST", "/market-intelligence/forecast", {
            "product_id": "PROD001",
            "periods": 30,
            "model": "auto"
        })
        
        assert response.status_code == 200, f"Forecast failed: {response.text}"
        
        data = response.json()
        assert 'forecast' in data, "Forecast data missing"
        assert 'confidence_intervals' in data, "Confidence intervals missing"
        assert 'model_used' in data, "Model information missing"
        assert 'metrics' in data, "Metrics missing"
        
        # Validate forecast structure
        assert len(data['forecast']) == 30, "Incorrect forecast length"
        assert all(isinstance(v, (int, float)) for v in data['forecast']), "Invalid forecast values"
        
        # Validate metrics
        metrics = data['metrics']
        assert 'rmse' in metrics, "RMSE missing"
        assert 'mae' in metrics, "MAE missing"
        assert 'mape' in metrics, "MAPE missing"
    
    def test_market_intelligence_trends(self):
        """Test: Market Intelligence Hub - Analyze trends"""
        response = self._make_request("GET", "/market-intelligence/trends", {
            "category": "Electronics",
            "days": 90
        })
        
        assert response.status_code == 200, f"Trends analysis failed: {response.text}"
        
        data = response.json()
        assert 'trends' in data, "Trends data missing"
        assert 'seasonality' in data, "Seasonality data missing"
        assert 'growth_rate' in data, "Growth rate missing"
    
    def test_market_intelligence_model_comparison(self):
        """Test: Market Intelligence Hub - Compare models"""
        response = self._make_request("POST", "/market-intelligence/compare", {
            "product_id": "PROD001",
            "periods": 30,
            "models": ["arima", "prophet", "lstm"]
        })
        
        assert response.status_code == 200, f"Model comparison failed: {response.text}"
        
        data = response.json()
        assert 'comparison' in data, "Comparison data missing"
        assert 'best_model' in data, "Best model not identified"
        assert 'metrics_by_model' in data, "Model metrics missing"
    
    # ===== Demand Insights Engine Tests =====
    
    def test_demand_insights_segmentation(self):
        """Test: Demand Insights Engine - Customer segmentation"""
        response = self._make_request("GET", "/demand-insights/segments", {
            "n_clusters": 4
        })
        
        assert response.status_code == 200, f"Segmentation failed: {response.text}"
        
        data = response.json()
        assert 'segments' in data, "Segments data missing"
        assert 'cluster_centers' in data, "Cluster centers missing"
        assert 'segment_sizes' in data, "Segment sizes missing"
        
        # Validate segments
        assert len(data['segments']) == 4, "Incorrect number of segments"
    
    def test_demand_insights_clv_prediction(self):
        """Test: Demand Insights Engine - CLV prediction"""
        response = self._make_request("POST", "/demand-insights/clv", {
            "customer_ids": ["CUST001", "CUST002", "CUST003"]
        })
        
        assert response.status_code == 200, f"CLV prediction failed: {response.text}"
        
        data = response.json()
        assert 'clv_predictions' in data, "CLV predictions missing"
        assert 'confidence_scores' in data, "Confidence scores missing"
        
        # Validate predictions
        assert len(data['clv_predictions']) == 3, "Incorrect number of predictions"
        assert all(v > 0 for v in data['clv_predictions'].values()), "Invalid CLV values"
    
    def test_demand_insights_churn_prediction(self):
        """Test: Demand Insights Engine - Churn prediction"""
        response = self._make_request("POST", "/demand-insights/churn", {
            "customer_ids": ["CUST001", "CUST002"]
        })
        
        assert response.status_code == 200, f"Churn prediction failed: {response.text}"
        
        data = response.json()
        assert 'churn_predictions' in data, "Churn predictions missing"
        assert 'churn_probability' in data, "Churn probabilities missing"
        
        # Validate probabilities
        for prob in data['churn_probability'].values():
            assert 0 <= prob <= 1, f"Invalid probability: {prob}"
    
    def test_demand_insights_price_elasticity(self):
        """Test: Demand Insights Engine - Price elasticity"""
        response = self._make_request("POST", "/demand-insights/elasticity", {
            "product_id": "PROD001",
            "price_range": {"min": 50, "max": 150}
        })
        
        assert response.status_code == 200, f"Price elasticity failed: {response.text}"
        
        data = response.json()
        assert 'elasticity_coefficient' in data, "Elasticity coefficient missing"
        assert 'demand_curve' in data, "Demand curve missing"
        assert 'revenue_impact' in data, "Revenue impact missing"
    
    # ===== Compliance Guardian Tests =====
    
    def test_compliance_fraud_detection(self):
        """Test: Compliance Guardian - Fraud detection"""
        response = self._make_request("POST", "/compliance/fraud-detection", {
            "transaction_ids": ["TXN001", "TXN002", "TXN003"]
        })
        
        assert response.status_code == 200, f"Fraud detection failed: {response.text}"
        
        data = response.json()
        assert 'fraud_scores' in data, "Fraud scores missing"
        assert 'anomaly_flags' in data, "Anomaly flags missing"
        
        # Validate scores
        for score in data['fraud_scores'].values():
            assert -1 <= score <= 1, f"Invalid fraud score: {score}"
    
    def test_compliance_risk_scoring(self):
        """Test: Compliance Guardian - Risk scoring"""
        response = self._make_request("POST", "/compliance/risk-score", {
            "transaction_ids": ["TXN001", "TXN002"]
        })
        
        assert response.status_code == 200, f"Risk scoring failed: {response.text}"
        
        data = response.json()
        assert 'risk_scores' in data, "Risk scores missing"
        assert 'risk_category' in data, "Risk categories missing"
        
        # Validate scores
        for score in data['risk_scores'].values():
            assert 0 <= score <= 100, f"Invalid risk score: {score}"
    
    def test_compliance_pci_compliance(self):
        """Test: Compliance Guardian - PCI compliance check"""
        response = self._make_request("POST", "/compliance/pci-compliance", {
            "payment_ids": ["PAY001", "PAY002"]
        })
        
        assert response.status_code == 200, f"PCI compliance check failed: {response.text}"
        
        data = response.json()
        assert 'compliance_status' in data, "Compliance status missing"
        assert 'violations' in data, "Violations data missing"
        assert 'masked_data' in data, "Masked data missing"
        
        # Validate credit card masking
        for masked in data['masked_data'].values():
            if 'card_number' in masked:
                assert '****' in masked['card_number'], "Credit card not properly masked"
    
    def test_compliance_high_risk_transactions(self):
        """Test: Compliance Guardian - High-risk transactions"""
        response = self._make_request("GET", "/compliance/high-risk-transactions", {
            "threshold": 70,
            "limit": 50
        })
        
        assert response.status_code == 200, f"High-risk query failed: {response.text}"
        
        data = response.json()
        assert 'transactions' in data, "Transactions data missing"
        assert 'count' in data, "Count missing"
        
        # Validate all transactions meet threshold
        for txn in data['transactions']:
            assert txn['risk_score'] >= 70, f"Transaction below threshold: {txn['risk_score']}"
    
    # ===== Retail Copilot Tests =====
    
    def test_retail_copilot_chat(self):
        """Test: Retail Copilot - Chat interaction"""
        response = self._make_request("POST", "/retail-copilot/chat", {
            "user_id": "USER001",
            "message": "What are the top 5 selling products this month?"
        })
        
        assert response.status_code == 200, f"Chat failed: {response.text}"
        
        data = response.json()
        assert 'response' in data, "Response missing"
        assert 'conversation_id' in data, "Conversation ID missing"
        assert 'query_type' in data, "Query type missing"
        
        # Validate response is not empty
        assert len(data['response']) > 0, "Empty response"
    
    def test_retail_copilot_inventory_query(self):
        """Test: Retail Copilot - Inventory query"""
        response = self._make_request("POST", "/retail-copilot/inventory", {
            "user_id": "USER001",
            "question": "Show me products with low stock levels"
        })
        
        assert response.status_code == 200, f"Inventory query failed: {response.text}"
        
        data = response.json()
        assert 'answer' in data, "Answer missing"
        assert 'data' in data, "Data missing"
        assert 'sql_query' in data, "SQL query missing"
    
    def test_retail_copilot_recommendations(self):
        """Test: Retail Copilot - Product recommendations"""
        response = self._make_request("POST", "/retail-copilot/recommendations", {
            "customer_id": "CUST001",
            "limit": 5
        })
        
        assert response.status_code == 200, f"Recommendations failed: {response.text}"
        
        data = response.json()
        assert 'recommendations' in data, "Recommendations missing"
        assert 'reasoning' in data, "Reasoning missing"
        
        # Validate recommendations
        assert len(data['recommendations']) <= 5, "Too many recommendations"
    
    # ===== Global Market Pulse Tests =====
    
    def test_global_market_trends(self):
        """Test: Global Market Pulse - Market trends"""
        response = self._make_request("GET", "/global-market/trends", {
            "product_id": "PROD001",
            "days": 180
        })
        
        assert response.status_code == 200, f"Trends analysis failed: {response.text}"
        
        data = response.json()
        assert 'trend' in data, "Trend data missing"
        assert 'seasonal' in data, "Seasonal data missing"
        assert 'statistics' in data, "Statistics missing"
    
    def test_global_market_price_comparison(self):
        """Test: Global Market Pulse - Price comparison"""
        response = self._make_request("POST", "/global-market/price-comparison", {
            "product_id": "PROD001",
            "regions": ["North America", "Europe", "Asia"]
        })
        
        assert response.status_code == 200, f"Price comparison failed: {response.text}"
        
        data = response.json()
        assert 'comparisons' in data, "Comparisons missing"
        assert 'statistical_tests' in data, "Statistical tests missing"
        
        # Validate statistical tests
        for test in data['statistical_tests']:
            assert 'p_value' in test, "P-value missing"
            assert 'effect_size' in test, "Effect size missing"
    
    def test_global_market_opportunities(self):
        """Test: Global Market Pulse - Market opportunities"""
        response = self._make_request("POST", "/global-market/opportunities", {
            "regions": ["North America", "Europe", "Asia", "Latin America"],
            "weights": {
                "market_size": 0.25,
                "growth_rate": 0.25,
                "competition": 0.20,
                "price_premium": 0.15,
                "maturity": 0.15
            }
        })
        
        assert response.status_code == 200, f"Opportunity scoring failed: {response.text}"
        
        data = response.json()
        assert 'opportunities' in data, "Opportunities missing"
        assert 'scores' in data, "Scores missing"
        assert 'rankings' in data, "Rankings missing"
        
        # Validate scores
        for score in data['scores'].values():
            assert 0 <= score <= 100, f"Invalid opportunity score: {score}"
    
    def test_global_market_competitor_analysis(self):
        """Test: Global Market Pulse - Competitor analysis"""
        response = self._make_request("POST", "/global-market/competitor-analysis", {
            "region": "North America",
            "category": "Electronics"
        })
        
        assert response.status_code == 200, f"Competitor analysis failed: {response.text}"
        
        data = response.json()
        assert 'competitors' in data, "Competitors data missing"
        assert 'market_share' in data, "Market share missing"
        assert 'hhi' in data, "HHI missing"
        
        # Validate HHI
        assert 0 <= data['hhi'] <= 10000, f"Invalid HHI: {data['hhi']}"
    
    # ===== Cross-System Integration Tests =====
    
    def test_cross_system_data_flow(self):
        """Test: Data flows correctly between systems"""
        # Get customer segments from Demand Insights
        segments_response = self._make_request("GET", "/demand-insights/segments", {"n_clusters": 4})
        assert segments_response.status_code == 200
        
        # Use segment data for targeted recommendations in Retail Copilot
        copilot_response = self._make_request("POST", "/retail-copilot/recommendations", {
            "customer_id": "CUST001",
            "limit": 5
        })
        assert copilot_response.status_code == 200
        
        # Verify recommendations are personalized
        recommendations = copilot_response.json()['recommendations']
        assert len(recommendations) > 0, "No recommendations generated"
    
    def test_cross_system_consistency(self):
        """Test: Data consistency across systems"""
        # Get product forecast from Market Intelligence
        forecast_response = self._make_request("POST", "/market-intelligence/forecast", {
            "product_id": "PROD001",
            "periods": 30,
            "model": "auto"
        })
        assert forecast_response.status_code == 200
        
        # Get demand forecast from Demand Insights
        demand_response = self._make_request("POST", "/demand-insights/forecast", {
            "product_id": "PROD001",
            "periods": 30
        })
        assert demand_response.status_code == 200
        
        # Both forecasts should be reasonable and not wildly different
        forecast1 = forecast_response.json()['forecast']
        forecast2 = demand_response.json()['forecast']
        
        # Calculate correlation (should be positive)
        import numpy as np
        correlation = np.corrcoef(forecast1, forecast2)[0, 1]
        assert correlation > 0, f"Forecasts are negatively correlated: {correlation}"


if __name__ == "__main__":
    pytest.main([__file__, "-v", "--tb=short"])
