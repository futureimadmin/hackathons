"""
Customer Churn Prediction Module

Predicts customer churn probability using machine learning models.
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


class ChurnPredictor:
    """
    Predicts customer churn using Gradient Boosting Classifier.
    
    Identifies at-risk customers based on behavioral patterns
    and engagement metrics.
    """
    
    def __init__(self, n_estimators: int = 100, random_state: int = 42):
        self.model = GradientBoostingClassifier(
            n_estimators=n_estimators,
            learning_rate=0.1,
            max_depth=5,
            random_state=random_state
        )
        self.scaler = StandardScaler()
        self.feature_names = []
        self.is_trained = False
        self.churn_threshold = 0.5
    
    def prepare_features(self, data: pd.DataFrame) -> pd.DataFrame:
        """
        Prepare features for churn prediction.
        
        Args:
            data: DataFrame with customer data
            
        Returns:
            DataFrame with engineered features
        """
        features = pd.DataFrame()
        
        # Recency features (strong churn indicators)
        features['days_since_last_purchase'] = data['recency_days']
        features['is_inactive_30d'] = (data['recency_days'] > 30).astype(int)
        features['is_inactive_60d'] = (data['recency_days'] > 60).astype(int)
        features['is_inactive_90d'] = (data['recency_days'] > 90).astype(int)
        
        # Frequency features
        features['total_purchases'] = data['frequency']
        features['is_one_time_buyer'] = (data['frequency'] == 1).astype(int)
        features['purchase_frequency_rate'] = data['frequency'] / data['customer_age_days'].replace(0, 1)
        
        # Monetary features
        features['total_spent'] = data['monetary_total']
        features['avg_order_value'] = data['monetary_total'] / data['frequency'].replace(0, 1)
        features['spending_trend'] = data.get('spending_trend', 0)  # Recent vs historical spending
        
        # Engagement features
        features['customer_age_days'] = data['customer_age_days']
        features['avg_days_between_purchases'] = data['customer_age_days'] / data['frequency'].replace(0, 1)
        features['email_open_rate'] = data.get('email_open_rate', 0)
        features['email_click_rate'] = data.get('email_click_rate', 0)
        features['website_visits_last_30d'] = data.get('website_visits_last_30d', 0)
        
        # Product engagement
        features['unique_products'] = data.get('unique_products_purchased', 1)
        features['unique_categories'] = data.get('unique_categories_purchased', 1)
        features['product_diversity'] = features['unique_products'] / features['total_purchases'].replace(0, 1)
        
        # Satisfaction indicators
        features['return_rate'] = data.get('return_rate', 0)
        features['avg_rating'] = data.get('avg_rating', 3.5)
        features['has_complained'] = data.get('has_complained', 0).astype(int)
        features['support_tickets'] = data.get('support_tickets', 0)
        
        # Promotional engagement
        features['promo_usage_rate'] = data.get('promo_usage_rate', 0)
        features['discount_dependency'] = data.get('discount_dependency', 0)
        
        # Derived risk indicators
        features['declining_engagement'] = (
            (features['days_since_last_purchase'] > features['avg_days_between_purchases'] * 1.5)
        ).astype(int)
        features['low_satisfaction'] = (features['avg_rating'] < 3.0).astype(int)
        features['high_return_rate'] = (features['return_rate'] > 0.2).astype(int)
        
        return features
    
    def train(
        self,
        data: pd.DataFrame,
        target_column: str = 'churned',
        test_size: float = 0.2
    ) -> Dict:
        """
        Train the churn prediction model.
        
        Args:
            data: Training data with customer features and churn labels
            target_column: Name of the target column (1 = churned, 0 = active)
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
            logger.info("Training churn prediction model...")
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
                'churn_rate': float(y.mean()),
                'feature_importance': feature_importance.head(10).to_dict('records')
            }
            
            logger.info(f"Churn model trained - ROC AUC: {roc_auc:.3f}, Accuracy: {test_score:.3f}")
            
            return result
            
        except Exception as e:
            logger.error(f"Error training churn model: {str(e)}")
            raise
    
    def predict(self, data: pd.DataFrame) -> pd.DataFrame:
        """
        Predict churn probability for customers.
        
        Args:
            data: DataFrame with customer features
            
        Returns:
            DataFrame with churn predictions
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
            churn_probability = self.model.predict_proba(X_scaled)[:, 1]
            churn_prediction = (churn_probability >= self.churn_threshold).astype(int)
            
            # Create result DataFrame
            result = data.copy()
            result['churn_probability'] = churn_probability
            result['churn_prediction'] = churn_prediction
            result['risk_level'] = pd.cut(
                churn_probability,
                bins=[0, 0.3, 0.6, 0.8, 1.0],
                labels=['Low', 'Medium', 'High', 'Critical']
            )
            
            logger.info(f"Predicted churn for {len(data)} customers")
            
            return result
            
        except Exception as e:
            logger.error(f"Error predicting churn: {str(e)}")
            raise
    
    def identify_at_risk_customers(
        self,
        data: pd.DataFrame,
        risk_threshold: float = 0.6
    ) -> pd.DataFrame:
        """
        Identify customers at high risk of churning.
        
        Args:
            data: DataFrame with customer data
            risk_threshold: Minimum churn probability to flag (default 0.6)
            
        Returns:
            DataFrame with at-risk customers
        """
        try:
            # Get predictions
            predictions = self.predict(data)
            
            # Filter at-risk customers
            at_risk = predictions[predictions['churn_probability'] >= risk_threshold].copy()
            
            # Sort by risk
            at_risk = at_risk.sort_values('churn_probability', ascending=False)
            
            logger.info(f"Identified {len(at_risk)} at-risk customers")
            
            return at_risk
            
        except Exception as e:
            logger.error(f"Error identifying at-risk customers: {str(e)}")
            raise
    
    def analyze_churn_factors(self, data: pd.DataFrame) -> Dict:
        """
        Analyze key factors contributing to churn.
        
        Args:
            data: DataFrame with customer data and predictions
            
        Returns:
            Dictionary with churn factor analysis
        """
        try:
            if not self.is_trained:
                raise ValueError("Model must be trained before analysis")
            
            # Get predictions if not present
            if 'churn_probability' not in data.columns:
                data = self.predict(data)
            
            # Segment by risk level
            risk_segments = data.groupby('risk_level').agg({
                'customer_id': 'count',
                'churn_probability': 'mean',
                'recency_days': 'mean',
                'frequency': 'mean',
                'monetary_total': 'mean'
            }).reset_index()
            
            risk_segments.columns = ['risk_level', 'count', 'avg_churn_prob', 
                                    'avg_recency', 'avg_frequency', 'avg_monetary']
            
            # Top churn indicators
            feature_importance = pd.DataFrame({
                'feature': self.feature_names,
                'importance': self.model.feature_importances_
            }).sort_values('importance', ascending=False).head(10)
            
            result = {
                'risk_distribution': risk_segments.to_dict('records'),
                'total_customers': len(data),
                'at_risk_count': len(data[data['churn_probability'] >= 0.6]),
                'at_risk_percentage': float(len(data[data['churn_probability'] >= 0.6]) / len(data) * 100),
                'avg_churn_probability': float(data['churn_probability'].mean()),
                'top_churn_factors': feature_importance.to_dict('records')
            }
            
            return result
            
        except Exception as e:
            logger.error(f"Error analyzing churn factors: {str(e)}")
            raise
