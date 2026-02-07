import { apiClient } from './apiClient';

export interface TrendData {
  month: string;
  sales: number;
  revenue: number;
  [key: string]: string | number;
}

export interface ForecastData {
  month: string;
  actual: number;
  forecast: number;
  lower: number;
  upper: number;
  [key: string]: string | number;
}

export interface PricingData {
  product: string;
  ourPrice: number;
  competitor1: number;
  competitor2: number;
  marketAvg: number;
  [key: string]: string | number;
}

export interface ForecastRequest {
  metric?: string;
  horizon?: number;
  model?: 'auto' | 'arima' | 'prophet' | 'lstm';
  product_id?: string;
  category_id?: string;
  start_date?: string;
  end_date?: string;
}

export interface ForecastResponse {
  forecast: ForecastData[];
  model_used: string;
  metrics: {
    mae: number;
    rmse: number;
    mape: number;
  };
}

export interface TrendsResponse {
  trends: TrendData[];
  period: string;
}

export interface CompetitivePricingResponse {
  pricing: PricingData[];
  last_updated: string;
}

class MarketIntelligenceService {
  /**
   * Get market trends data
   */
  async getTrends(): Promise<TrendsResponse> {
    return apiClient.get<TrendsResponse>('/market-intelligence/trends');
  }

  /**
   * Generate sales forecast
   */
  async generateForecast(request: ForecastRequest): Promise<ForecastResponse> {
    return apiClient.post<ForecastResponse>('/market-intelligence/forecast', request);
  }

  /**
   * Get competitive pricing analysis
   */
  async getCompetitivePricing(): Promise<CompetitivePricingResponse> {
    return apiClient.get<CompetitivePricingResponse>('/market-intelligence/competitive-pricing');
  }

  /**
   * Compare forecasting models
   */
  async compareModels(request: ForecastRequest): Promise<any> {
    return apiClient.post('/market-intelligence/compare-models', request);
  }
}

export const marketIntelligenceService = new MarketIntelligenceService();
