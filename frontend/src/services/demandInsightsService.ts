import { apiClient } from './apiClient';

export interface CustomerSegment {
  segment_id: number;
  segment_name: string;
  customer_count: number;
  avg_clv: number;
  characteristics: string;
  [key: string]: string | number;
}

export interface DemandForecast {
  date: string;
  product_id: string;
  forecast_demand: number;
  lower_bound: number;
  upper_bound: number;
  [key: string]: string | number;
}

export interface PriceElasticity {
  product_id: string;
  product_name: string;
  elasticity: number;
  optimal_price: number;
  current_price: number;
  [key: string]: string | number;
}

export interface CustomerCLV {
  customer_id: string;
  predicted_clv: number;
  segment: string;
  risk_score: number;
}

export interface ChurnPrediction {
  customer_id: string;
  churn_probability: number;
  risk_level: string;
  factors: string[];
}

export interface SegmentsResponse {
  segments: CustomerSegment[];
  total_customers: number;
}

export interface ForecastResponse {
  forecasts: DemandForecast[];
  model_accuracy: number;
}

export interface PriceElasticityResponse {
  elasticity: PriceElasticity[];
  analysis_date: string;
}

export interface CLVResponse {
  predictions: CustomerCLV[];
  avg_clv: number;
}

export interface ChurnResponse {
  predictions: ChurnPrediction[];
  at_risk_count: number;
}

class DemandInsightsService {
  /**
   * Get customer segments
   */
  async getSegments(): Promise<SegmentsResponse> {
    return apiClient.get<SegmentsResponse>('/demand-insights/segments');
  }

  /**
   * Generate demand forecast
   */
  async generateForecast(request: { product_id?: string; horizon?: number }): Promise<ForecastResponse> {
    return apiClient.post<ForecastResponse>('/demand-insights/forecast', request);
  }

  /**
   * Get price elasticity analysis
   */
  async getPriceElasticity(request: { product_id?: string }): Promise<PriceElasticityResponse> {
    return apiClient.post<PriceElasticityResponse>('/demand-insights/price-elasticity', request);
  }

  /**
   * Get customer lifetime value predictions
   */
  async getCLV(request: { customer_id?: string }): Promise<CLVResponse> {
    return apiClient.post<CLVResponse>('/demand-insights/clv', request);
  }

  /**
   * Get churn predictions
   */
  async getChurnPredictions(request: { threshold?: number }): Promise<ChurnResponse> {
    return apiClient.post<ChurnResponse>('/demand-insights/churn', request);
  }

  /**
   * Get at-risk customers
   */
  async getAtRiskCustomers(): Promise<ChurnResponse> {
    return apiClient.get<ChurnResponse>('/demand-insights/at-risk-customers');
  }
}

export const demandInsightsService = new DemandInsightsService();
