"""
Market Opportunity Scoring Module

Calculates market entry opportunity scores using Multi-Criteria Decision Analysis (MCDA).
"""

import pandas as pd
import numpy as np
from typing import Dict, List, Any, Optional
import logging

logger = logging.getLogger(__name__)


class OpportunityScorer:
    """
    Scores market opportunities using MCDA methodology.
    """
    
    def __init__(self):
        """Initialize the opportunity scorer with default weights."""
        # Default weights for scoring criteria (must sum to 1.0)
        self.default_weights = {
            'market_size': 0.25,
            'growth_rate': 0.25,
            'competition_level': 0.20,
            'price_premium': 0.15,
            'market_maturity': 0.15
        }
    
    def score_opportunities(self, data: pd.DataFrame,
                           region_column: str = 'region',
                           criteria_columns: Optional[Dict[str, str]] = None,
                           weights: Optional[Dict[str, float]] = None) -> pd.DataFrame:
        """
        Score market opportunities using MCDA.
        
        Args:
            data: DataFrame with market data
            region_column: Name of region column
            criteria_columns: Mapping of criteria names to column names
            weights: Custom weights for criteria (must sum to 1.0)
        
        Returns:
            DataFrame with opportunity scores
        """
        try:
            # Use default weights if not provided
            if weights is None:
                weights = self.default_weights
            else:
                # Validate weights sum to 1.0
                if not np.isclose(sum(weights.values()), 1.0):
                    raise ValueError("Weights must sum to 1.0")
            
            # Default criteria column mapping
            if criteria_columns is None:
                criteria_columns = {
                    'market_size': 'market_size',
                    'growth_rate': 'growth_rate',
                    'competition_level': 'competition_level',
                    'price_premium': 'price_premium',
                    'market_maturity': 'market_maturity'
                }
            
            # Normalize criteria
            normalized_data = self._normalize_criteria(data, criteria_columns)
            
            # Calculate weighted scores
            scores = self._calculate_weighted_scores(normalized_data, weights)
            
            # Add scores to data
            result = data.copy()
            result['opportunity_score'] = scores
            result['opportunity_rank'] = scores.rank(ascending=False, method='min')
            result['opportunity_category'] = result['opportunity_score'].apply(self._categorize_score)
            
            # Sort by score
            result = result.sort_values('opportunity_score', ascending=False)
            
            return result
        
        except Exception as e:
            logger.error(f"Error scoring opportunities: {str(e)}")
            raise
    
    def _normalize_criteria(self, data: pd.DataFrame,
                           criteria_columns: Dict[str, str]) -> pd.DataFrame:
        """
        Normalize criteria to 0-1 scale.
        
        For beneficial criteria (higher is better): (x - min) / (max - min)
        For cost criteria (lower is better): (max - x) / (max - min)
        """
        normalized = data.copy()
        
        # Beneficial criteria (higher is better)
        beneficial = ['market_size', 'growth_rate', 'price_premium']
        
        # Cost criteria (lower is better)
        cost = ['competition_level', 'market_maturity']
        
        for criterion, column in criteria_columns.items():
            if column not in data.columns:
                logger.warning(f"Column {column} not found, using default value 0.5")
                normalized[f'{criterion}_normalized'] = 0.5
                continue
            
            values = data[column].fillna(data[column].median())
            
            if len(values.unique()) == 1:
                # All values are the same
                normalized[f'{criterion}_normalized'] = 0.5
            elif criterion in beneficial:
                # Beneficial: higher is better
                min_val = values.min()
                max_val = values.max()
                normalized[f'{criterion}_normalized'] = (values - min_val) / (max_val - min_val)
            elif criterion in cost:
                # Cost: lower is better
                min_val = values.min()
                max_val = values.max()
                normalized[f'{criterion}_normalized'] = (max_val - values) / (max_val - min_val)
            else:
                # Default: beneficial
                min_val = values.min()
                max_val = values.max()
                normalized[f'{criterion}_normalized'] = (values - min_val) / (max_val - min_val)
        
        return normalized
    
    def _calculate_weighted_scores(self, data: pd.DataFrame,
                                   weights: Dict[str, float]) -> pd.Series:
        """Calculate weighted opportunity scores."""
        score = pd.Series(0.0, index=data.index)
        
        for criterion, weight in weights.items():
            column = f'{criterion}_normalized'
            if column in data.columns:
                score += data[column] * weight
        
        # Scale to 0-100
        return score * 100
    
    def _categorize_score(self, score: float) -> str:
        """Categorize opportunity score."""
        if score >= 80:
            return 'Excellent'
        elif score >= 60:
            return 'Good'
        elif score >= 40:
            return 'Moderate'
        elif score >= 20:
            return 'Low'
        else:
            return 'Very Low'
    
    def rank_opportunities(self, scored_data: pd.DataFrame,
                          region_column: str = 'region',
                          top_n: int = 10) -> List[Dict[str, Any]]:
        """
        Rank and return top market opportunities.
        
        Args:
            scored_data: DataFrame with opportunity scores
            region_column: Name of region column
            top_n: Number of top opportunities to return
        
        Returns:
            List of top opportunities with details
        """
        try:
            # Sort by score
            sorted_data = scored_data.sort_values('opportunity_score', ascending=False)
            
            # Get top N
            top_opportunities = sorted_data.head(top_n)
            
            # Convert to list of dictionaries
            opportunities = []
            for _, row in top_opportunities.iterrows():
                opp = {
                    'region': row[region_column],
                    'opportunity_score': float(row['opportunity_score']),
                    'rank': int(row['opportunity_rank']),
                    'category': row['opportunity_category']
                }
                
                # Add criteria values if available
                criteria_fields = ['market_size', 'growth_rate', 'competition_level', 
                                 'price_premium', 'market_maturity']
                for field in criteria_fields:
                    if field in row:
                        opp[field] = float(row[field])
                
                opportunities.append(opp)
            
            return opportunities
        
        except Exception as e:
            logger.error(f"Error ranking opportunities: {str(e)}")
            raise
    
    def sensitivity_analysis(self, data: pd.DataFrame,
                            criteria_columns: Dict[str, str],
                            base_weights: Optional[Dict[str, float]] = None) -> Dict[str, Any]:
        """
        Perform sensitivity analysis by varying weights.
        
        Args:
            data: DataFrame with market data
            criteria_columns: Mapping of criteria names to column names
            base_weights: Base weights for comparison
        
        Returns:
            Dictionary with sensitivity analysis results
        """
        try:
            if base_weights is None:
                base_weights = self.default_weights
            
            # Calculate base scores
            base_scores = self.score_opportunities(data, criteria_columns=criteria_columns, weights=base_weights)
            
            # Vary each weight by ±20%
            sensitivity_results = {}
            
            for criterion in base_weights.keys():
                # Increase weight
                increased_weights = base_weights.copy()
                increase_amount = base_weights[criterion] * 0.2
                increased_weights[criterion] += increase_amount
                
                # Redistribute the increase proportionally among other weights
                other_criteria = [c for c in base_weights.keys() if c != criterion]
                total_other = sum(base_weights[c] for c in other_criteria)
                for other in other_criteria:
                    if total_other > 0:
                        increased_weights[other] -= increase_amount * (base_weights[other] / total_other)
                
                # Calculate scores with increased weight
                increased_scores = self.score_opportunities(data, criteria_columns=criteria_columns, weights=increased_weights)
                
                # Calculate rank correlation
                base_ranks = base_scores['opportunity_rank']
                increased_ranks = increased_scores['opportunity_rank']
                rank_correlation = base_ranks.corr(increased_ranks, method='spearman')
                
                # Calculate score changes
                score_changes = increased_scores['opportunity_score'] - base_scores['opportunity_score']
                
                sensitivity_results[criterion] = {
                    'weight_change': '+20%',
                    'rank_correlation': float(rank_correlation),
                    'avg_score_change': float(score_changes.mean()),
                    'max_score_change': float(score_changes.max()),
                    'min_score_change': float(score_changes.min())
                }
            
            return {
                'base_weights': base_weights,
                'sensitivity_results': sensitivity_results
            }
        
        except Exception as e:
            logger.error(f"Error in sensitivity analysis: {str(e)}")
            raise
    
    def compare_scenarios(self, data: pd.DataFrame,
                         criteria_columns: Dict[str, str],
                         scenarios: Dict[str, Dict[str, float]]) -> Dict[str, Any]:
        """
        Compare different weighting scenarios.
        
        Args:
            data: DataFrame with market data
            criteria_columns: Mapping of criteria names to column names
            scenarios: Dictionary of scenario names to weight dictionaries
        
        Returns:
            Dictionary with scenario comparison results
        """
        try:
            scenario_results = {}
            
            for scenario_name, weights in scenarios.items():
                # Validate weights
                if not np.isclose(sum(weights.values()), 1.0):
                    logger.warning(f"Scenario {scenario_name} weights don't sum to 1.0, normalizing...")
                    total = sum(weights.values())
                    weights = {k: v/total for k, v in weights.items()}
                
                # Calculate scores for this scenario
                scored_data = self.score_opportunities(data, criteria_columns=criteria_columns, weights=weights)
                
                # Get top 5 opportunities
                top_5 = scored_data.nsmallest(5, 'opportunity_rank')
                
                scenario_results[scenario_name] = {
                    'weights': weights,
                    'top_5_regions': top_5['region'].tolist() if 'region' in top_5.columns else [],
                    'top_5_scores': top_5['opportunity_score'].tolist(),
                    'avg_score': float(scored_data['opportunity_score'].mean()),
                    'score_std': float(scored_data['opportunity_score'].std())
                }
            
            return {
                'scenarios': scenario_results,
                'total_scenarios': len(scenarios)
            }
        
        except Exception as e:
            logger.error(f"Error comparing scenarios: {str(e)}")
            raise
