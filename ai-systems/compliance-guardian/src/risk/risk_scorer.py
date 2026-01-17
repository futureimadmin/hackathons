"""
Risk Scoring Module

Uses Gradient Boosting to calculate comprehensive risk scores for transactions.
"""

import numpy as np
import pandas as pd
from typing import Dict, List, Optional
from sklearn.ensemble import GradientBoostingClassifier
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import StandardScaler
from sklearn.metrics import classification_report, roc_auc_score, confusion_matrix
import logging

logger = logging.getLogger(__name__)


class RiskScorer:
    """
    Calculates risk scores (0-100) for transactions using Gradient Boosting.
    
    Combines multiple risk factors into a comprehensive score that indicates
    the likelihood of fraud, compliance violations, or other risks.
    """
    
    def __init__(
        self,
        n_estimators: int = 100,
        learning_rate: float = 0.1,
        max_depth: int = 5,
        random_state: int = 42
    ):
        """
        Initialize risk scorer.
        
        Args:
            n_estimators: Number of boosting stages
            learning_rate: Learning rate for boosting
            max_depth: Maximum depth of trees
            random_state: Random seed for reproducibility
        """
        self.model = GradientBoostingClassifier(
            n_estimators=n_estimators,
            learning_rate=learning_rate,
            max_depth=max_depth,
            random_state=random_state
        )
        self.scaler = StandardScaler()
        self.feature_names = []
        self.is_trained = False
        self.high_risk_threshold = 70  # Score above 70 is high risk
    
    def prepare_features(self, data: pd.DataFrame) -> pd.DataFrame:
        """
        Prepare features for risk scoring.
        
        Args:
            data: DataFrame with transaction data
            
        Returns:
            DataFrame with engineered features
        """
        features = pd.DataFrame()
        
        # Transaction characteristics
        features['amount'] = data['amount']
        features['amount_log'] = np.log1p(data['amount'])
        features['amount_squared'] = data['amount'] ** 2
        
        # Customer risk factors
        features['customer_age_days'] = data.get('customer_age_days', 0)
        features['is_new_customer'] = (data.get('customer_age_days', 365) < 30).astype(int)
        features['customer_transaction_count'] = data.get('previous_transactions', 0)
        features['customer_avg_amount'] = data.get('avg_transaction_amount', 0)
        
        # Behavioral anomalies
        if 'avg_transaction_amount' in data.columns:
            features['amount_vs_avg_ratio'] = (
                data['amount'] / data['avg_transaction_amount'].replace(0, 1)
            )
            features['is_unusual_amount'] = (
                (data['amount'] > data['avg_transaction_amount'] * 3) |
                (data['amount'] < data['avg_transaction_amount'] * 0.3)
            ).astype(int)
        else:
            features['amount_vs_avg_ratio'] = 1.0
            features['is_unusual_amount'] = 0
        
        # Geographic risk
        features['is_international'] = data.get('is_international', 0).astype(int)
        features['distance_from_home'] = data.get('distance_from_home_km', 0)
        features['is_high_risk_country'] = data.get('is_high_risk_country', 0).astype(int)
        
        # Time-based risk
        if 'transaction_time' in data.columns:
            data['transaction_time'] = pd.to_datetime(data['transaction_time'])
            features['hour'] = data['transaction_time'].dt.hour
            features['is_business_hours'] = (
                (data['transaction_time'].dt.hour >= 9) &
                (data['transaction_time'].dt.hour <= 17) &
                (data['transaction_time'].dt.dayofweek < 5)
            ).astype(int)
            features['is_night'] = (
                (data['transaction_time'].dt.hour < 6) |
                (data['transaction_time'].dt.hour >= 22)
            ).astype(int)
        else:
            features['hour'] = 12
            features['is_business_hours'] = 1
            features['is_night'] = 0
        
        # Payment method risk
        features['is_card_present'] = data.get('is_card_present', 1).astype(int)
        features['is_online'] = data.get('is_online', 0).astype(int)
        features['payment_method_risk'] = data.get('payment_method_risk_score', 0)
        
        # Merchant risk
        features['merchant_risk_score'] = data.get('merchant_risk_score', 0)
        features['is_new_merchant'] = data.get('is_new_merchant', 0).astype(int)
        features['merchant_category_risk'] = data.get('merchant_category_risk', 0)
        
        # Velocity indicators
        features['transactions_last_hour'] = data.get('transactions_last_hour', 0)
        features['transactions_last_day'] = data.get('transactions_last_day', 0)
        features['amount_last_hour'] = data.get('amount_last_hour', 0)
        features['amount_last_day'] = data.get('amount_last_day', 0)
        
        # Card and account risk
        features['failed_attempts_last_day'] = data.get('failed_attempts_last_day', 0)
        features['card_age_days'] = data.get('card_age_days', 365)
        features['is_new_card'] = (data.get('card_age_days', 365) < 30).astype(int)
        features['account_changes_last_30d'] = data.get('account_changes_last_30d', 0)
        
        # Device and IP risk
        features['is_new_device'] = data.get('is_new_device', 0).astype(int)
        features['is_vpn'] = data.get('is_vpn', 0).astype(int)
        features['ip_risk_score'] = data.get('ip_risk_score', 0)
        
        # Compliance indicators
        features['kyc_verified'] = data.get('kyc_verified', 1).astype(int)
        features['aml_flagged'] = data.get('aml_flagged', 0).astype(int)
        features['sanctions_match'] = data.get('sanctions_match', 0).astype(int)
        
        # Derived risk indicators
        features['multiple_risk_factors'] = (
            features['is_international'] +
            features['is_night'] +
            features['is_new_customer'] +
            features['is_new_card'] +
            features['is_new_device']
        )
        
        features['velocity_risk'] = (
            (features['transactions_last_hour'] >= 3).astype(int) +
            (features['transactions_last_day'] >= 10).astype(int)
        )
        
        return features
    
    def train(
        self,
        data: pd.DataFrame,
        target_column: str = 'is_high_risk',
        test_size: float = 0.2
    ) -> Dict:
        """
        Train the risk scoring model.
        
        Args:
            data: Training data with transaction features and risk labels
            target_column: Name of the target column (1 = high risk, 0 = low risk)
            test_size: Proportion of data for testing
            
        Returns:
            Dictionary with training metrics
        """
        try:
            # Prepare features
            X = self.prepare_features(data)
            y = data[target_column]
            
            self.feature_names = X.columns.tolist()
            
            # Split data
            X_train, X_test, y_train, y_test = train_test_split(
                X, y, test_size=test_size, random_state=42, stratify=y
            )
            
            # Scale features
            X_train_scaled = self.scaler.fit_transform(X_train)
            X_test_scaled = self.scaler.transform(X_test)
            
            # Train model
            logger.info("Training risk scoring model...")
            self.model.fit(X_train_scaled, y_train)
            
            # Predictions
            y_pred = self.model.predict(X_test_scaled)
            y_pred_proba = self.model.predict_proba(X_test_scaled)[:, 1]
            
            # Calculate metrics
            train_score = self.model.score(X_train_scaled, y_train)
            test_score = self.model.score(X_test_scaled, y_test)
            roc_auc = roc_auc_score(y_test, y_pred_proba)
            
            # Confusion matrix
            cm = confusion_matrix(y_test, y_pred)
            tn, fp, fn, tp = cm.ravel()
            
            # Classification report
            report = classification_report(y_test, y_pred, output_dict=True)
            
            # Feature importance
            feature_importance = pd.DataFrame({
                'feature': self.feature_names,
                'importance': self.model.feature_importances_
            }).sort_values('importance', ascending=False)
            
            self.is_trained = True
            
            result = {
                'train_accuracy': float(train_score),
                'test_accuracy': float(test_score),
                'roc_auc': float(roc_auc),
                'precision': float(report['1']['precision']),
                'recall': float(report['1']['recall']),
                'f1_score': float(report['1']['f1-score']),
                'confusion_matrix': {
                    'true_negatives': int(tn),
                    'false_positives': int(fp),
                    'false_negatives': int(fn),
                    'true_positives': int(tp)
                },
                'n_samples': len(data),
                'n_features': len(self.feature_names),
                'high_risk_rate': float(y.mean()),
                'feature_importance': feature_importance.head(10).to_dict('records')
            }
            
            logger.info(f"Risk scoring model trained - ROC AUC: {roc_auc:.3f}, Accuracy: {test_score:.3f}")
            
            return result
            
        except Exception as e:
            logger.error(f"Error training risk scoring model: {str(e)}")
            raise
    
    def calculate_risk_score(self, data: pd.DataFrame) -> pd.DataFrame:
        """
        Calculate risk scores (0-100) for transactions.
        
        Args:
            data: DataFrame with transaction data
            
        Returns:
            DataFrame with risk scores
        """
        try:
            if not self.is_trained:
                # If not trained, use rule-based scoring
                return self._rule_based_scoring(data)
            
            # Prepare features
            X = self.prepare_features(data)
            
            # Ensure all features are present
            for feature in self.feature_names:
                if feature not in X.columns:
                    X[feature] = 0
            
            X = X[self.feature_names]
            
            # Scale and predict
            X_scaled = self.scaler.transform(X)
            risk_probability = self.model.predict_proba(X_scaled)[:, 1]
            
            # Convert probability to 0-100 score
            risk_score = risk_probability * 100
            
            # Create result DataFrame
            result = data.copy()
            result['risk_score'] = risk_score
            result['risk_level'] = pd.cut(
                risk_score,
                bins=[0, 30, 60, 80, 100],
                labels=['Low', 'Medium', 'High', 'Critical']
            )
            result['is_high_risk'] = (risk_score >= self.high_risk_threshold).astype(int)
            
            logger.info(f"Calculated risk scores for {len(data)} transactions")
            
            return result
            
        except Exception as e:
            logger.error(f"Error calculating risk scores: {str(e)}")
            raise
    
    def _rule_based_scoring(self, data: pd.DataFrame) -> pd.DataFrame:
        """
        Calculate risk scores using rule-based approach (when model not trained).
        
        Args:
            data: DataFrame with transaction data
            
        Returns:
            DataFrame with risk scores
        """
        result = data.copy()
        risk_score = np.zeros(len(data))
        
        # Amount-based risk (0-20 points)
        if 'amount' in data.columns:
            amount_percentile = data['amount'].rank(pct=True)
            risk_score += amount_percentile * 20
        
        # International transactions (+15 points)
        if 'is_international' in data.columns:
            risk_score += data['is_international'] * 15
        
        # New customer (+10 points)
        if 'customer_age_days' in data.columns:
            risk_score += (data['customer_age_days'] < 30).astype(int) * 10
        
        # Night transactions (+10 points)
        if 'transaction_time' in data.columns:
            data['transaction_time'] = pd.to_datetime(data['transaction_time'])
            hour = data['transaction_time'].dt.hour
            risk_score += ((hour < 6) | (hour >= 22)).astype(int) * 10
        
        # High velocity (+15 points)
        if 'transactions_last_hour' in data.columns:
            risk_score += (data['transactions_last_hour'] >= 3).astype(int) * 15
        
        # Failed attempts (+10 points)
        if 'failed_attempts_last_day' in data.columns:
            risk_score += (data['failed_attempts_last_day'] > 0).astype(int) * 10
        
        # Card not present (+10 points)
        if 'is_card_present' in data.columns:
            risk_score += (1 - data['is_card_present']) * 10
        
        # New device (+10 points)
        if 'is_new_device' in data.columns:
            risk_score += data['is_new_device'] * 10
        
        # Cap at 100
        risk_score = np.minimum(risk_score, 100)
        
        result['risk_score'] = risk_score
        result['risk_level'] = pd.cut(
            risk_score,
            bins=[0, 30, 60, 80, 100],
            labels=['Low', 'Medium', 'High', 'Critical']
        )
        result['is_high_risk'] = (risk_score >= self.high_risk_threshold).astype(int)
        
        return result
    
    def flag_high_risk_transactions(
        self,
        data: pd.DataFrame,
        threshold: int = 70
    ) -> pd.DataFrame:
        """
        Flag transactions with high risk scores.
        
        Args:
            data: DataFrame with transaction data
            threshold: Minimum risk score to flag (default 70)
            
        Returns:
            DataFrame with flagged transactions
        """
        try:
            # Calculate risk scores
            scored = self.calculate_risk_score(data)
            
            # Filter high-risk transactions
            high_risk = scored[scored['risk_score'] >= threshold].copy()
            
            # Sort by risk score
            high_risk = high_risk.sort_values('risk_score', ascending=False)
            
            logger.info(f"Flagged {len(high_risk)} high-risk transactions")
            
            return high_risk
            
        except Exception as e:
            logger.error(f"Error flagging high-risk transactions: {str(e)}")
            raise
    
    def analyze_risk_distribution(self, data: pd.DataFrame) -> Dict:
        """
        Analyze risk score distribution.
        
        Args:
            data: DataFrame with transaction data and risk scores
            
        Returns:
            Dictionary with risk distribution analysis
        """
        try:
            if 'risk_score' not in data.columns:
                data = self.calculate_risk_score(data)
            
            # Risk level distribution
            risk_distribution = data['risk_level'].value_counts().to_dict()
            
            # Score statistics
            score_stats = {
                'min': float(data['risk_score'].min()),
                'max': float(data['risk_score'].max()),
                'mean': float(data['risk_score'].mean()),
                'median': float(data['risk_score'].median()),
                'std': float(data['risk_score'].std())
            }
            
            # High-risk analysis
            high_risk = data[data['risk_score'] >= self.high_risk_threshold]
            
            result = {
                'total_transactions': len(data),
                'high_risk_count': len(high_risk),
                'high_risk_percentage': float(len(high_risk) / len(data) * 100),
                'risk_distribution': {k: int(v) for k, v in risk_distribution.items()},
                'score_statistics': score_stats,
                'threshold': self.high_risk_threshold
            }
            
            return result
            
        except Exception as e:
            logger.error(f"Error analyzing risk distribution: {str(e)}")
            raise
