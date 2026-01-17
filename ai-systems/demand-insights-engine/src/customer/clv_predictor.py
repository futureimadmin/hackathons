"""
Customer Lifetime Value (CLV) Prediction Module

Predicts customer lifetime value using machine learning models.
"""

import numpy as np
import pandas as pd
from typing import Dict, List, Optional
from sklearn.ensemble import RandomForestRegressor
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import StandardScaler
import logging

logger = logging.getLogger(__name__)


class CLVPredictor:
    """
    Predicts customer lifetime value using Random Forest regression.
    
    Calculates CLV based on customer behavior, purchase history,
    and engagement metrics.
    """
    
    def __init__(self, n_estimators: int = 100, random_state: int = 42):
        self.model = RandomForestRegressor(
            n_estimators=n_estimators,
            max_depth=10,
            min_samples_split=5,
            random_state=random_state,
            n_jobs=-1
        )
        self.scaler = StandardScaler()
        self.feature_names = []
        self.is_trained = False
    
    def prepare_features(self, data: pd.DataFrame) -> pd.DataFrame:
        """
        Prepare features for CLV prediction.
        
        Args:
            data: DataFrame with customer data
            
        Returns:
            DataFrame with engineered features
        """
        features = pd.DataFrame()
        
        # RFM features
        features['recency_days'] = data['recency_days']
        features['frequency'] = data['frequency']
        features['monetary_total'] = data['monetary_total']
        features['avg_order_value'] = data['monetary_total'] / data['frequency'].replace(0, 1)
        
        # Time-based features
        features['customer_age_days'] = data['customer_age_days']
        features['purchase_frequency_rate'] = data['frequency'] / data['customer_age_days'].replace(0, 1)
        
        # Engagement features
        features['days_since_last_purchase'] = data.get('days_since_last_purchase', data['recency_days'])
        features['avg_days_between_purchases'] = data['customer_age_days'] / data['frequency'].replace(0, 1)
        
        # Product diversity
        features['unique_products'] = data.get('unique_products_purchased', 1)
        features['unique_categories'] = data.get('unique_categories_purchased', 1)
        
        # Returns and satisfaction
        features['return_rate'] = data.get('return_rate', 0)
        features['avg_rating'] = data.get('avg_rating', 3.5)
        
        # Promotional engagement
        features['promo_usage_rate'] = data.get('promo_usage_rate', 0)
        features['email_open_rate'] = data.get('email_open_rate', 0)
        
        # Derived features
        features['is_active'] = (features['recency_days'] <= 90).astype(int)
        features['is_frequent_buyer'] = (features['frequency'] >= 5).astype(int)
        features['is_high_value'] = (features['monetary_total'] >= features['monetary_total'].quantile(0.75)).astype(int)
        
        return features
    
    def train(
        self,
        data: pd.DataFrame,
        target_column: str = 'actual_clv',
        test_size: float = 0.2
    ) -> Dict:
        """
        Train the CLV prediction model.
        
        Args:
            data: Training data with customer features and actual CLV
            target_column: Name of the target column
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
                X, y, test_size=test_size, random_state=42
            )
            
            # Scale features
            X_train_scaled = self.scaler.fit_transform(X_train)
            X_test_scaled = self.scaler.transform(X_test)
            
            # Train model
            logger.info("Training CLV prediction model...")
            self.model.fit(X_train_scaled, y_train)
            
            # Evaluate
            train_score = self.model.score(X_train_scaled, y_train)
            test_score = self.model.score(X_test_scaled, y_test)
            
            # Predictions
            y_pred = self.model.predict(X_test_scaled)
            
            # Calculate metrics
            mae = np.mean(np.abs(y_test - y_pred))
            rmse = np.sqrt(np.mean((y_test - y_pred) ** 2))
            mape = np.mean(np.abs((y_test - y_pred) / y_test.replace(0, 1))) * 100
            
            # Feature importance
            feature_importance = pd.DataFrame({
                'feature': self.feature_names,
                'importance': self.model.feature_importances_
            }).sort_values('importance', ascending=False)
            
            self.is_trained = True
            
            result = {
                'train_r2': float(train_score),
                'test_r2': float(test_score),
                'mae': float(mae),
                'rmse': float(rmse),
                'mape': float(mape),
                'n_samples': len(data),
                'n_features': len(self.feature_names),
                'feature_importance': feature_importance.head(10).to_dict('records')
            }
            
            logger.info(f"CLV model trained - Test R²: {test_score:.3f}, MAE: ${mae:.2f}")
            
            return result
            
        except Exception as e:
            logger.error(f"Error training CLV model: {str(e)}")
            raise
    
    def predict(self, data: pd.DataFrame) -> pd.DataFrame:
        """
        Predict CLV for customers.
        
        Args:
            data: DataFrame with customer features
            
        Returns:
            DataFrame with CLV predictions
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
            predictions = self.model.predict(X_scaled)
            
            # Create result DataFrame
            result = data.copy()
            result['predicted_clv'] = predictions
            result['clv_segment'] = pd.cut(
                predictions,
                bins=[0, 100, 500, 1000, float('inf')],
                labels=['Low', 'Medium', 'High', 'Very High']
            )
            
            logger.info(f"Predicted CLV for {len(data)} customers")
            
            return result
            
        except Exception as e:
            logger.error(f"Error predicting CLV: {str(e)}")
            raise
    
    def calculate_clv_simple(
        self,
        avg_order_value: float,
        purchase_frequency: float,
        customer_lifespan_years: float,
        profit_margin: float = 0.2
    ) -> float:
        """
        Calculate CLV using simple formula.
        
        CLV = (Average Order Value × Purchase Frequency × Customer Lifespan) × Profit Margin
        
        Args:
            avg_order_value: Average value per order
            purchase_frequency: Number of purchases per year
            customer_lifespan_years: Expected customer lifespan in years
            profit_margin: Profit margin as decimal (default 20%)
            
        Returns:
            Calculated CLV
        """
        clv = avg_order_value * purchase_frequency * customer_lifespan_years * profit_margin
        return float(clv)
    
    def segment_by_clv(self, data: pd.DataFrame, clv_column: str = 'predicted_clv') -> Dict:
        """
        Segment customers by CLV.
        
        Args:
            data: DataFrame with CLV predictions
            clv_column: Name of CLV column
            
        Returns:
            Dictionary with segment analysis
        """
        try:
            # Define segments
            data = data.copy()
            data['clv_segment'] = pd.cut(
                data[clv_column],
                bins=[0, 100, 500, 1000, float('inf')],
                labels=['Low', 'Medium', 'High', 'Very High']
            )
            
            # Analyze segments
            segments = []
            for segment in ['Low', 'Medium', 'High', 'Very High']:
                segment_data = data[data['clv_segment'] == segment]
                
                if len(segment_data) > 0:
                    segments.append({
                        'segment': segment,
                        'count': len(segment_data),
                        'percentage': float(len(segment_data) / len(data) * 100),
                        'avg_clv': float(segment_data[clv_column].mean()),
                        'total_clv': float(segment_data[clv_column].sum()),
                        'avg_frequency': float(segment_data['frequency'].mean()) if 'frequency' in segment_data else 0,
                        'avg_monetary': float(segment_data['monetary_total'].mean()) if 'monetary_total' in segment_data else 0
                    })
            
            result = {
                'segments': segments,
                'total_customers': len(data),
                'total_clv': float(data[clv_column].sum()),
                'avg_clv': float(data[clv_column].mean()),
                'median_clv': float(data[clv_column].median())
            }
            
            logger.info(f"Segmented {len(data)} customers by CLV")
            
            return result
            
        except Exception as e:
            logger.error(f"Error segmenting by CLV: {str(e)}")
            raise
