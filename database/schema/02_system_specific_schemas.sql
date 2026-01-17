-- System-Specific Schemas for AI Systems
-- Requirements: 14.3

USE ecommerce;

-- ============================================================================
-- MARKET INTELLIGENCE SCHEMA
-- System 1: Market Intelligence Hub
-- ============================================================================

CREATE TABLE IF NOT EXISTS market_intelligence_forecasts (
    forecast_id VARCHAR(36) PRIMARY KEY,
    product_id VARCHAR(36),
    category_id VARCHAR(36),
    forecast_date DATE NOT NULL,
    forecast_period VARCHAR(20) NOT NULL, -- 'daily', 'weekly', 'monthly'
    model_type VARCHAR(50) NOT NULL, -- 'ARIMA', 'Prophet', 'LSTM'
    predicted_sales DECIMAL(12, 2),
    predicted_revenue DECIMAL(12, 2),
    confidence_lower DECIMAL(12, 2),
    confidence_upper DECIMAL(12, 2),
    accuracy_score DECIMAL(5, 4),
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (product_id) REFERENCES products(product_id) ON DELETE CASCADE,
    FOREIGN KEY (category_id) REFERENCES categories(category_id) ON DELETE CASCADE,
    INDEX idx_product (product_id),
    INDEX idx_category (category_id),
    INDEX idx_forecast_date (forecast_date),
    INDEX idx_model_type (model_type)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS market_trends (
    trend_id VARCHAR(36) PRIMARY KEY,
    category_id VARCHAR(36),
    trend_date DATE NOT NULL,
    trend_type VARCHAR(50) NOT NULL, -- 'seasonal', 'growth', 'decline'
    trend_strength DECIMAL(5, 4), -- 0.0 to 1.0
    description TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (category_id) REFERENCES categories(category_id) ON DELETE CASCADE,
    INDEX idx_category (category_id),
    INDEX idx_trend_date (trend_date),
    INDEX idx_trend_type (trend_type)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS competitive_pricing (
    pricing_id VARCHAR(36) PRIMARY KEY,
    product_id VARCHAR(36) NOT NULL,
    competitor_name VARCHAR(100) NOT NULL,
    competitor_price DECIMAL(10, 2) NOT NULL,
    price_date DATE NOT NULL,
    price_difference DECIMAL(10, 2),
    price_difference_pct DECIMAL(5, 2),
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (product_id) REFERENCES products(product_id) ON DELETE CASCADE,
    INDEX idx_product (product_id),
    INDEX idx_competitor (competitor_name),
    INDEX idx_price_date (price_date)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================================
-- DEMAND INSIGHTS SCHEMA
-- System 2: Demand Insights Engine
-- ============================================================================

CREATE TABLE IF NOT EXISTS customer_segments (
    segment_id VARCHAR(36) PRIMARY KEY,
    customer_id VARCHAR(36) NOT NULL,
    segment_name VARCHAR(100) NOT NULL, -- 'High Value', 'At Risk', 'New', etc.
    rfm_recency INT, -- Days since last purchase
    rfm_frequency INT, -- Number of purchases
    rfm_monetary DECIMAL(12, 2), -- Total spend
    segment_score DECIMAL(5, 2),
    assigned_date DATE NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (customer_id) REFERENCES customers(customer_id) ON DELETE CASCADE,
    INDEX idx_customer (customer_id),
    INDEX idx_segment_name (segment_name),
    INDEX idx_assigned_date (assigned_date)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS demand_forecasts (
    demand_forecast_id VARCHAR(36) PRIMARY KEY,
    product_id VARCHAR(36) NOT NULL,
    forecast_date DATE NOT NULL,
    predicted_demand INT NOT NULL,
    confidence_interval_lower INT,
    confidence_interval_upper INT,
    model_type VARCHAR(50) NOT NULL, -- 'XGBoost', 'Random Forest', etc.
    feature_importance JSON,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (product_id) REFERENCES products(product_id) ON DELETE CASCADE,
    INDEX idx_product (product_id),
    INDEX idx_forecast_date (forecast_date)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS price_elasticity (
    elasticity_id VARCHAR(36) PRIMARY KEY,
    product_id VARCHAR(36) NOT NULL,
    analysis_date DATE NOT NULL,
    elasticity_coefficient DECIMAL(8, 4),
    optimal_price DECIMAL(10, 2),
    expected_revenue DECIMAL(12, 2),
    price_sensitivity VARCHAR(20), -- 'high', 'medium', 'low'
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (product_id) REFERENCES products(product_id) ON DELETE CASCADE,
    INDEX idx_product (product_id),
    INDEX idx_analysis_date (analysis_date)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS customer_lifetime_value (
    clv_id VARCHAR(36) PRIMARY KEY,
    customer_id VARCHAR(36) NOT NULL,
    calculation_date DATE NOT NULL,
    predicted_clv DECIMAL(12, 2) NOT NULL,
    confidence_score DECIMAL(5, 4),
    churn_probability DECIMAL(5, 4),
    expected_purchases INT,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (customer_id) REFERENCES customers(customer_id) ON DELETE CASCADE,
    INDEX idx_customer (customer_id),
    INDEX idx_calculation_date (calculation_date),
    INDEX idx_predicted_clv (predicted_clv)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================================
-- COMPLIANCE GUARDIAN SCHEMA
-- System 3: Compliance Guardian
-- ============================================================================

CREATE TABLE IF NOT EXISTS fraud_detections (
    detection_id VARCHAR(36) PRIMARY KEY,
    order_id VARCHAR(36),
    payment_id VARCHAR(36),
    detection_date TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fraud_score DECIMAL(5, 4) NOT NULL, -- 0.0 to 1.0
    fraud_type VARCHAR(50), -- 'card_fraud', 'account_takeover', 'friendly_fraud'
    risk_level VARCHAR(20) NOT NULL, -- 'low', 'medium', 'high', 'critical'
    detection_method VARCHAR(50), -- 'isolation_forest', 'rule_based', etc.
    is_confirmed_fraud BOOLEAN,
    investigation_status VARCHAR(50) DEFAULT 'pending',
    notes TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (order_id) REFERENCES orders(order_id) ON DELETE CASCADE,
    FOREIGN KEY (payment_id) REFERENCES payments(payment_id) ON DELETE CASCADE,
    INDEX idx_order (order_id),
    INDEX idx_payment (payment_id),
    INDEX idx_fraud_score (fraud_score),
    INDEX idx_risk_level (risk_level),
    INDEX idx_detection_date (detection_date)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS compliance_checks (
    check_id VARCHAR(36) PRIMARY KEY,
    check_type VARCHAR(50) NOT NULL, -- 'PCI_DSS', 'GDPR', 'data_quality'
    entity_type VARCHAR(50) NOT NULL, -- 'order', 'payment', 'customer'
    entity_id VARCHAR(36) NOT NULL,
    check_date TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    compliance_status VARCHAR(20) NOT NULL, -- 'compliant', 'non_compliant', 'warning'
    issues_found JSON,
    severity VARCHAR(20), -- 'low', 'medium', 'high', 'critical'
    remediation_required BOOLEAN NOT NULL DEFAULT FALSE,
    remediation_notes TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_check_type (check_type),
    INDEX idx_entity (entity_type, entity_id),
    INDEX idx_compliance_status (compliance_status),
    INDEX idx_check_date (check_date)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS risk_scores (
    risk_score_id VARCHAR(36) PRIMARY KEY,
    entity_type VARCHAR(50) NOT NULL, -- 'customer', 'transaction', 'product'
    entity_id VARCHAR(36) NOT NULL,
    score_date TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    risk_score DECIMAL(5, 2) NOT NULL, -- 0 to 100
    risk_category VARCHAR(50),
    risk_factors JSON,
    model_version VARCHAR(20),
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_entity (entity_type, entity_id),
    INDEX idx_risk_score (risk_score),
    INDEX idx_score_date (score_date)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================================
-- RETAIL COPILOT SCHEMA
-- System 4: Retail Copilot
-- ============================================================================

CREATE TABLE IF NOT EXISTS copilot_conversations (
    conversation_id VARCHAR(36) PRIMARY KEY,
    user_id VARCHAR(36) NOT NULL,
    conversation_title VARCHAR(255),
    started_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    last_message_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    message_count INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_user (user_id),
    INDEX idx_started_at (started_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS copilot_messages (
    message_id VARCHAR(36) PRIMARY KEY,
    conversation_id VARCHAR(36) NOT NULL,
    role VARCHAR(20) NOT NULL, -- 'user', 'assistant', 'system'
    message_text TEXT NOT NULL,
    query_type VARCHAR(50), -- 'inventory', 'orders', 'customers', 'analytics'
    sql_query TEXT,
    query_results JSON,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (conversation_id) REFERENCES copilot_conversations(conversation_id) ON DELETE CASCADE,
    INDEX idx_conversation (conversation_id),
    INDEX idx_created_at (created_at),
    INDEX idx_query_type (query_type)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS product_recommendations (
    recommendation_id VARCHAR(36) PRIMARY KEY,
    customer_id VARCHAR(36),
    product_id VARCHAR(36) NOT NULL,
    recommendation_type VARCHAR(50) NOT NULL, -- 'collaborative', 'content_based', 'hybrid'
    recommendation_score DECIMAL(5, 4),
    recommendation_date TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    was_clicked BOOLEAN DEFAULT FALSE,
    was_purchased BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (customer_id) REFERENCES customers(customer_id) ON DELETE CASCADE,
    FOREIGN KEY (product_id) REFERENCES products(product_id) ON DELETE CASCADE,
    INDEX idx_customer (customer_id),
    INDEX idx_product (product_id),
    INDEX idx_recommendation_date (recommendation_date)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================================
-- GLOBAL MARKET PULSE SCHEMA
-- System 5: Global Market Pulse
-- ============================================================================

CREATE TABLE IF NOT EXISTS regional_market_data (
    market_data_id VARCHAR(36) PRIMARY KEY,
    region VARCHAR(100) NOT NULL, -- 'North America', 'Europe', 'Asia Pacific', etc.
    country VARCHAR(100) NOT NULL,
    category_id VARCHAR(36),
    data_date DATE NOT NULL,
    market_size DECIMAL(15, 2),
    growth_rate DECIMAL(5, 2),
    market_share DECIMAL(5, 2),
    avg_price DECIMAL(10, 2),
    currency_code CHAR(3) NOT NULL DEFAULT 'USD',
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (category_id) REFERENCES categories(category_id) ON DELETE CASCADE,
    INDEX idx_region (region),
    INDEX idx_country (country),
    INDEX idx_category (category_id),
    INDEX idx_data_date (data_date)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS market_opportunities (
    opportunity_id VARCHAR(36) PRIMARY KEY,
    region VARCHAR(100) NOT NULL,
    country VARCHAR(100) NOT NULL,
    category_id VARCHAR(36),
    opportunity_type VARCHAR(50) NOT NULL, -- 'expansion', 'new_product', 'pricing'
    opportunity_score DECIMAL(5, 2) NOT NULL, -- 0 to 100
    market_potential DECIMAL(15, 2),
    competition_level VARCHAR(20), -- 'low', 'medium', 'high'
    entry_barriers VARCHAR(20), -- 'low', 'medium', 'high'
    recommendation TEXT,
    analysis_date DATE NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (category_id) REFERENCES categories(category_id) ON DELETE CASCADE,
    INDEX idx_region (region),
    INDEX idx_country (country),
    INDEX idx_opportunity_score (opportunity_score),
    INDEX idx_analysis_date (analysis_date)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS competitor_analysis (
    analysis_id VARCHAR(36) PRIMARY KEY,
    competitor_name VARCHAR(100) NOT NULL,
    region VARCHAR(100) NOT NULL,
    category_id VARCHAR(36),
    analysis_date DATE NOT NULL,
    market_share DECIMAL(5, 2),
    pricing_strategy VARCHAR(50),
    product_count INT,
    avg_rating DECIMAL(3, 2),
    strengths TEXT,
    weaknesses TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (category_id) REFERENCES categories(category_id) ON DELETE CASCADE,
    INDEX idx_competitor (competitor_name),
    INDEX idx_region (region),
    INDEX idx_analysis_date (analysis_date)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================================
-- SUMMARY
-- ============================================================================
-- System-specific tables created:
--
-- Market Intelligence Hub (3 tables):
-- - market_intelligence_forecasts
-- - market_trends
-- - competitive_pricing
--
-- Demand Insights Engine (4 tables):
-- - customer_segments
-- - demand_forecasts
-- - price_elasticity
-- - customer_lifetime_value
--
-- Compliance Guardian (3 tables):
-- - fraud_detections
-- - compliance_checks
-- - risk_scores
--
-- Retail Copilot (3 tables):
-- - copilot_conversations
-- - copilot_messages
-- - product_recommendations
--
-- Global Market Pulse (3 tables):
-- - regional_market_data
-- - market_opportunities
-- - competitor_analysis
--
-- Total: 16 system-specific tables
