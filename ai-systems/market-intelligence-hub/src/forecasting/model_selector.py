"""
Model Selector

Compares multiple forecasting models and selects the best one based on evaluation metrics.
"""

import pandas as pd
import numpy as np
import logging
from typing import Dict, List, Optional
from .arima_forecaster import ARIMAForecaster
from .prophet_forecaster import ProphetForecaster
from .lstm_forecaster import LSTMForecaster

logger = logging.getLogger(__name__)


class ModelSelector:
    """Select best forecasting model based on performance metrics."""
    
    def __init__(self, test_size: float = 0.2):
        """
        Initialize model selector.
        
        Args:
            test_size: Fraction of data to use for testing
        """
        self.test_size = test_size
        self.models = {}
        self.evaluation_results = {}
        self.best_model_name = None
        self.best_model = None
        
    def split_data(self, series: pd.Series) -> tuple:
        """
        Split time series into train and test sets.
        
        Args:
            series: Time series data
            
        Returns:
            Tuple of (train_series, test_series)
        """
        split_idx = int(len(series) * (1 - self.test_size))
        train = series.iloc[:split_idx]
        test = series.iloc[split_idx:]
        
        logger.info(f"Split data: {len(train)} train, {len(test)} test samples")
        return train, test
    
    def train_arima(self, train_series: pd.Series) -> ARIMAForecaster:
        """Train ARIMA model."""
        logger.info("Training ARIMA model...")
        model = ARIMAForecaster(max_p=5, max_d=2, max_q=5)
        model.fit(train_series)
        return model
    
    def train_prophet(self, train_series: pd.Series) -> ProphetForecaster:
        """Train Prophet model."""
        logger.info("Training Prophet model...")
        model = ProphetForecaster(
            yearly_seasonality=True,
            weekly_seasonality=True,
            daily_seasonality=False,
            seasonality_mode='multiplicative'
        )
        model.fit(train_series)
        return model
    
    def train_lstm(self, train_series: pd.Series) -> LSTMForecaster:
        """Train LSTM model."""
        logger.info("Training LSTM model...")
        model = LSTMForecaster(
            lookback=30,
            lstm_units=50,
            dropout=0.2,
            epochs=50,
            batch_size=32
        )
        model.fit(train_series, validation_split=0.2)
        return model
    
    def evaluate_models(
        self,
        series: pd.Series,
        models_to_test: Optional[List[str]] = None
    ) -> Dict:
        """
        Evaluate multiple models and select the best one.
        
        Args:
            series: Time series data
            models_to_test: List of model names to test. 
                          Options: ['arima', 'prophet', 'lstm']
                          If None, tests all models.
            
        Returns:
            Dictionary with evaluation results for all models
        """
        if models_to_test is None:
            models_to_test = ['arima', 'prophet', 'lstm']
        
        # Split data
        train, test = self.split_data(series)
        
        # Train and evaluate each model
        for model_name in models_to_test:
            try:
                if model_name == 'arima':
                    model = self.train_arima(train)
                    metrics = model.evaluate(test)
                    self.models['arima'] = model
                    self.evaluation_results['arima'] = metrics
                    
                elif model_name == 'prophet':
                    model = self.train_prophet(train)
                    metrics = model.evaluate(test)
                    self.models['prophet'] = model
                    self.evaluation_results['prophet'] = metrics
                    
                elif model_name == 'lstm':
                    model = self.train_lstm(train)
                    metrics = model.evaluate(test, train)
                    self.models['lstm'] = model
                    self.evaluation_results['lstm'] = metrics
                    
            except Exception as e:
                logger.error(f"Error training {model_name}: {str(e)}")
                self.evaluation_results[model_name] = {
                    'error': str(e),
                    'rmse': np.inf,
                    'mae': np.inf,
                    'mape': np.inf
                }
        
        # Select best model based on RMSE
        self._select_best_model()
        
        return self.evaluation_results
    
    def _select_best_model(self):
        """Select best model based on RMSE."""
        best_rmse = np.inf
        best_name = None
        
        for model_name, metrics in self.evaluation_results.items():
            if 'error' not in metrics and metrics['rmse'] < best_rmse:
                best_rmse = metrics['rmse']
                best_name = model_name
        
        if best_name:
            self.best_model_name = best_name
            self.best_model = self.models[best_name]
            logger.info(f"Best model: {best_name} with RMSE={best_rmse:.2f}")
        else:
            logger.warning("No valid model found")
    
    def get_best_model(self) -> tuple:
        """
        Get the best performing model.
        
        Returns:
            Tuple of (model_name, model_object)
        """
        if self.best_model is None:
            raise ValueError("No models have been evaluated yet")
        
        return self.best_model_name, self.best_model
    
    def forecast_with_best_model(
        self,
        series: pd.Series,
        steps: int,
        confidence_level: float = 0.95
    ) -> Dict:
        """
        Generate forecast using the best model.
        
        Args:
            series: Full time series data
            steps: Number of periods to forecast
            confidence_level: Confidence level for intervals
            
        Returns:
            Dictionary with forecast and metadata
        """
        if self.best_model is None:
            raise ValueError("No models have been evaluated yet")
        
        logger.info(f"Generating forecast with {self.best_model_name}...")
        
        # Retrain best model on full dataset
        if self.best_model_name == 'arima':
            self.best_model.fit(series)
            forecast = self.best_model.forecast(steps, confidence_level)
        elif self.best_model_name == 'prophet':
            self.best_model.fit(series)
            forecast = self.best_model.forecast(steps, freq='D', confidence_level=confidence_level)
        elif self.best_model_name == 'lstm':
            self.best_model.fit(series)
            forecast = self.best_model.forecast(series, steps)
        
        # Add evaluation metrics
        forecast['evaluation_metrics'] = self.evaluation_results[self.best_model_name]
        forecast['selected_model'] = self.best_model_name
        
        return forecast
    
    def get_model_comparison(self) -> pd.DataFrame:
        """
        Get comparison table of all models.
        
        Returns:
            DataFrame with model comparison
        """
        if not self.evaluation_results:
            return pd.DataFrame()
        
        comparison = []
        for model_name, metrics in self.evaluation_results.items():
            if 'error' not in metrics:
                comparison.append({
                    'model': model_name,
                    'rmse': metrics['rmse'],
                    'mae': metrics['mae'],
                    'mape': metrics['mape'],
                    'is_best': model_name == self.best_model_name
                })
        
        df = pd.DataFrame(comparison)
        if not df.empty:
            df = df.sort_values('rmse')
        
        return df
