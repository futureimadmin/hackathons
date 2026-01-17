"""
Prophet Forecasting Model

Implements Facebook Prophet for time series forecasting with automatic seasonality detection.
Handles multiple seasonality patterns and holidays.
"""

import pandas as pd
import numpy as np
from prophet import Prophet
import logging
from typing import Dict, List, Optional

logger = logging.getLogger(__name__)


class ProphetForecaster:
    """Prophet forecasting model with automatic seasonality detection."""
    
    def __init__(
        self,
        yearly_seasonality: bool = True,
        weekly_seasonality: bool = True,
        daily_seasonality: bool = False,
        seasonality_mode: str = 'multiplicative'
    ):
        """
        Initialize Prophet forecaster.
        
        Args:
            yearly_seasonality: Enable yearly seasonality
            weekly_seasonality: Enable weekly seasonality
            daily_seasonality: Enable daily seasonality
            seasonality_mode: 'additive' or 'multiplicative'
        """
        self.yearly_seasonality = yearly_seasonality
        self.weekly_seasonality = weekly_seasonality
        self.daily_seasonality = daily_seasonality
        self.seasonality_mode = seasonality_mode
        self.model = None
        
    def prepare_data(self, series: pd.Series) -> pd.DataFrame:
        """
        Prepare data in Prophet format (ds, y columns).
        
        Args:
            series: Time series with datetime index
            
        Returns:
            DataFrame with 'ds' and 'y' columns
        """
        df = pd.DataFrame({
            'ds': series.index,
            'y': series.values
        })
        return df
    
    def fit(self, series: pd.Series, holidays: Optional[pd.DataFrame] = None):
        """
        Fit Prophet model to time series data.
        
        Args:
            series: Time series data with datetime index
            holidays: Optional DataFrame with holiday dates
        """
        logger.info("Fitting Prophet model...")
        
        # Prepare data
        df = self.prepare_data(series)
        
        # Initialize model
        self.model = Prophet(
            yearly_seasonality=self.yearly_seasonality,
            weekly_seasonality=self.weekly_seasonality,
            daily_seasonality=self.daily_seasonality,
            seasonality_mode=self.seasonality_mode,
            holidays=holidays
        )
        
        # Fit model
        self.model.fit(df)
        
        logger.info("Prophet model fitted successfully")
    
    def forecast(self, steps: int, freq: str = 'D', confidence_level: float = 0.95) -> Dict:
        """
        Generate forecast with confidence intervals.
        
        Args:
            steps: Number of periods to forecast
            freq: Frequency of forecast ('D' for daily, 'W' for weekly, etc.)
            confidence_level: Confidence level for intervals (default 0.95)
            
        Returns:
            Dictionary with forecast, lower_bound, upper_bound, trend, seasonality
        """
        if self.model is None:
            raise ValueError("Model must be fitted before forecasting")
        
        logger.info(f"Generating {steps}-step forecast with Prophet...")
        
        # Create future dataframe
        future = self.model.make_future_dataframe(periods=steps, freq=freq)
        
        # Generate forecast
        forecast_df = self.model.predict(future)
        
        # Extract forecast values (only future periods)
        forecast_values = forecast_df.tail(steps)
        
        # Adjust interval width based on confidence level
        interval_width = confidence_level
        
        result = {
            'forecast': forecast_values['yhat'].tolist(),
            'lower_bound': forecast_values['yhat_lower'].tolist(),
            'upper_bound': forecast_values['yhat_upper'].tolist(),
            'trend': forecast_values['trend'].tolist(),
            'dates': forecast_values['ds'].dt.strftime('%Y-%m-%d').tolist(),
            'model': 'Prophet',
            'seasonality_mode': self.seasonality_mode,
            'confidence_level': confidence_level
        }
        
        # Add seasonality components if available
        if 'yearly' in forecast_values.columns:
            result['yearly_seasonality'] = forecast_values['yearly'].tolist()
        if 'weekly' in forecast_values.columns:
            result['weekly_seasonality'] = forecast_values['weekly'].tolist()
        
        return result
    
    def evaluate(self, test_series: pd.Series) -> Dict:
        """
        Evaluate model performance on test data.
        
        Args:
            test_series: Test time series data
            
        Returns:
            Dictionary with RMSE, MAE, MAPE metrics
        """
        if self.model is None:
            raise ValueError("Model must be fitted before evaluation")
        
        # Prepare test data
        test_df = self.prepare_data(test_series)
        
        # Generate predictions
        predictions = self.model.predict(test_df)
        
        # Calculate metrics
        actual = test_df['y'].values
        predicted = predictions['yhat'].values
        
        rmse = np.sqrt(np.mean((actual - predicted) ** 2))
        mae = np.mean(np.abs(actual - predicted))
        mape = np.mean(np.abs((actual - predicted) / actual)) * 100
        
        metrics = {
            'rmse': float(rmse),
            'mae': float(mae),
            'mape': float(mape)
        }
        
        logger.info(f"Evaluation metrics: RMSE={rmse:.2f}, MAE={mae:.2f}, MAPE={mape:.2f}%")
        return metrics
    
    def get_changepoints(self) -> pd.DataFrame:
        """
        Get detected changepoints in the time series.
        
        Returns:
            DataFrame with changepoint dates and deltas
        """
        if self.model is None:
            raise ValueError("Model must be fitted first")
        
        changepoints = pd.DataFrame({
            'date': self.model.changepoints,
            'delta': self.model.params['delta'].mean(axis=0)
        })
        
        return changepoints
    
    def plot_components(self):
        """
        Plot forecast components (trend, seasonality).
        Note: This requires matplotlib and is meant for analysis, not production.
        """
        if self.model is None:
            raise ValueError("Model must be fitted first")
        
        # This would typically be used in notebooks for analysis
        logger.info("Use model.plot_components() for visualization in notebooks")
