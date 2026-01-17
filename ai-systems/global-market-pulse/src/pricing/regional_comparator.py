"""
Regional Price Comparison Module

Compares prices across regions with statistical significance tests
and currency normalization.
"""

import pandas as pd
import numpy as np
from typing import Dict, List, Any, Optional
from scipy import stats
import logging

logger = logging.getLogger(__name__)


class RegionalComparator:
    """
    Compares prices across regions with statistical analysis.
    """
    
    def __init__(self):
        """Initialize the regional comparator."""
        # Currency exchange rates (USD as base)
        self.exchange_rates = {
            'USD': 1.0,
            'EUR': 1.08,
            'GBP': 1.27,
            'JPY': 0.0067,
            'CNY': 0.14,
            'INR': 0.012,
            'CAD': 0.74,
            'AUD': 0.66,
            'BRL': 0.20,
            'MXN': 0.058
        }
    
    def compare_regional_prices(self, data: pd.DataFrame,
                               region_column: str = 'region',
                               price_column: str = 'price',
                               currency_column: str = 'currency',
                               product_column: str = 'product_id') -> Dict[str, Any]:
        """
        Compare prices across regions.
        
        Args:
            data: DataFrame with regional price data
            region_column: Name of region column
            price_column: Name of price column
            currency_column: Name of currency column
            product_column: Name of product column
        
        Returns:
            Dictionary with comparison results
        """
        try:
            # Normalize prices to USD
            data = data.copy()
            data['price_usd'] = data.apply(
                lambda row: self._convert_to_usd(row[price_column], row[currency_column]),
                axis=1
            )
            
            # Calculate regional statistics
            regional_stats = self._calculate_regional_stats(
                data, region_column, 'price_usd', product_column
            )
            
            # Perform pairwise comparisons
            pairwise_comparisons = self._pairwise_comparisons(
                data, region_column, 'price_usd'
            )
            
            # Identify price outliers
            outliers = self._identify_outliers(
                data, region_column, 'price_usd', product_column
            )
            
            # Calculate price dispersion
            dispersion = self._calculate_price_dispersion(
                data, region_column, 'price_usd'
            )
            
            return {
                'regional_statistics': regional_stats,
                'pairwise_comparisons': pairwise_comparisons,
                'outliers': outliers,
                'price_dispersion': dispersion,
                'total_regions': len(data[region_column].unique()),
                'total_products': len(data[product_column].unique()) if product_column in data.columns else 0
            }
        
        except Exception as e:
            logger.error(f"Error comparing regional prices: {str(e)}")
            raise
    
    def _convert_to_usd(self, price: float, currency: str) -> float:
        """Convert price to USD."""
        if pd.isna(price) or pd.isna(currency):
            return np.nan
        
        rate = self.exchange_rates.get(currency.upper(), 1.0)
        return price * rate
    
    def _calculate_regional_stats(self, data: pd.DataFrame,
                                  region_column: str,
                                  price_column: str,
                                  product_column: str) -> List[Dict[str, Any]]:
        """Calculate statistics for each region."""
        stats_list = []
        
        for region in data[region_column].unique():
            region_data = data[data[region_column] == region][price_column].dropna()
            
            if len(region_data) == 0:
                continue
            
            stats_list.append({
                'region': region,
                'mean_price': float(region_data.mean()),
                'median_price': float(region_data.median()),
                'std_dev': float(region_data.std()),
                'min_price': float(region_data.min()),
                'max_price': float(region_data.max()),
                'count': int(len(region_data)),
                'coefficient_of_variation': float(region_data.std() / region_data.mean()) if region_data.mean() > 0 else 0
            })
        
        # Sort by mean price
        stats_list.sort(key=lambda x: x['mean_price'], reverse=True)
        
        return stats_list
    
    def _pairwise_comparisons(self, data: pd.DataFrame,
                             region_column: str,
                             price_column: str) -> List[Dict[str, Any]]:
        """Perform pairwise statistical comparisons between regions."""
        regions = data[region_column].unique()
        comparisons = []
        
        for i, region1 in enumerate(regions):
            for region2 in regions[i+1:]:
                prices1 = data[data[region_column] == region1][price_column].dropna()
                prices2 = data[data[region_column] == region2][price_column].dropna()
                
                if len(prices1) < 2 or len(prices2) < 2:
                    continue
                
                # Perform t-test
                t_stat, p_value = stats.ttest_ind(prices1, prices2)
                
                # Calculate effect size (Cohen's d)
                pooled_std = np.sqrt((prices1.std()**2 + prices2.std()**2) / 2)
                cohens_d = (prices1.mean() - prices2.mean()) / pooled_std if pooled_std > 0 else 0
                
                # Determine significance
                is_significant = p_value < 0.05
                
                # Calculate price difference
                price_diff = prices1.mean() - prices2.mean()
                price_diff_pct = (price_diff / prices2.mean() * 100) if prices2.mean() > 0 else 0
                
                comparisons.append({
                    'region1': region1,
                    'region2': region2,
                    'region1_mean': float(prices1.mean()),
                    'region2_mean': float(prices2.mean()),
                    'price_difference': float(price_diff),
                    'price_difference_pct': float(price_diff_pct),
                    't_statistic': float(t_stat),
                    'p_value': float(p_value),
                    'is_significant': bool(is_significant),
                    'cohens_d': float(cohens_d),
                    'effect_size': self._interpret_effect_size(cohens_d)
                })
        
        # Sort by absolute price difference
        comparisons.sort(key=lambda x: abs(x['price_difference']), reverse=True)
        
        return comparisons
    
    def _interpret_effect_size(self, cohens_d: float) -> str:
        """Interpret Cohen's d effect size."""
        abs_d = abs(cohens_d)
        if abs_d < 0.2:
            return 'negligible'
        elif abs_d < 0.5:
            return 'small'
        elif abs_d < 0.8:
            return 'medium'
        else:
            return 'large'
    
    def _identify_outliers(self, data: pd.DataFrame,
                          region_column: str,
                          price_column: str,
                          product_column: str) -> List[Dict[str, Any]]:
        """Identify price outliers within each region."""
        outliers = []
        
        for region in data[region_column].unique():
            region_data = data[data[region_column] == region].copy()
            prices = region_data[price_column].dropna()
            
            if len(prices) < 4:
                continue
            
            # Calculate IQR
            Q1 = prices.quantile(0.25)
            Q3 = prices.quantile(0.75)
            IQR = Q3 - Q1
            
            # Define outlier bounds
            lower_bound = Q1 - 1.5 * IQR
            upper_bound = Q3 + 1.5 * IQR
            
            # Find outliers
            region_outliers = region_data[
                (region_data[price_column] < lower_bound) | 
                (region_data[price_column] > upper_bound)
            ]
            
            for _, row in region_outliers.iterrows():
                outliers.append({
                    'region': region,
                    'product_id': row[product_column] if product_column in row else 'unknown',
                    'price': float(row[price_column]),
                    'mean_price': float(prices.mean()),
                    'deviation_from_mean': float(row[price_column] - prices.mean()),
                    'z_score': float((row[price_column] - prices.mean()) / prices.std()) if prices.std() > 0 else 0,
                    'outlier_type': 'high' if row[price_column] > upper_bound else 'low'
                })
        
        return outliers
    
    def _calculate_price_dispersion(self, data: pd.DataFrame,
                                   region_column: str,
                                   price_column: str) -> Dict[str, Any]:
        """Calculate overall price dispersion metrics."""
        all_prices = data[price_column].dropna()
        
        if len(all_prices) == 0:
            return {}
        
        # Calculate dispersion metrics
        price_range = all_prices.max() - all_prices.min()
        cv = all_prices.std() / all_prices.mean() if all_prices.mean() > 0 else 0
        
        # Calculate Gini coefficient
        gini = self._calculate_gini(all_prices.values)
        
        return {
            'overall_mean': float(all_prices.mean()),
            'overall_std': float(all_prices.std()),
            'price_range': float(price_range),
            'coefficient_of_variation': float(cv),
            'gini_coefficient': float(gini),
            'min_price': float(all_prices.min()),
            'max_price': float(all_prices.max()),
            'price_spread_pct': float(price_range / all_prices.mean() * 100) if all_prices.mean() > 0 else 0
        }
    
    def _calculate_gini(self, values: np.ndarray) -> float:
        """Calculate Gini coefficient for price inequality."""
        if len(values) == 0:
            return 0.0
        
        sorted_values = np.sort(values)
        n = len(values)
        cumsum = np.cumsum(sorted_values)
        
        return (2 * np.sum((np.arange(1, n + 1)) * sorted_values)) / (n * cumsum[-1]) - (n + 1) / n
    
    def analyze_currency_impact(self, data: pd.DataFrame,
                                region_column: str = 'region',
                                price_column: str = 'price',
                                currency_column: str = 'currency') -> Dict[str, Any]:
        """
        Analyze the impact of currency exchange rates on regional pricing.
        
        Args:
            data: DataFrame with regional price data
            region_column: Name of region column
            price_column: Name of price column
            currency_column: Name of currency column
        
        Returns:
            Dictionary with currency impact analysis
        """
        try:
            data = data.copy()
            
            # Group by currency
            currency_stats = []
            for currency in data[currency_column].unique():
                currency_data = data[data[currency_column] == currency]
                prices = currency_data[price_column].dropna()
                
                if len(prices) == 0:
                    continue
                
                # Convert to USD
                exchange_rate = self.exchange_rates.get(currency.upper(), 1.0)
                prices_usd = prices * exchange_rate
                
                currency_stats.append({
                    'currency': currency,
                    'exchange_rate_to_usd': float(exchange_rate),
                    'avg_price_local': float(prices.mean()),
                    'avg_price_usd': float(prices_usd.mean()),
                    'regions': list(currency_data[region_column].unique()),
                    'count': int(len(prices))
                })
            
            return {
                'currency_statistics': currency_stats,
                'total_currencies': len(currency_stats)
            }
        
        except Exception as e:
            logger.error(f"Error analyzing currency impact: {str(e)}")
            raise
