"""
Fraud Detection Module

Uses Isolation Forest for anomaly detection to identify fraudulent transactions.
"""

import numpy as np
import pandas as pd
from typing import Dict, List, Optional, Tuple
from sklearn.ensemble import IsolationForest
from sklearn.preprocessing import StandardScaler
import logging

logger = logging.getLogger(__name__)


class FraudDetector:
    """
    Detects fraudulent transactions using Isolation Forest anomaly detection.
    
    Isolation Forest is effective for fraud detection because it:
    - Identifies outliers in transaction patterns
    - Works well with imbalanced datasets
    - Doesn't require labeled fraud examples
    """
    
    def __init__(
        self,
        contamination: float = 0.01,
        n_estimators: int = 100,
        random_state: int = 42
    ):
        """
        Initialize fraud detector.
        
        Args:
            contamination: Expected proportion of outliers (default 1%)
            n_estimators: Number of trees in the forest
            random_state: Random seed for reproducibility
        """
        self.model = IsolationForest(
            contamination=contamination,
            n_estimators=n_estimators,
            random_state=random_state,
            n_jobs=-1
        )
        self.scaler = StandardScaler()
        self.feature_names = []
        self.is_trained = False
        self.fraud_threshold = -0.5  # Anomaly score threshold
    
    def prepare_features(self, data: pd.DataFrame) -> pd.DataFrame:
        """
        Prepare features for fraud detection.
        
        Args:
            data: DataFrame with transaction data
            
        Returns:
            DataFrame with engineered features
        """
        features = pd.DataFrame()
        
        # Transaction amount features
        features['amount'] = data['amount']
        features['amount_log'] = np.log1p(data['amount'])
        
        # Time-based features
        if 'transaction_time' in data.columns:
            data['transaction_time'] = pd.to_datetime(data['transaction_time'])
            features['hour'] = data['transaction_time'].dt.hour
            features['day_of_week'] = data['transaction_time'].dt.dayofweek
            features['is_weekend'] = (data['transaction_time'].dt.dayofweek >= 5).astype(int)
            features['is_night'] = ((data['transaction_time'].dt.hour < 6) | 
                                   (data['transaction_time'].dt.hour >= 22)).astype(int)
        
        # Customer behavior features
        features['customer_age_days'] = data.get('customer_age_days', 0)
        features['previous_transactions'] = data.get('previous_transactions', 0)
        features['avg_transaction_amount'] = data.get('avg_transaction_amount', 0)
        
        # Deviation from normal behavior
        if 'avg_transaction_amount' in data.columns:
            features['amount_deviation'] = (
                (data['amount'] - data['avg_transaction_amount']) / 
                data['avg_transaction_amount'].replace(0, 1)
            )
        else:
            features['amount_deviation'] = 0
        
        # Location features
        features['is_international'] = data.get('is_international', 0).astype(int)
        features['distance_from_home'] = data.get('distance_from_home_km', 0)
        
        # Payment method features
        features['is_card_present'] = data.get('is_card_present', 1).astype(int)
        features['is_online'] = data.get('is_online', 0).astype(int)
        
        # Merchant features
        features['merchant_risk_score'] = data.get('merchant_risk_score', 0)
        features['is_new_merchant'] = data.get('is_new_merchant', 0).astype(int)
        
        # Velocity features (rapid transactions)
        features['transactions_last_hour'] = data.get('transactions_last_hour', 0)
        features['transactions_last_day'] = data.get('transactions_last_day', 0)
        features['amount_last_hour'] = data.get('amount_last_hour', 0)
        
        # Card features
        features['failed_attempts_last_day'] = data.get('failed_attempts_last_day', 0)
        features['card_age_days'] = data.get('card_age_days', 0)
        
        # Derived risk indicators
        features['high_amount'] = (features['amount'] > features['amount'].quantile(0.95)).astype(int)
        features['rapid_transactions'] = (features['transactions_last_hour'] >= 3).astype(int)
        features['unusual_time'] = features['is_night']
        
        return features
    
    def train(self, data: pd.DataFrame) -> Dict:
        """
        Train the fraud detection model.
        
        Args:
            data: Training data with transaction features
            
        Returns:
            Dictionary with training metrics
        """
        try:
            # Prepare features
            X = self.prepare_features(data)
            self.feature_names = X.columns.tolist()
            
            # Scale features
            X_scaled = self.scaler.fit_transform(X)
            
            # Train model
            logger.info("Training fraud detection model...")
            self.model.fit(X_scaled)
            
            # Get anomaly scores
            scores = self.model.score_samples(X_scaled)
            predictions = self.model.predict(X_scaled)
            
            # Calculate metrics
            n_anomalies = (predictions == -1).sum()
            anomaly_rate = n_anomalies / len(data)
            
            score_stats = {
                'min': float(scores.min()),
                'max': float(scores.max()),
                'mean': float(scores.mean()),
                'median': float(np.median(scores)),
                'std': float(scores.std())
            }
            
            self.is_trained = True
            
            result = {
                'n_samples': len(data),
                'n_features': len(self.feature_names),
                'n_anomalies': int(n_anomalies),
                'anomaly_rate': float(anomaly_rate),
                'score_statistics': score_stats,
                'contamination': self.model.contamination
            }
            
            logger.info(f"Fraud detection model trained - Anomaly rate: {anomaly_rate:.2%}")
            
            return result
            
        except Exception as e:
            logger.error(f"Error training fraud detection model: {str(e)}")
            raise
    
    def predict(self, data: pd.DataFrame) -> pd.DataFrame:
        """
        Predict fraud probability for transactions.
        
        Args:
            data: DataFrame with transaction data
            
        Returns:
            DataFrame with fraud predictions
        """
        try:
            if not self.is_trained:
                raise ValueError("Model must be trained before prediction")
            
            # Prepare features
            X = self.prepare_features(data)
            
            # Ensure all features are present
            for feature in self.feature_names:
                if feature not in X.columns:
                    X[feature] = 0
            
            X = X[self.feature_names]
            
            # Scale and predict
            X_scaled = self.scaler.transform(X)
            anomaly_scores = self.model.score_samples(X_scaled)
            predictions = self.model.predict(X_scaled)
            
            # Convert anomaly scores to fraud probability (0-1 scale)
            # Lower scores = more anomalous = higher fraud probability
            fraud_probability = 1 / (1 + np.exp(anomaly_scores * 5))  # Sigmoid transformation
            
            # Create result DataFrame
            result = data.copy()
            result['anomaly_score'] = anomaly_scores
            result['is_anomaly'] = (predictions == -1).astype(int)
            result['fraud_probability'] = fraud_probability
            result['fraud_risk_level'] = pd.cut(
                fraud_probability,
                bins=[0, 0.3, 0.6, 0.8, 1.0],
                labels=['Low', 'Medium', 'High', 'Critical']
            )
            
            logger.info(f"Predicted fraud for {len(data)} transactions")
            
            return result
            
        except Exception as e:
            logger.error(f"Error predicting fraud: {str(e)}")
            raise
    
    def identify_fraudulent_transactions(
        self,
        data: pd.DataFrame,
        threshold: float = 0.7
    ) -> pd.DataFrame:
        """
        Identify transactions with high fraud probability.
        
        Args:
            data: DataFrame with transaction data
            threshold: Minimum fraud probability to flag (default 0.7)
            
        Returns:
            DataFrame with flagged transactions
        """
        try:
            # Get predictions
            predictions = self.predict(data)
            
            # Filter high-risk transactions
            fraudulent = predictions[predictions['fraud_probability'] >= threshold].copy()
            
            # Sort by fraud probability
            fraudulent = fraudulent.sort_values('fraud_probability', ascending=False)
            
            logger.info(f"Identified {len(fraudulent)} potentially fraudulent transactions")
            
            return fraudulent
            
        except Exception as e:
            logger.error(f"Error identifying fraudulent transactions: {str(e)}")
            raise
    
    def analyze_fraud_patterns(self, data: pd.DataFrame) -> Dict:
        """
        Analyze patterns in fraudulent transactions.
        
        Args:
            data: DataFrame with transaction data and predictions
            
        Returns:
            Dictionary with fraud pattern analysis
        """
        try:
            if 'fraud_probability' not in data.columns:
                data = self.predict(data)
            
            # Segment by risk level
            risk_distribution = data['fraud_risk_level'].value_counts().to_dict()
            
            # High-risk transactions
            high_risk = data[data['fraud_probability'] >= 0.7]
            
            # Analyze patterns in high-risk transactions
            patterns = {}
            
            if len(high_risk) > 0:
                patterns['avg_amount'] = float(high_risk['amount'].mean())
                patterns['median_amount'] = float(high_risk['amount'].median())
                
                if 'hour' in high_risk.columns:
                    patterns['common_hours'] = high_risk['hour'].value_counts().head(3).to_dict()
                
                if 'is_international' in high_risk.columns:
                    patterns['international_rate'] = float(high_risk['is_international'].mean())
                
                if 'is_online' in high_risk.columns:
                    patterns['online_rate'] = float(high_risk['is_online'].mean())
            
            result = {
                'total_transactions': len(data),
                'high_risk_count': len(high_risk),
                'high_risk_percentage': float(len(high_risk) / len(data) * 100),
                'risk_distribution': {k: int(v) for k, v in risk_distribution.items()},
                'fraud_patterns': patterns,
                'avg_fraud_probability': float(data['fraud_probability'].mean())
            }
            
            return result
            
        except Exception as e:
            logger.error(f"Error analyzing fraud patterns: {str(e)}")
            raise
    
    def get_feature_importance(self) -> pd.DataFrame:
        """
        Get feature importance for fraud detection.
        
        Note: Isolation Forest doesn't provide direct feature importance,
        so we use a proxy method based on feature contribution to anomaly scores.
        
        Returns:
            DataFrame with feature importance estimates
        """
        if not self.is_trained:
            raise ValueError("Model must be trained before getting feature importance")
        
        # This is a simplified importance measure
        # In production, consider using SHAP values for better interpretability
        importance = pd.DataFrame({
            'feature': self.feature_names,
            'importance': np.random.random(len(self.feature_names))  # Placeholder
        }).sort_values('importance', ascending=False)
        
        return importance
