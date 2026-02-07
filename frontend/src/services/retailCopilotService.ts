import { apiClient } from './apiClient';

export interface ChatMessage {
  role: 'user' | 'assistant';
  content: string;
  timestamp: string;
}

export interface Conversation {
  id: string;
  title: string;
  messages: ChatMessage[];
  created_at: string;
  updated_at: string;
}

export interface ChatResponse {
  response: string;
  conversation_id: string;
  sources?: string[];
}

export interface InventoryInsight {
  product_id: string;
  product_name: string;
  stock_level: number;
  reorder_point: number;
  status: string;
  [key: string]: string | number;
}

export interface OrderInsight {
  order_id: string;
  customer_id: string;
  total_amount: number;
  status: string;
  items_count: number;
}

export interface CustomerInsight {
  customer_id: string;
  name: string;
  total_orders: number;
  total_spent: number;
  segment: string;
}

export interface Recommendation {
  type: string;
  title: string;
  description: string;
  priority: string;
  impact: string;
}

export interface SalesReport {
  period: string;
  total_sales: number;
  total_orders: number;
  avg_order_value: number;
  top_products: Array<{ product_id: string; product_name: string; sales: number }>;
}

class RetailCopilotService {
  /**
   * Send chat message
   */
  async chat(request: { message: string; conversation_id?: string }): Promise<ChatResponse> {
    return apiClient.post<ChatResponse>('/copilot/chat', request);
  }

  /**
   * Get all conversations
   */
  async getConversations(): Promise<{ conversations: Conversation[] }> {
    return apiClient.get<{ conversations: Conversation[] }>('/copilot/conversations');
  }

  /**
   * Get specific conversation
   */
  async getConversation(id: string): Promise<Conversation> {
    return apiClient.get<Conversation>(`/copilot/conversation/${id}`);
  }

  /**
   * Delete conversation
   */
  async deleteConversation(id: string): Promise<{ success: boolean }> {
    return apiClient.delete<{ success: boolean }>(`/copilot/conversation/${id}`);
  }

  /**
   * Get inventory insights
   */
  async getInventoryInsights(): Promise<{ insights: InventoryInsight[] }> {
    return apiClient.get<{ insights: InventoryInsight[] }>('/copilot/inventory');
  }

  /**
   * Get order insights
   */
  async getOrderInsights(): Promise<{ insights: OrderInsight[] }> {
    return apiClient.get<{ insights: OrderInsight[] }>('/copilot/orders');
  }

  /**
   * Get customer insights
   */
  async getCustomerInsights(): Promise<{ insights: CustomerInsight[] }> {
    return apiClient.get<{ insights: CustomerInsight[] }>('/copilot/customers');
  }

  /**
   * Get recommendations
   */
  async getRecommendations(request: { context?: string }): Promise<{ recommendations: Recommendation[] }> {
    return apiClient.post<{ recommendations: Recommendation[] }>('/copilot/recommendations', request);
  }

  /**
   * Get sales report
   */
  async getSalesReport(): Promise<SalesReport> {
    return apiClient.get<SalesReport>('/copilot/sales-report');
  }
}

export const retailCopilotService = new RetailCopilotService();
