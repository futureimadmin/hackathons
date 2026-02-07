import { apiClient } from './apiClient';

export interface FraudDetection {
  transaction_id: string;
  fraud_score: number;
  is_fraud: boolean;
  anomaly_factors: string[];
}

export interface RiskScore {
  transaction_id: string;
  risk_score: number;
  risk_level: string;
  factors: string[];
}

export interface HighRiskTransaction {
  transaction_id: string;
  customer_id: string;
  amount: number;
  risk_score: number;
  timestamp: string;
  [key: string]: string | number;
}

export interface PCICompliance {
  compliant: boolean;
  issues: string[];
  recommendations: string[];
}

export interface ComplianceReport {
  period: string;
  total_transactions: number;
  flagged_transactions: number;
  compliance_rate: number;
  issues: string[];
}

export interface FraudStatistics {
  total_transactions: number;
  fraud_detected: number;
  fraud_rate: number;
  total_loss_prevented: number;
}

export interface FraudDetectionResponse {
  results: FraudDetection[];
  summary: {
    total_checked: number;
    fraud_detected: number;
  };
}

export interface RiskScoreResponse {
  scores: RiskScore[];
  avg_risk_score: number;
}

export interface HighRiskTransactionsResponse {
  transactions: HighRiskTransaction[];
  count: number;
}

class ComplianceService {
  /**
   * Detect fraud in transactions
   */
  async detectFraud(request: { transaction_ids?: string[] }): Promise<FraudDetectionResponse> {
    return apiClient.post<FraudDetectionResponse>('/compliance/fraud-detection', request);
  }

  /**
   * Calculate risk scores
   */
  async getRiskScore(request: { transaction_id: string }): Promise<RiskScoreResponse> {
    return apiClient.post<RiskScoreResponse>('/compliance/risk-score', request);
  }

  /**
   * Get high-risk transactions
   */
  async getHighRiskTransactions(): Promise<HighRiskTransactionsResponse> {
    return apiClient.get<HighRiskTransactionsResponse>('/compliance/high-risk-transactions');
  }

  /**
   * Check PCI compliance
   */
  async checkPCICompliance(request: { transaction_id: string }): Promise<PCICompliance> {
    return apiClient.post<PCICompliance>('/compliance/pci-compliance', request);
  }

  /**
   * Get compliance report
   */
  async getComplianceReport(): Promise<ComplianceReport> {
    return apiClient.get<ComplianceReport>('/compliance/compliance-report');
  }

  /**
   * Get fraud statistics
   */
  async getFraudStatistics(): Promise<FraudStatistics> {
    return apiClient.get<FraudStatistics>('/compliance/fraud-statistics');
  }
}

export const complianceService = new ComplianceService();
