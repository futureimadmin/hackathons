"""
ARIMA Forecasting Model

Implements ARIMA (AutoRegressive Integrated Moving Average) for time series forecasting.
Includes automatic parameter selection using AIC.
"""

import pandas as pd
import numpy as np
from statsmodels.tsa.arima.model import ARIMA
from statsmodels.tsa.stattools import adfuller
from statsmodels.graphics.tsaplots import plot_acf, plot_pacf
import warnings
import logging
from typing import Dict, List, Tuple, Optional

warnings.filterwarnings('ignore')
logger = logging.getLogger(__name__)


class ARIMAForecaster:
    """ARIMA forecasting model with automatic parameter selection."""
    
    def __init__(self, max_p: int = 5, max_d: int = 2, max_q: int = 5):
        """
        Initialize ARIMA forecaster.
        
        Args:
            max_p: Maximum AR order to test
            max_d: Maximum differencing order to test
            max_q: Maximum MA order to test
        """
        self.max_p = max_p
        self.max_d = max_d
        self.max_q = max_q
        self.model = None
        self.best_params = None
        self.best_aic = np.inf
        
    def check_stationarity(self, series: pd.Series) -> Tuple[bool, int]:
        """
        Check if series is stationary using Augmented Dickey-Fuller test.
        
        Args:
            series: Time series data
            
        Returns:
            Tuple of (is_stationary, suggested_d)
        """
        result = adfuller(series.dropna())
        p_value = result[1]
        
        is_stationary = p_value < 0.05
        suggested_d = 0 if is_stationary else 1
        
        logger.info(f"ADF test p-value: {p_value:.4f}, Stationary: {is_stationary}")
        return is_stationary, suggested_d
    
    def find_best_params(self, series: pd.Series) -> Tuple[int, int, int]:
        """
        Find best ARIMA parameters using grid search with AIC.
        
        Args:
            series: Time series data
            
        Returns:
            Tuple of (p, d, q) parameters
        """
        logger.info("Starting ARIMA parameter search...")
        
        # Check stationarity to determine d
        _, suggested_d = self.check_stationarity(series)
        
        best_aic = np.inf
        best_params = (1, suggested_d, 1)
        
        # Grid search
        for p in range(self.max_p + 1):
            for d in range(min(suggested_d + 1, self.max_d + 1)):
                for q in range(self.max_q + 1):
                    try:
                        model = ARIMA(series, order=(p, d, q))
                        fitted = model.fit()
                        aic = fitted.aic
                        
                        if aic < best_aic:
                            best_aic = aic
                            best_params = (p, d, q)
                            logger.info(f"New best: ({p},{d},{q}) AIC={aic:.2f}")
                    except:
                        continue
        
        self.best_params = best_params
        self.best_aic = best_aic
        logger.info(f"Best parameters: {best_params}, AIC: {best_aic:.2f}")
        
        return best_params
    
    def fit(self, series: pd.Series, order: Optional[Tuple[int, int, int]] = None):
        """
        Fit ARIMA model to time series data.
        
        Args:
            series: Time series data
            order: Optional (p,d,q) parameters. If None, will auto-select.
        """
        if order is None:
            order = self.find_best_params(series)
        
        logger.info(f"Fitting ARIMA{order} model...")
        self.model = ARIMA(series, order=order)
        self.fitted_model = self.model.fit()
        self.best_params = order
        
        logger.info(f"Model fitted. AIC: {self.fitted_model.aic:.2f}")
    
    def forecast(self, steps: int, confidence_level: float = 0.95) -> Dict:
        """
        Generate forecast with confidence intervals.
        
        Args:
            steps: Number of periods to forecast
            confidence_level: Confidence level for intervals (default 0.95)
            
        Returns:
            Dictionary with forecast, lower_bound, upper_bound
        """
        if self.fitted_model is None:
            raise ValueError("Model must be fitted before forecasting")
        
        logger.info(f"Generating {steps}-step forecast...")
        
        # Get forecast
        forecast_result = self.fitted_model.forecast(steps=steps)
        
        # Get confidence intervals
        forecast_df = self.fitted_model.get_forecast(steps=steps)
        conf_int = forecast_df.conf_int(alpha=1-confidence_level)
        
        result = {
            'forecast': forecast_result.tolist(),
            'lower_bound': conf_int.iloc[:, 0].tolist(),
            'upper_bound': conf_int.iloc[:, 1].tolist(),
            'model': 'ARIMA',
            'params': self.best_params,
            'aic': self.fitted_model.aic,
            'confidence_level': confidence_level
        }
        
        return result
    
    def evaluate(self, test_series: pd.Series) -> Dict:
        """
        Evaluate model performance on test data.
        
        Args:
            test_series: Test time series data
            
        Returns:
            Dictionary with RMSE, MAE, MAPE metrics
        """
        if self.fitted_model is None:
            raise ValueError("Model must be fitted before evaluation")
        
        # Generate predictions
        predictions = self.fitted_model.forecast(steps=len(test_series))
        
        # Calculate metrics
        rmse = np.sqrt(np.mean((test_series - predictions) ** 2))
        mae = np.mean(np.abs(test_series - predictions))
        mape = np.mean(np.abs((test_series - predictions) / test_series)) * 100
        
        metrics = {
            'rmse': float(rmse),
            'mae': float(mae),
            'mape': float(mape)
        }
        
        logger.info(f"Evaluation metrics: RMSE={rmse:.2f}, MAE={mae:.2f}, MAPE={mape:.2f}%")
        return metrics
    
    def get_model_summary(self) -> str:
        """Get model summary statistics."""
        if self.fitted_model is None:
            return "Model not fitted"
        
        return str(self.fitted_model.summary())
