"""
Demand Forecasting

Implements XGBoost-based demand forecasting with feature engineering
for seasonality, promotions, and price effects.
"""

import pandas as pd
import numpy as np
import xgboost as xgb
from sklearn.model_selection import train_test_split, TimeSeriesSplit
from sklearn.metrics import mean_squared_error, mean_absolute_error
import logging
from typing import Dict, List, Tuple, Optional
from datetime import datetime, timedelta

logger = logging.getLogger(__name__)


class DemandForecaster:
    """Demand forecasting using XGBoost with engineered features."""
    
    def __init__(
        self,
        n_estimators: int = 100,
        max_depth: int = 6,
        learning_rate: float = 0.1,
        lookback_days: int = 30
    ):
        """
        Initialize demand forecaster.
        
        Args:
            n_estimators: Number of boosting rounds
            max_depth: Maximum tree depth
            learning_rate: Learning rate
            lookback_days: Number of days to look back for features
        """
        self.n_estimators = n_estimators
        self.max_depth = max_depth
        self.learning_rate = learning_rate
        self.lookback_days = lookback_days
        self.model = None
        self.feature_importance = None
        
    def engineer_features(
        self,
        sales_data: pd.DataFrame,
        include_promotions: bool = True
    ) -> pd.DataFrame:
        """
        Engineer features for demand forecasting.
        
        Args:
            sales_data: DataFrame with date, product_id, quantity, price
            include_promotions: Whether to include promotion features
            
        Returns:
            DataFrame with engineered features
        """
        logger.info("Engineering features for demand forecasting...")
        
        df = sales_data.copy()
        df['date'] = pd.to_datetime(df['date'])
        df = df.sort_values('date')
        
        # Time-based features
        df['year'] = df['date'].dt.year
        df['month'] = df['date'].dt.month
        df['day'] = df['date'].dt.day
        df['day_of_week'] = df['date'].dt.dayofweek
        df['day_of_year'] = df['date'].dt.dayofyear
        df['week_of_year'] = df['date'].dt.isocalendar().week
        df['quarter'] = df['date'].dt.quarter
        df['is_weekend'] = (df['day_of_week'] >= 5).astype(int)
        df['is_month_start'] = df['date'].dt.is_month_start.astype(int)
        df['is_month_end'] = df['date'].dt.is_month_end.astype(int)
        
        # Cyclical encoding for seasonality
        df['month_sin'] = np.sin(2 * np.pi * df['month'] / 12)
        df['month_cos'] = np.cos(2 * np.pi * df['month'] / 12)
        df['day_of_week_sin'] = np.sin(2 * np.pi * df['day_of_week'] / 7)
        df['day_of_week_cos'] = np.cos(2 * np.pi * df['day_of_week'] / 7)
        
        # Lag features (previous days' sales)
        for product_id in df['product_id'].unique():
            mask = df['product_id'] == product_id
            for lag in [1, 7, 14, 30]:
                df.loc[mask, f'quantity_lag_{lag}'] = df.loc[mask, 'quantity'].shift(lag)
        
        # Rolling statistics
        for product_id in df['product_id'].unique():
            mask = df['product_id'] == product_id
            for window in [7, 14, 30]:
                df.loc[mask, f'quantity_rolling_mean_{window}'] = df.loc[mask, 'quantity'].rolling(window).mean()
                df.loc[mask, f'quantity_rolling_std_{window}'] = df.loc[mask, 'quantity'].rolling(window).std()
        
        # Price features
        if 'price' in df.columns:
            for product_id in df['product_id'].unique():
                mask = df['product_id'] == product_id
                df.loc[mask, 'price_change'] = df.loc[mask, 'price'].pct_change()
                df.loc[mask, 'price_rolling_mean_7'] = df.loc[mask, 'price'].rolling(7).mean()
        
        # Promotion features
        if include_promotions and 'has_promotion' in df.columns:
            df['promotion_days'] = df.groupby('product_id')['has_promotion'].transform(
                lambda x: x.rolling(7, min_periods=1).sum()
            )
        
        # Fill NaN values
        df = df.fillna(method='bfill').fillna(0)
        
        logger.info(f"Engineered {len(df.columns)} features")
        return df
    
    def prepare_training_data(
        self,
        features_df: pd.DataFrame,
        target_col: str = 'quantity'
    ) -> Tuple[pd.DataFrame, pd.Series]:
        """
        Prepare training data by selecting features and target.
        
        Args:
            features_df: DataFrame with engineered features
            target_col: Name of target column
            
        Returns:
            Tuple of (X, y)
        """
        # Exclude non-feature columns
        exclude_cols = ['date', 'product_id', 'order_id', target_col]
        feature_cols = [col for col in features_df.columns if col not in exclude_cols]
        
        X = features_df[feature_cols]
        y = features_df[target_col]
        
        return X, y
    
    def fit(
        self,
        sales_data: pd.DataFrame,
        validation_split: float = 0.2
    ) -> 'DemandForecaster':
        """
        Fit XGBoost model to sales data.
        
        Args:
            sales_data: DataFrame with sales history
            validation_split: Fraction for validation
            
        Returns:
            Self for method chaining
        """
        logger.info("Fitting demand forecasting model...")
        
        # Engineer features
        features_df = self.engineer_features(sales_data)
        
        # Prepare training data
        X, y = self.prepare_training_data(features_df)
        
        # Time series split for validation
        split_idx = int(len(X) * (1 - validation_split))
        X_train, X_val = X.iloc[:split_idx], X.iloc[split_idx:]
        y_train, y_val = y.iloc[:split_idx], y.iloc[split_idx:]
        
        # Train XGBoost model
        self.model = xgb.XGBRegressor(
            n_estimators=self.n_estimators,
            max_depth=self.max_depth,
            learning_rate=self.learning_rate,
            objective='reg:squarederror',
            random_state=42
        )
        
        self.model.fit(
            X_train, y_train,
            eval_set=[(X_val, y_val)],
            early_stopping_rounds=10,
            verbose=False
        )
        
        # Store feature importance
        self.feature_importance = pd.DataFrame({
            'feature': X.columns,
            'importance': self.model.feature_importances_
        }).sort_values('importance', ascending=False)
        
        logger.info("Model fitted successfully")
        return self
    
    def predict(
        self,
        sales_data: pd.DataFrame,
        forecast_horizon: int = 30
    ) -> pd.DataFrame:
        """
        Generate demand forecast.
        
        Args:
            sales_data: Historical sales data
            forecast_horizon: Number of days to forecast
            
        Returns:
            DataFrame with forecasts
        """
        if self.model is None:
            raise ValueError("Model must be fitted before prediction")
        
        logger.info(f"Generating {forecast_horizon}-day demand forecast...")
        
        # Engineer features for historical data
        features_df = self.engineer_features(sales_data)
        X, _ = self.prepare_training_data(features_df)
        
        # Generate predictions for historical period
        predictions = self.model.predict(X)
        
        # Create forecast dataframe
        forecast_df = features_df[['date', 'product_id']].copy()
        forecast_df['predicted_quantity'] = predictions
        
        # For future dates, we would need to create future feature rows
        # This is a simplified version - in production, implement recursive forecasting
        
        return forecast_df
    
    def evaluate(
        self,
        test_data: pd.DataFrame
    ) -> Dict[str, float]:
        """
        Evaluate model performance.
        
        Args:
            test_data: Test dataset
            
        Returns:
            Dictionary with evaluation metrics
        """
        if self.model is None:
            raise ValueError("Model must be fitted before evaluation")
        
        # Engineer features
        features_df = self.engineer_features(test_data)
        X, y_true = self.prepare_training_data(features_df)
        
        # Predict
        y_pred = self.model.predict(X)
        
        # Calculate metrics
        rmse = np.sqrt(mean_squared_error(y_true, y_pred))
        mae = mean_absolute_error(y_true, y_pred)
        mape = np.mean(np.abs((y_true - y_pred) / y_true)) * 100
        
        # R-squared
        ss_res = np.sum((y_true - y_pred) ** 2)
        ss_tot = np.sum((y_true - np.mean(y_true)) ** 2)
        r2 = 1 - (ss_res / ss_tot)
        
        metrics = {
            'rmse': float(rmse),
            'mae': float(mae),
            'mape': float(mape),
            'r2': float(r2)
        }
        
        logger.info(f"Evaluation metrics: RMSE={rmse:.2f}, MAE={mae:.2f}, MAPE={mape:.2f}%, R²={r2:.3f}")
        return metrics
    
    def get_feature_importance(self, top_n: int = 10) -> pd.DataFrame:
        """
        Get top N most important features.
        
        Args:
            top_n: Number of top features to return
            
        Returns:
            DataFrame with feature importance
        """
        if self.feature_importance is None:
            raise ValueError("Model must be fitted first")
        
        return self.feature_importance.head(top_n)
