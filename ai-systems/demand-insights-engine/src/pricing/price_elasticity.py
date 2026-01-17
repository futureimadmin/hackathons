"""
Price Elasticity Analysis Module

Calculates price elasticity of demand and provides pricing optimization recommendations.
"""

import numpy as np
import pandas as pd
from typing import Dict, List, Tuple, Optional
from scipy import stats
from sklearn.linear_model import LinearRegression
import logging

logger = logging.getLogger(__name__)


class PriceElasticityAnalyzer:
    """
    Analyzes price elasticity and optimizes pricing strategies.
    
    Uses regression analysis to calculate price elasticity coefficients
    and provides revenue-maximizing price recommendations.
    """
    
    def __init__(self):
        self.elasticity_models = {}
        self.elasticity_coefficients = {}
    
    def calculate_elasticity(
        self,
        data: pd.DataFrame,
        product_id: Optional[str] = None,
        category: Optional[str] = None
    ) -> Dict:
        """
        Calculate price elasticity of demand.
        
        Args:
            data: DataFrame with columns: product_id, price, quantity, date
            product_id: Optional product ID to analyze
            category: Optional category to analyze
            
        Returns:
            Dictionary with elasticity metrics
        """
        try:
            # Filter data if needed
            if product_id:
                data = data[data['product_id'] == product_id]
            elif category:
                data = data[data['category'] == category]
            
            if len(data) < 10:
                raise ValueError("Insufficient data for elasticity calculation")
            
            # Calculate log transformations for elasticity
            data = data.copy()
            data['log_price'] = np.log(data['price'])
            data['log_quantity'] = np.log(data['quantity'])
            
            # Remove infinite values
            data = data.replace([np.inf, -np.inf], np.nan).dropna()
            
            # Fit regression model: log(Q) = a + b*log(P)
            X = data[['log_price']].values
            y = data['log_quantity'].values
            
            model = LinearRegression()
            model.fit(X, y)
            
            elasticity = model.coef_[0]
            r_squared = model.score(X, y)
            
            # Calculate confidence interval
            predictions = model.predict(X)
            residuals = y - predictions
            std_error = np.std(residuals) / np.sqrt(len(data))
            confidence_interval = 1.96 * std_error
            
            # Determine elasticity type
            if elasticity < -1:
                elasticity_type = "Elastic"
                interpretation = "Demand is highly sensitive to price changes"
            elif elasticity > -1 and elasticity < 0:
                elasticity_type = "Inelastic"
                interpretation = "Demand is relatively insensitive to price changes"
            else:
                elasticity_type = "Unusual"
                interpretation = "Positive elasticity detected - verify data quality"
            
            result = {
                'elasticity_coefficient': float(elasticity),
                'r_squared': float(r_squared),
                'confidence_interval': float(confidence_interval),
                'elasticity_type': elasticity_type,
                'interpretation': interpretation,
                'sample_size': len(data),
                'price_range': {
                    'min': float(data['price'].min()),
                    'max': float(data['price'].max()),
                    'mean': float(data['price'].mean())
                },
                'quantity_range': {
                    'min': float(data['quantity'].min()),
                    'max': float(data['quantity'].max()),
                    'mean': float(data['quantity'].mean())
                }
            }
            
            # Store model
            key = product_id or category or 'overall'
            self.elasticity_models[key] = model
            self.elasticity_coefficients[key] = elasticity
            
            logger.info(f"Calculated elasticity for {key}: {elasticity:.3f}")
            
            return result
            
        except Exception as e:
            logger.error(f"Error calculating elasticity: {str(e)}")
            raise
    
    def optimize_price(
        self,
        current_price: float,
        current_quantity: float,
        cost_per_unit: float,
        elasticity: Optional[float] = None,
        product_id: Optional[str] = None
    ) -> Dict:
        """
        Calculate optimal price for revenue maximization.
        
        Args:
            current_price: Current product price
            current_quantity: Current sales quantity
            cost_per_unit: Cost to produce/acquire one unit
            elasticity: Price elasticity coefficient (if known)
            product_id: Product ID to use stored elasticity
            
        Returns:
            Dictionary with pricing recommendations
        """
        try:
            # Get elasticity coefficient
            if elasticity is None:
                if product_id and product_id in self.elasticity_coefficients:
                    elasticity = self.elasticity_coefficients[product_id]
                else:
                    raise ValueError("Elasticity coefficient required")
            
            # Calculate optimal price using elasticity formula
            # Optimal markup = -1 / (elasticity + 1)
            if elasticity >= -1:
                logger.warning("Inelastic demand - price increase recommended")
                optimal_markup = 0.5  # Conservative 50% markup
            else:
                optimal_markup = -1 / (elasticity + 1)
            
            optimal_price = cost_per_unit * (1 + optimal_markup)
            
            # Estimate quantity at optimal price using elasticity
            price_change_pct = (optimal_price - current_price) / current_price
            quantity_change_pct = elasticity * price_change_pct
            estimated_quantity = current_quantity * (1 + quantity_change_pct)
            
            # Calculate revenue and profit
            current_revenue = current_price * current_quantity
            current_profit = (current_price - cost_per_unit) * current_quantity
            
            estimated_revenue = optimal_price * estimated_quantity
            estimated_profit = (optimal_price - cost_per_unit) * estimated_quantity
            
            revenue_change = ((estimated_revenue - current_revenue) / current_revenue) * 100
            profit_change = ((estimated_profit - current_profit) / current_profit) * 100
            
            # Generate recommendation
            if optimal_price > current_price * 1.05:
                recommendation = "Increase price"
            elif optimal_price < current_price * 0.95:
                recommendation = "Decrease price"
            else:
                recommendation = "Maintain current price"
            
            result = {
                'current_price': float(current_price),
                'optimal_price': float(optimal_price),
                'price_change_pct': float((optimal_price - current_price) / current_price * 100),
                'recommendation': recommendation,
                'elasticity_used': float(elasticity),
                'estimated_impact': {
                    'quantity_change_pct': float(quantity_change_pct * 100),
                    'revenue_change_pct': float(revenue_change),
                    'profit_change_pct': float(profit_change),
                    'estimated_quantity': float(estimated_quantity),
                    'estimated_revenue': float(estimated_revenue),
                    'estimated_profit': float(estimated_profit)
                },
                'current_metrics': {
                    'quantity': float(current_quantity),
                    'revenue': float(current_revenue),
                    'profit': float(current_profit),
                    'margin_pct': float((current_price - cost_per_unit) / current_price * 100)
                }
            }
            
            logger.info(f"Price optimization: {recommendation} from ${current_price:.2f} to ${optimal_price:.2f}")
            
            return result
            
        except Exception as e:
            logger.error(f"Error optimizing price: {str(e)}")
            raise
    
    def analyze_price_sensitivity(
        self,
        data: pd.DataFrame,
        price_points: List[float]
    ) -> Dict:
        """
        Analyze demand sensitivity across different price points.
        
        Args:
            data: Historical sales data
            price_points: List of price points to analyze
            
        Returns:
            Dictionary with sensitivity analysis
        """
        try:
            # Calculate average elasticity
            elasticity_result = self.calculate_elasticity(data)
            elasticity = elasticity_result['elasticity_coefficient']
            
            # Calculate demand at each price point
            base_price = data['price'].mean()
            base_quantity = data['quantity'].mean()
            
            sensitivity_data = []
            for price in price_points:
                price_change_pct = (price - base_price) / base_price
                quantity_change_pct = elasticity * price_change_pct
                estimated_quantity = base_quantity * (1 + quantity_change_pct)
                estimated_revenue = price * estimated_quantity
                
                sensitivity_data.append({
                    'price': float(price),
                    'estimated_quantity': float(max(0, estimated_quantity)),
                    'estimated_revenue': float(max(0, estimated_revenue)),
                    'price_change_pct': float(price_change_pct * 100)
                })
            
            # Find revenue-maximizing price
            max_revenue_point = max(sensitivity_data, key=lambda x: x['estimated_revenue'])
            
            result = {
                'base_price': float(base_price),
                'base_quantity': float(base_quantity),
                'elasticity': float(elasticity),
                'sensitivity_curve': sensitivity_data,
                'revenue_maximizing_price': max_revenue_point['price'],
                'max_estimated_revenue': max_revenue_point['estimated_revenue']
            }
            
            return result
            
        except Exception as e:
            logger.error(f"Error analyzing price sensitivity: {str(e)}")
            raise
