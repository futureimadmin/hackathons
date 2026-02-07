import { apiClient } from './apiClient';

export interface MarketTrend {
  region: string;
  product_category: string;
  trend_score: number;
  growth_rate: number;
  period: string;
  [key: string]: string | number;
}

export interface RegionalPrice {
  region: string;
  product_id: string;
  product_name: string;
  avg_price: number;
  currency: string;
  [key: string]: string | number;
}

export interface PriceComparison {
  product_id: string;
  product_name: string;
  regions: Array<{
    region: string;
    price: number;
    currency: string;
  }>;
}

export interface MarketOpportunity {
  region: string;
  product_category: string;
  opportunity_score: number;
  factors: string[];
  recommendation: string;
}

export interface CompetitorAnalysis {
  competitor_name: string;
  market_share: number;
  pricing_strategy: string;
  strengths: string[];
  weaknesses: string[];
}

export interface MarketShare {
  region: string;
  our_share: number;
  competitor_shares: Array<{
    competitor: string;
    share: number;
  }>;
}

export interface GrowthRate {
  region: string;
  category: string;
  growth_rate: number;
  period: string;
}

export interface TrendChange {
  region: string;
  product_category: string;
  change_type: string;
  magnitude: number;
  detected_at: string;
}

class GlobalMarketService {
  /**
   * Get market trends
   */
  async getTrends(): Promise<{ trends: MarketTrend[] }> {
    return apiClient.get<{ trends: MarketTrend[] }>('/global-market/trends');
  }

  /**
   * Get regional prices
   */
  async getRegionalPrices(): Promise<{ prices: RegionalPrice[] }> {
    return apiClient.get<{ prices: RegionalPrice[] }>('/global-market/regional-prices');
  }

  /**
   * Compare prices across regions
   */
  async comparePrices(request: { product_id: string }): Promise<PriceComparison> {
    return apiClient.post<PriceComparison>('/global-market/price-comparison', request);
  }

  /**
   * Get market opportunities
   */
  async getOpportunities(request: { region?: string }): Promise<{ opportunities: MarketOpportunity[] }> {
    return apiClient.post<{ opportunities: MarketOpportunity[] }>('/global-market/opportunities', request);
  }

  /**
   * Get competitor analysis
   */
  async getCompetitorAnalysis(request: { region: string }): Promise<{ analysis: CompetitorAnalysis[] }> {
    return apiClient.post<{ analysis: CompetitorAnalysis[] }>('/global-market/competitor-analysis', request);
  }

  /**
   * Get market share
   */
  async getMarketShare(): Promise<{ market_share: MarketShare[] }> {
    return apiClient.get<{ market_share: MarketShare[] }>('/global-market/market-share');
  }

  /**
   * Get growth rates
   */
  async getGrowthRates(): Promise<{ growth_rates: GrowthRate[] }> {
    return apiClient.get<{ growth_rates: GrowthRate[] }>('/global-market/growth-rates');
  }

  /**
   * Detect trend changes
   */
  async detectTrendChanges(request: { region?: string }): Promise<{ changes: TrendChange[] }> {
    return apiClient.post<{ changes: TrendChange[] }>('/global-market/trend-changes', request);
  }
}

export const globalMarketService = new GlobalMarketService();
