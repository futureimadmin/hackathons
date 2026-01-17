"""
Evaluation Metrics

Provides functions for calculating forecasting accuracy metrics.
"""

import numpy as np
import pandas as pd
from typing import Dict, Union


def calculate_rmse(actual: Union[np.ndarray, pd.Series], predicted: Union[np.ndarray, pd.Series]) -> float:
    """
    Calculate Root Mean Squared Error.
    
    Args:
        actual: Actual values
        predicted: Predicted values
        
    Returns:
        RMSE value
    """
    return float(np.sqrt(np.mean((actual - predicted) ** 2)))


def calculate_mae(actual: Union[np.ndarray, pd.Series], predicted: Union[np.ndarray, pd.Series]) -> float:
    """
    Calculate Mean Absolute Error.
    
    Args:
        actual: Actual values
        predicted: Predicted values
        
    Returns:
        MAE value
    """
    return float(np.mean(np.abs(actual - predicted)))


def calculate_mape(actual: Union[np.ndarray, pd.Series], predicted: Union[np.ndarray, pd.Series]) -> float:
    """
    Calculate Mean Absolute Percentage Error.
    
    Args:
        actual: Actual values
        predicted: Predicted values
        
    Returns:
        MAPE value (as percentage)
    """
    # Avoid division by zero
    mask = actual != 0
    return float(np.mean(np.abs((actual[mask] - predicted[mask]) / actual[mask])) * 100)


def calculate_smape(actual: Union[np.ndarray, pd.Series], predicted: Union[np.ndarray, pd.Series]) -> float:
    """
    Calculate Symmetric Mean Absolute Percentage Error.
    
    Args:
        actual: Actual values
        predicted: Predicted values
        
    Returns:
        SMAPE value (as percentage)
    """
    numerator = np.abs(actual - predicted)
    denominator = (np.abs(actual) + np.abs(predicted)) / 2
    
    # Avoid division by zero
    mask = denominator != 0
    return float(np.mean(numerator[mask] / denominator[mask]) * 100)


def calculate_r2(actual: Union[np.ndarray, pd.Series], predicted: Union[np.ndarray, pd.Series]) -> float:
    """
    Calculate R-squared (coefficient of determination).
    
    Args:
        actual: Actual values
        predicted: Predicted values
        
    Returns:
        R-squared value
    """
    ss_res = np.sum((actual - predicted) ** 2)
    ss_tot = np.sum((actual - np.mean(actual)) ** 2)
    
    if ss_tot == 0:
        return 0.0
    
    return float(1 - (ss_res / ss_tot))


def calculate_all_metrics(
    actual: Union[np.ndarray, pd.Series],
    predicted: Union[np.ndarray, pd.Series]
) -> Dict[str, float]:
    """
    Calculate all evaluation metrics.
    
    Args:
        actual: Actual values
        predicted: Predicted values
        
    Returns:
        Dictionary with all metrics
    """
    return {
        'rmse': calculate_rmse(actual, predicted),
        'mae': calculate_mae(actual, predicted),
        'mape': calculate_mape(actual, predicted),
        'smape': calculate_smape(actual, predicted),
        'r2': calculate_r2(actual, predicted)
    }


def calculate_forecast_accuracy(
    actual: Union[np.ndarray, pd.Series],
    predicted: Union[np.ndarray, pd.Series],
    lower_bound: Union[np.ndarray, pd.Series],
    upper_bound: Union[np.ndarray, pd.Series]
) -> Dict[str, float]:
    """
    Calculate forecast accuracy including confidence interval coverage.
    
    Args:
        actual: Actual values
        predicted: Predicted values
        lower_bound: Lower confidence bound
        upper_bound: Upper confidence bound
        
    Returns:
        Dictionary with accuracy metrics
    """
    metrics = calculate_all_metrics(actual, predicted)
    
    # Calculate coverage (percentage of actuals within confidence interval)
    within_interval = (actual >= lower_bound) & (actual <= upper_bound)
    coverage = float(np.mean(within_interval) * 100)
    
    # Calculate average interval width
    avg_interval_width = float(np.mean(upper_bound - lower_bound))
    
    metrics['coverage'] = coverage
    metrics['avg_interval_width'] = avg_interval_width
    
    return metrics
