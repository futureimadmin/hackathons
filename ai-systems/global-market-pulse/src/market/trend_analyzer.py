"""
Market Trend Analysis Module

Performs time series decomposition, trend detection, and seasonality analysis
for global and regional market trends.
"""

import pandas as pd
import numpy as np
from typing import Dict, List, Tuple, Any
from datetime import datetime, timedelta
from scipy import stats
from statsmodels.tsa.seasonal import seasonal_decompose
from statsmodels.tsa.stattools import adfuller
import logging

logger = logging.getLogger(__name__)


class TrendAnalyzer:
    """
    Analyzes market trends using time series decomposition and statistical methods.
    """
    
    def __init__(self):
        """Initialize the trend analyzer."""
        self.min_data_points = 14  # Minimum data points for analysis
    
    def analyze_trends(self, data: pd.DataFrame, 
                      date_column: str = 'date',
                      value_column: str = 'value',
                      region_column: str = None) -> Dict[str, Any]:
        """
        Analyze market trends with time series decomposition.
        
        Args:
            data: DataFrame with time series data
            date_column: Name of date column
            value_column: Name of value column
            region_column: Optional region column for regional analysis
        
        Returns:
            Dictionary with trend analysis results
        """
        try:
            # Ensure date column is datetime
            data = data.copy()
            data[date_column] = pd.to_datetime(data[date_column])
            data = data.sort_values(date_column)
            
            if region_column:
                # Analyze by region
                results = {}
                for region in data[region_column].unique():
                    region_data = data[data[region_column] == region]
                    results[region] = self._analyze_single_series(
                        region_data, date_column, value_column
                    )
                return {'regional_trends': results}
            else:
                # Analyze overall
                return self._analyze_single_series(data, date_column, value_column)
        
        except Exception as e:
            logger.error(f"Error analyzing trends: {str(e)}")
            raise
    
    def _analyze_single_series(self, data: pd.DataFrame,
                               date_column: str,
                               value_column: str) -> Dict[str, Any]:
        """Analyze a single time series."""
        if len(data) < self.min_data_points:
            return {
                'error': f'Insufficient data points (need at least {self.min_data_points})',
                'data_points': len(data)
            }
        
        # Set date as index
        ts_data = data.set_index(date_column)[value_column]
        
        # Perform decomposition
        decomposition = self._decompose_series(ts_data)
        
        # Detect trend direction
        trend_info = self._detect_trend_direction(decomposition['trend'])
        
        # Analyze seasonality
        seasonality_info = self._analyze_seasonality(decomposition['seasonal'])
        
        # Test for stationarity
        stationarity = self._test_stationarity(ts_data)
        
        # Calculate growth metrics
        growth_metrics = self._calculate_growth_metrics(ts_data)
        
        return {
            'decomposition': decomposition,
            'trend': trend_info,
            'seasonality': seasonality_info,
            'stationarity': stationarity,
            'growth_metrics': growth_metrics,
            'data_points': len(data),
            'date_range': {
                'start': data[date_column].min().isoformat(),
                'end': data[date_column].max().isoformat()
            }
        }
    
    def _decompose_series(self, ts_data: pd.Series) -> Dict[str, Any]:
        """Decompose time series into trend, seasonal, and residual components."""
        try:
            # Determine period (weekly = 7, monthly = 30)
            period = min(7, len(ts_data) // 2)
            
            if len(ts_data) >= 2 * period:
                decomp = seasonal_decompose(ts_data, model='additive', period=period, extrapolate_trend='freq')
                
                return {
                    'trend': decomp.trend.dropna().tolist(),
                    'seasonal': decomp.seasonal.dropna().tolist(),
                    'residual': decomp.resid.dropna().tolist(),
                    'observed': ts_data.tolist(),
                    'dates': ts_data.index.astype(str).tolist()
                }
            else:
                return {
                    'trend': ts_data.tolist(),
                    'seasonal': [0] * len(ts_data),
                    'residual': [0] * len(ts_data),
                    'observed': ts_data.tolist(),
                    'dates': ts_data.index.astype(str).tolist(),
                    'note': 'Insufficient data for full decomposition'
                }
        except Exception as e:
            logger.warning(f"Decomposition failed: {str(e)}")
            return {
                'trend': ts_data.tolist(),
                'seasonal': [0] * len(ts_data),
                'residual': [0] * len(ts_data),
                'observed': ts_data.tolist(),
                'dates': ts_data.index.astype(str).tolist(),
                'error': str(e)
            }
    
    def _detect_trend_direction(self, trend: List[float]) -> Dict[str, Any]:
        """Detect trend direction and strength."""
        if not trend or len(trend) < 2:
            return {'direction': 'unknown', 'strength': 0}
        
        # Remove NaN values
        trend_clean = [x for x in trend if not pd.isna(x)]
        
        if len(trend_clean) < 2:
            return {'direction': 'unknown', 'strength': 0}
        
        # Calculate linear regression
        x = np.arange(len(trend_clean))
        y = np.array(trend_clean)
        
        slope, intercept, r_value, p_value, std_err = stats.linregress(x, y)
        
        # Determine direction
        if abs(slope) < std_err:
            direction = 'stable'
        elif slope > 0:
            direction = 'increasing'
        else:
            direction = 'decreasing'
        
        # Calculate strength (R-squared)
        strength = r_value ** 2
        
        # Calculate percentage change
        pct_change = ((trend_clean[-1] - trend_clean[0]) / trend_clean[0] * 100) if trend_clean[0] != 0 else 0
        
        return {
            'direction': direction,
            'strength': float(strength),
            'slope': float(slope),
            'r_squared': float(r_value ** 2),
            'p_value': float(p_value),
            'percentage_change': float(pct_change),
            'start_value': float(trend_clean[0]),
            'end_value': float(trend_clean[-1])
        }
    
    def _analyze_seasonality(self, seasonal: List[float]) -> Dict[str, Any]:
        """Analyze seasonality patterns."""
        if not seasonal:
            return {'has_seasonality': False}
        
        # Remove NaN values
        seasonal_clean = [x for x in seasonal if not pd.isna(x)]
        
        if len(seasonal_clean) < 2:
            return {'has_seasonality': False}
        
        # Calculate seasonality strength
        seasonal_variance = np.var(seasonal_clean)
        has_seasonality = seasonal_variance > 0.01
        
        # Find peaks and troughs
        seasonal_array = np.array(seasonal_clean)
        peaks = []
        troughs = []
        
        for i in range(1, len(seasonal_array) - 1):
            if seasonal_array[i] > seasonal_array[i-1] and seasonal_array[i] > seasonal_array[i+1]:
                peaks.append(i)
            elif seasonal_array[i] < seasonal_array[i-1] and seasonal_array[i] < seasonal_array[i+1]:
                troughs.append(i)
        
        return {
            'has_seasonality': bool(has_seasonality),
            'variance': float(seasonal_variance),
            'amplitude': float(np.max(seasonal_clean) - np.min(seasonal_clean)),
            'peak_count': len(peaks),
            'trough_count': len(troughs),
            'max_value': float(np.max(seasonal_clean)),
            'min_value': float(np.min(seasonal_clean))
        }
    
    def _test_stationarity(self, ts_data: pd.Series) -> Dict[str, Any]:
        """Test time series for stationarity using Augmented Dickey-Fuller test."""
        try:
            # Remove NaN values
            ts_clean = ts_data.dropna()
            
            if len(ts_clean) < 3:
                return {'is_stationary': False, 'note': 'Insufficient data'}
            
            # Perform ADF test
            adf_result = adfuller(ts_clean, autolag='AIC')
            
            is_stationary = adf_result[1] < 0.05  # p-value < 0.05
            
            return {
                'is_stationary': bool(is_stationary),
                'adf_statistic': float(adf_result[0]),
                'p_value': float(adf_result[1]),
                'critical_values': {
                    '1%': float(adf_result[4]['1%']),
                    '5%': float(adf_result[4]['5%']),
                    '10%': float(adf_result[4]['10%'])
                }
            }
        except Exception as e:
            logger.warning(f"Stationarity test failed: {str(e)}")
            return {'is_stationary': False, 'error': str(e)}
    
    def _calculate_growth_metrics(self, ts_data: pd.Series) -> Dict[str, Any]:
        """Calculate growth metrics."""
        if len(ts_data) < 2:
            return {}
        
        # Calculate various growth metrics
        values = ts_data.values
        
        # Overall growth
        total_growth = ((values[-1] - values[0]) / values[0] * 100) if values[0] != 0 else 0
        
        # Average period-over-period growth
        pct_changes = ts_data.pct_change().dropna()
        avg_growth = pct_changes.mean() * 100 if len(pct_changes) > 0 else 0
        
        # Volatility (standard deviation of returns)
        volatility = pct_changes.std() * 100 if len(pct_changes) > 0 else 0
        
        # Compound annual growth rate (CAGR) approximation
        periods = len(ts_data)
        cagr = (((values[-1] / values[0]) ** (1 / periods)) - 1) * 100 if values[0] > 0 else 0
        
        return {
            'total_growth_pct': float(total_growth),
            'avg_period_growth_pct': float(avg_growth),
            'volatility_pct': float(volatility),
            'cagr_pct': float(cagr),
            'min_value': float(np.min(values)),
            'max_value': float(np.max(values)),
            'mean_value': float(np.mean(values)),
            'median_value': float(np.median(values))
        }
    
    def detect_trend_changes(self, data: pd.DataFrame,
                            date_column: str = 'date',
                            value_column: str = 'value',
                            window: int = 7) -> List[Dict[str, Any]]:
        """
        Detect significant trend changes (breakpoints).
        
        Args:
            data: DataFrame with time series data
            date_column: Name of date column
            value_column: Name of value column
            window: Window size for trend calculation
        
        Returns:
            List of detected trend changes
        """
        try:
            data = data.copy()
            data[date_column] = pd.to_datetime(data[date_column])
            data = data.sort_values(date_column)
            
            # Calculate rolling trends
            data['rolling_mean'] = data[value_column].rolling(window=window).mean()
            data['rolling_std'] = data[value_column].rolling(window=window).std()
            
            # Detect changes
            changes = []
            for i in range(window, len(data) - window):
                before = data.iloc[i-window:i][value_column].mean()
                after = data.iloc[i:i+window][value_column].mean()
                std = data.iloc[i]['rolling_std']
                
                if pd.notna(std) and std > 0:
                    # Z-score for change
                    z_score = abs(after - before) / std
                    
                    if z_score > 2:  # Significant change
                        changes.append({
                            'date': data.iloc[i][date_column].isoformat(),
                            'index': i,
                            'before_mean': float(before),
                            'after_mean': float(after),
                            'change_pct': float((after - before) / before * 100) if before != 0 else 0,
                            'z_score': float(z_score),
                            'significance': 'high' if z_score > 3 else 'medium'
                        })
            
            return changes
        
        except Exception as e:
            logger.error(f"Error detecting trend changes: {str(e)}")
            return []
