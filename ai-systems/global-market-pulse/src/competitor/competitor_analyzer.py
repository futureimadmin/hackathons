"""
Competitor Analysis Module

Analyzes competitor pricing, market share, and competitive positioning across regions.
"""

import pandas as pd
import numpy as np
from typing import Dict, List, Any, Optional
import logging

logger = logging.getLogger(__name__)


class CompetitorAnalyzer:
    """
    Analyzes competitor data across regions.
    """
    
    def __init__(self):
        """Initialize the competitor analyzer."""
        pass
    
    def analyze_competitor_pricing(self, data: pd.DataFrame,
                                   competitor_column: str = 'competitor',
                                   price_column: str = 'price',
                                   region_column: str = 'region',
                                   product_column: str = 'product_id') -> Dict[str, Any]:
        """
        Analyze competitor pricing strategies.
        
        Args:
            data: DataFrame with competitor pricing data
            competitor_column: Name of competitor column
            price_column: Name of price column
            region_column: Name of region column
            product_column: Name of product column
        
        Returns:
            Dictionary with competitor pricing analysis
        """
        try:
            # Calculate competitor statistics
            competitor_stats = self._calculate_competitor_stats(
                data, competitor_column, price_column, region_column
            )
            
            # Identify price leaders
            price_leaders = self._identify_price_leaders(
                data, competitor_column, price_column, region_column
            )
            
            # Calculate price positioning
            price_positioning = self._calculate_price_positioning(
                data, competitor_column, price_column
            )
            
            # Analyze regional strategies
            regional_strategies = self._analyze_regional_strategies(
                data, competitor_column, price_column, region_column
            )
            
            return {
                'competitor_statistics': competitor_stats,
                'price_leaders': price_leaders,
                'price_positioning': price_positioning,
                'regional_strategies': regional_strategies,
                'total_competitors': len(data[competitor_column].unique()),
                'total_regions': len(data[region_column].unique())
            }
        
        except Exception as e:
            logger.error(f"Error analyzing competitor pricing: {str(e)}")
            raise
    
    def _calculate_competitor_stats(self, data: pd.DataFrame,
                                    competitor_column: str,
                                    price_column: str,
                                    region_column: str) -> List[Dict[str, Any]]:
        """Calculate statistics for each competitor."""
        stats_list = []
        
        for competitor in data[competitor_column].unique():
            comp_data = data[data[competitor_column] == competitor]
            prices = comp_data[price_column].dropna()
            
            if len(prices) == 0:
                continue
            
            stats_list.append({
                'competitor': competitor,
                'avg_price': float(prices.mean()),
                'median_price': float(prices.median()),
                'min_price': float(prices.min()),
                'max_price': float(prices.max()),
                'price_std': float(prices.std()),
                'regions_present': int(comp_data[region_column].nunique()),
                'total_products': int(len(comp_data))
            })
        
        # Sort by average price
        stats_list.sort(key=lambda x: x['avg_price'])
        
        return stats_list
    
    def _identify_price_leaders(self, data: pd.DataFrame,
                               competitor_column: str,
                               price_column: str,
                               region_column: str) -> Dict[str, Any]:
        """Identify price leaders (lowest and highest) by region."""
        leaders = {
            'by_region': [],
            'overall': {}
        }
        
        # Overall leaders
        competitor_avg = data.groupby(competitor_column)[price_column].mean()
        leaders['overall'] = {
            'lowest_price_competitor': competitor_avg.idxmin(),
            'lowest_avg_price': float(competitor_avg.min()),
            'highest_price_competitor': competitor_avg.idxmax(),
            'highest_avg_price': float(competitor_avg.max())
        }
        
        # Regional leaders
        for region in data[region_column].unique():
            region_data = data[data[region_column] == region]
            region_avg = region_data.groupby(competitor_column)[price_column].mean()
            
            if len(region_avg) == 0:
                continue
            
            leaders['by_region'].append({
                'region': region,
                'lowest_price_competitor': region_avg.idxmin(),
                'lowest_avg_price': float(region_avg.min()),
                'highest_price_competitor': region_avg.idxmax(),
                'highest_avg_price': float(region_avg.max()),
                'price_spread': float(region_avg.max() - region_avg.min())
            })
        
        return leaders
    
    def _calculate_price_positioning(self, data: pd.DataFrame,
                                    competitor_column: str,
                                    price_column: str) -> List[Dict[str, Any]]:
        """Calculate price positioning relative to market average."""
        market_avg = data[price_column].mean()
        
        positioning = []
        for competitor in data[competitor_column].unique():
            comp_prices = data[data[competitor_column] == competitor][price_column]
            comp_avg = comp_prices.mean()
            
            # Calculate positioning
            diff_from_market = comp_avg - market_avg
            diff_pct = (diff_from_market / market_avg * 100) if market_avg > 0 else 0
            
            # Categorize positioning
            if diff_pct < -10:
                position = 'Budget'
            elif diff_pct < -5:
                position = 'Value'
            elif diff_pct < 5:
                position = 'Market'
            elif diff_pct < 10:
                position = 'Premium'
            else:
                position = 'Luxury'
            
            positioning.append({
                'competitor': competitor,
                'avg_price': float(comp_avg),
                'market_avg_price': float(market_avg),
                'difference_from_market': float(diff_from_market),
                'difference_pct': float(diff_pct),
                'positioning': position
            })
        
        # Sort by price
        positioning.sort(key=lambda x: x['avg_price'])
        
        return positioning
    
    def _analyze_regional_strategies(self, data: pd.DataFrame,
                                    competitor_column: str,
                                    price_column: str,
                                    region_column: str) -> List[Dict[str, Any]]:
        """Analyze pricing strategies across regions for each competitor."""
        strategies = []
        
        for competitor in data[competitor_column].unique():
            comp_data = data[data[competitor_column] == competitor]
            
            # Calculate regional prices
            regional_prices = comp_data.groupby(region_column)[price_column].mean()
            
            if len(regional_prices) < 2:
                continue
            
            # Calculate price variation
            price_cv = regional_prices.std() / regional_prices.mean() if regional_prices.mean() > 0 else 0
            
            # Determine strategy
            if price_cv < 0.05:
                strategy = 'Uniform Pricing'
            elif price_cv < 0.15:
                strategy = 'Moderate Variation'
            else:
                strategy = 'Regional Pricing'
            
            strategies.append({
                'competitor': competitor,
                'regions_count': int(len(regional_prices)),
                'avg_price': float(regional_prices.mean()),
                'price_std': float(regional_prices.std()),
                'coefficient_of_variation': float(price_cv),
                'min_regional_price': float(regional_prices.min()),
                'max_regional_price': float(regional_prices.max()),
                'pricing_strategy': strategy
            })
        
        return strategies
    
    def analyze_market_share(self, data: pd.DataFrame,
                            competitor_column: str = 'competitor',
                            sales_column: str = 'sales',
                            region_column: str = 'region') -> Dict[str, Any]:
        """
        Analyze market share by competitor and region.
        
        Args:
            data: DataFrame with sales data
            competitor_column: Name of competitor column
            sales_column: Name of sales column
            region_column: Name of region column
        
        Returns:
            Dictionary with market share analysis
        """
        try:
            # Overall market share
            total_sales = data[sales_column].sum()
            overall_share = data.groupby(competitor_column)[sales_column].sum() / total_sales * 100
            
            overall_market_share = []
            for competitor, share in overall_share.items():
                overall_market_share.append({
                    'competitor': competitor,
                    'market_share_pct': float(share),
                    'total_sales': float(data[data[competitor_column] == competitor][sales_column].sum())
                })
            
            # Sort by market share
            overall_market_share.sort(key=lambda x: x['market_share_pct'], reverse=True)
            
            # Regional market share
            regional_market_share = []
            for region in data[region_column].unique():
                region_data = data[data[region_column] == region]
                region_total = region_data[sales_column].sum()
                
                if region_total == 0:
                    continue
                
                region_shares = []
                for competitor in region_data[competitor_column].unique():
                    comp_sales = region_data[region_data[competitor_column] == competitor][sales_column].sum()
                    share_pct = (comp_sales / region_total * 100) if region_total > 0 else 0
                    
                    region_shares.append({
                        'competitor': competitor,
                        'market_share_pct': float(share_pct),
                        'sales': float(comp_sales)
                    })
                
                # Sort by share
                region_shares.sort(key=lambda x: x['market_share_pct'], reverse=True)
                
                regional_market_share.append({
                    'region': region,
                    'total_sales': float(region_total),
                    'market_leader': region_shares[0]['competitor'] if region_shares else None,
                    'leader_share_pct': region_shares[0]['market_share_pct'] if region_shares else 0,
                    'competitors': region_shares
                })
            
            # Calculate concentration (HHI - Herfindahl-Hirschman Index)
            hhi = sum(share['market_share_pct'] ** 2 for share in overall_market_share)
            
            # Interpret concentration
            if hhi < 1500:
                concentration = 'Low (Competitive)'
            elif hhi < 2500:
                concentration = 'Moderate'
            else:
                concentration = 'High (Concentrated)'
            
            return {
                'overall_market_share': overall_market_share,
                'regional_market_share': regional_market_share,
                'market_concentration': {
                    'hhi': float(hhi),
                    'interpretation': concentration
                },
                'total_competitors': len(overall_market_share)
            }
        
        except Exception as e:
            logger.error(f"Error analyzing market share: {str(e)}")
            raise
    
    def identify_competitive_advantages(self, data: pd.DataFrame,
                                       competitor_column: str = 'competitor',
                                       metrics: Dict[str, str] = None) -> List[Dict[str, Any]]:
        """
        Identify competitive advantages for each competitor.
        
        Args:
            data: DataFrame with competitor data
            competitor_column: Name of competitor column
            metrics: Dictionary mapping metric names to column names
        
        Returns:
            List of competitive advantages by competitor
        """
        try:
            if metrics is None:
                metrics = {
                    'price': 'price',
                    'quality': 'quality_score',
                    'availability': 'availability_score'
                }
            
            advantages = []
            
            for competitor in data[competitor_column].unique():
                comp_data = data[data[competitor_column] == competitor]
                comp_advantages = {'competitor': competitor, 'advantages': []}
                
                for metric_name, column_name in metrics.items():
                    if column_name not in data.columns:
                        continue
                    
                    # Calculate competitor's position
                    comp_value = comp_data[column_name].mean()
                    market_value = data[column_name].mean()
                    
                    # For price, lower is better
                    if metric_name == 'price':
                        if comp_value < market_value * 0.95:
                            comp_advantages['advantages'].append({
                                'metric': metric_name,
                                'advantage': 'Price Leader',
                                'value': float(comp_value),
                                'market_avg': float(market_value),
                                'difference_pct': float((comp_value - market_value) / market_value * 100)
                            })
                    else:
                        # For other metrics, higher is better
                        if comp_value > market_value * 1.05:
                            comp_advantages['advantages'].append({
                                'metric': metric_name,
                                'advantage': f'{metric_name.title()} Leader',
                                'value': float(comp_value),
                                'market_avg': float(market_value),
                                'difference_pct': float((comp_value - market_value) / market_value * 100)
                            })
                
                advantages.append(comp_advantages)
            
            return advantages
        
        except Exception as e:
            logger.error(f"Error identifying competitive advantages: {str(e)}")
            raise
