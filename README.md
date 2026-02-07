# FutureIM eCommerce AI Analytics Platform

**Enterprise-grade cloud infrastructure for AI-powered eCommerce analytics**

---

## 🚀 Quick Start

```powershell
# Step 1: Run prerequisite scripts
cd terraform
.\create-backend-resources.ps1
.\create-dms-vpc-role.ps1
.\create-mysql-secret.ps1 -MySQLPassword "your_password"

# Step 2: Configure Terraform
# Edit terraform/terraform.dev.tfvars with your values

# Step 3: Deploy infrastructure
terraform init -backend-config=backend.tfvars
terraform apply -var-file="terraform.dev.tfvars"

# Step 4: Complete GitHub connection in AWS Console
# CodePipeline → Settings → Connections → Authorize

# Done! Your platform is ready.
```

**Deployment Time:** 20-25 minutes

---

## 📋 Table of Contents

1. [Overview](#overview)
2. [Architecture](#architecture)
3. [AI Models & Data Pipeline](#ai-models--data-pipeline)
4. [Modules](#modules)
5. [Quick Start](#quick-start-guide)
6. [Configuration](#configuration)
7. [Operations](#operations)
8. [Troubleshooting](#troubleshooting)
9. [Future Enhancements](#future-enhancements)
10. [FAQ](#frequently-asked-questions-faq)

---

## 🤖 AI Models Quick Reference

| System | Primary Models | Use Case | Output |
|--------|---------------|----------|--------|
| **Market Intelligence Hub** | ARIMA, Prophet, LSTM | Sales forecasting | 30-day forecasts, trends |
| **Demand Insights Engine** | K-Means, XGBoost, Random Forest | Customer analytics | Segments, CLV, churn risk |
| **Compliance Guardian** | Isolation Forest, Rule Engine | Fraud & compliance | Fraud scores, risk levels |
| **Global Market Pulse** | Market Basket, MCDA | Market opportunities | Opportunities, regional analysis |
| **Retail Copilot** | BERT, NER, GPT | Conversational AI | Natural language responses |

**Total Models:** 15+ AI/ML models across 5 systems  
**Processing:** Parallel execution on AWS Batch  
**Retraining:** Monthly + performance-based triggers

---

## Overview

### What is This Platform?

The FutureIM eCommerce AI Platform provides 5 specialized AI systems that analyze eCommerce data and deliver actionable insights:

1. **Market Intelligence Hub** - Forecasting and market analytics
2. **Demand Insights Engine** - Customer insights and demand forecasting
3. **Compliance Guardian** - Fraud detection and compliance monitoring
4. **Retail Copilot** - AI-powered assistant for retail teams
5. **Global Market Pulse** - Global market trends and opportunities

### Key Features

- ✅ **15+ AI/ML Models** - ARIMA, Prophet, LSTM, XGBoost, K-Means, Random Forest, Isolation Forest, BERT, NER
- ✅ **Automated AI Pipeline** - Parallel processing of 5 AI systems on AWS Batch
- ✅ **Smart Data Architecture** - 1 raw + 1 curated (shared) + 5 prod (system-specific) buckets
- ✅ **Automated CI/CD** - Push to GitHub, auto-deploy to AWS
- ✅ **Real-time Data Replication** - MySQL → S3 via DMS
- ✅ **Scalable Architecture** - Serverless Lambda functions
- ✅ **Model Monitoring** - Automatic retraining on performance degradation
- ✅ **Secure by Design** - KMS encryption, VPC isolation, PCI DSS compliance
- ✅ **Production Ready** - Monitoring, logging, error handling

### Technology Stack

| Layer | Technologies |
|-------|-------------|
| **Infrastructure** | AWS, Terraform, CloudFormation |
| **Backend** | Java 17 (Auth), Python 3.11 (AI Systems) |
| **Frontend** | React 18, TypeScript, Vite, Material-UI |
| **Database** | MySQL 9.6 (on-premises) |
| **Data Lake** | S3 (Parquet), Glue, Athena |
| **Data Pipeline** | DMS, AWS Batch, EventBridge |
| **AI/ML - Forecasting** | ARIMA, Prophet, LSTM, XGBoost |
| **AI/ML - Clustering** | K-Means, DBSCAN, Hierarchical |
| **AI/ML - Classification** | Random Forest, Gradient Boosting, Isolation Forest |
| **AI/ML - NLP** | BERT, DistilBERT, Transformers, Spacy |
| **AI/ML - Frameworks** | scikit-learn, TensorFlow, PyTorch |
| **CI/CD** | CodePipeline, CodeBuild, GitHub |
| **Monitoring** | CloudWatch, CloudTrail |

---

## Architecture

### High-Level Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    GitHub Repository                         │
│              futureimadmin/hackathons (master)               │
└────────────────────────┬────────────────────────────────────┘
                         │ Auto-trigger on push
                         ▼
┌─────────────────────────────────────────────────────────────┐
│              CodePipeline V2 (4 Stages)                      │
│  Source → Infrastructure → Build Lambdas → Build Frontend   │
└────────────────────────┬────────────────────────────────────┘
                         │
         ┌───────────────┼───────────────┐
         ▼               ▼               ▼
    ┌────────┐    ┌──────────┐    ┌──────────┐
    │  VPC   │    │   DMS    │    │   API    │
    │Subnets │    │Replication│   │ Gateway  │
    └────────┘    └──────────┘    └──────────┘
         │               │               │
         └───────────────┼───────────────┘
                         ▼
              ┌──────────────────────┐
              │   5 AI Systems       │
              │   Lambda Functions   │
              └──────────────────────┘
```

### Data Flow

```
MySQL (172.20.10.2) → DMS → S3 (Parquet) → Glue → Athena → Lambda → API Gateway → Frontend
```

### Network Architecture

```
VPC (10.0.0.0/16)
├─ Public Subnets (10.0.1.0/24, 10.0.2.0/24)
│  └─ NAT Gateway, Internet Gateway
└─ Private Subnets (10.0.11.0/24, 10.0.12.0/24)
   └─ DMS, Lambda Functions
```

---

## AI Models & Data Pipeline

### Data Pipeline Architecture

The platform uses a **3-tier data lake architecture** with AI processing:

```
Tier 1: Raw Data (Shared)
└─ ecommerce-raw-450133579764
   └─ All MySQL tables in Parquet format

Tier 2: Curated Data (Shared)
└─ ecommerce-curated-450133579764
   └─ Validated, deduplicated, compliance-checked data

Tier 3: Production Analytics (System-Specific)
├─ market-intelligence-hub-prod-450133579764
├─ demand-insights-engine-prod-450133579764
├─ compliance-guardian-prod-450133579764
├─ global-market-pulse-prod-450133579764
└─ retail-copilot-prod-450133579764
```

**Data Flow:**
```
MySQL → Raw Bucket → [Validation] → Curated Bucket → [AI Processing] → Prod Buckets → Athena → Frontend
```

### AI Processing Pipeline

**Location:** `data-processing/src/processors/curated_to_prod_ai.py`

The AI processing pipeline:
1. Loads ALL curated data from shared bucket
2. Runs system-specific AI models in parallel (AWS Batch)
3. Generates analytics DataFrames
4. Writes Parquet files to system-specific prod buckets
5. Triggers Glue Crawlers to create Athena tables

**Key Features:**
- Parallel execution of 5 AI systems
- Automatic model selection based on data characteristics
- Versioned analytics outputs (timestamped Parquet files)
- Automatic schema inference via Glue Crawlers
- No manual Athena table creation required

### AI Models by System

#### 1. Market Intelligence Hub - Forecasting Models

**Purpose:** Time series forecasting and market trend analysis

**AI Models Used:**

| Model | Purpose | Input | Output | Rationale |
|-------|---------|-------|--------|-----------|
| **ARIMA** | Sales forecasting | Historical sales time series | 30-day forecast with confidence intervals | Best for stationary time series, handles trends and seasonality |
| **Prophet** | Seasonal forecasting | Sales + holidays + events | Forecast with seasonal components | Excellent for business data with strong seasonal patterns |
| **LSTM** | Complex pattern forecasting | Multi-variate time series | Long-term forecasts | Captures non-linear patterns and long-term dependencies |
| **Model Selector** | Auto-select best model | Historical data + validation metrics | Best model recommendation | Compares RMSE, MAE, MAPE across models |

**Input Data:**
- `orders` table: order_date, total, customer_id
- `order_items` table: product_id, quantity, price
- `products` table: category, price, inventory

**Output Analytics Tables:**
- `forecasts`: Daily/weekly/monthly sales forecasts with confidence intervals
- `trends`: Market trend analysis (growth rates, momentum indicators)
- `competitive_pricing`: Price comparison analysis vs. market averages

**Performance Metrics:**
- RMSE (Root Mean Square Error)
- MAE (Mean Absolute Error)
- MAPE (Mean Absolute Percentage Error)
- R² Score

**Alternative Models:**
- **XGBoost**: For feature-rich forecasting with external variables
- **Exponential Smoothing**: For simple trend/seasonal patterns
- **VAR (Vector Autoregression)**: For multi-variate forecasting
- **Transformer Models**: For very long sequences with attention mechanisms

---

#### 2. Demand Insights Engine - Customer Analytics

**Purpose:** Customer segmentation, demand forecasting, and churn prediction

**AI Models Used:**

| Model | Purpose | Input | Output | Rationale |
|-------|---------|-------|--------|-----------|
| **K-Means Clustering** | Customer segmentation | RFM metrics (Recency, Frequency, Monetary) | Customer segments (bronze/silver/gold/platinum) | Unsupervised learning, scales well, interpretable segments |
| **XGBoost** | CLV prediction | Customer features + purchase history | Predicted lifetime value | Handles non-linear relationships, feature importance, high accuracy |
| **Random Forest** | Churn prediction | Customer behavior features | Churn probability (0-1) | Robust to overfitting, handles missing data, provides feature importance |
| **SARIMA** | Seasonal demand forecasting | Product sales history | Product-level demand forecast | Handles seasonality and trends in product demand |
| **Linear Regression** | Price elasticity | Price changes + demand changes | Elasticity coefficient | Simple, interpretable, sufficient for price sensitivity |

**Input Data:**
- `customers` table: customer_id, registration_date, location
- `orders` table: order_date, total, customer_id
- `order_items` table: product_id, quantity, price
- `products` table: product_id, category, price

**Output Analytics Tables:**
- `customer_segments`: Segment assignments with characteristics
- `customer_lifetime_value`: CLV predictions with confidence scores
- `demand_forecasts`: Product-level demand forecasts (30/60/90 days)
- `churn_predictions`: Churn probability and risk level per customer
- `price_elasticity`: Price sensitivity analysis per product/category

**Segmentation Criteria:**
- **Bronze**: Low frequency, low value customers
- **Silver**: Medium frequency, medium value customers
- **Gold**: High frequency, high value customers
- **Platinum**: VIP customers with highest CLV

**Alternative Models:**
- **DBSCAN**: Density-based clustering for irregular segment shapes
- **Hierarchical Clustering**: For nested segment hierarchies
- **Neural Networks**: Deep learning for CLV with complex patterns
- **Gradient Boosting Machines**: Alternative to XGBoost
- **Survival Analysis**: For time-to-churn prediction

---

#### 3. Compliance Guardian - Risk & Fraud Detection

**Purpose:** Fraud detection, risk scoring, and PCI DSS compliance monitoring

**AI Models Used:**

| Model | Purpose | Input | Output | Rationale |
|-------|---------|-------|--------|-----------|
| **Isolation Forest** | Anomaly detection | Transaction features (amount, time, location) | Anomaly score (0-1) | Excellent for outlier detection, unsupervised, handles high-dimensional data |
| **Random Forest** | Fraud classification | Transaction + customer features | Fraud probability + risk level | High accuracy, handles imbalanced data, interpretable |
| **Gradient Boosting** | Risk scoring | Customer + transaction history | Risk score (0-100) | Captures complex risk patterns, feature interactions |
| **Rule Engine** | PCI compliance | Payment data fields | Compliance status + violations | Deterministic, auditable, regulatory requirement |
| **DBSCAN** | Fraud pattern clustering | Fraudulent transaction features | Fraud clusters/patterns | Identifies organized fraud rings |

**Input Data:**
- `orders` table: order_id, total, order_date, customer_id
- `payments` table: payment_method, card_number, payment_status
- `customers` table: customer_id, registration_date, location
- `shipments` table: shipping_address, delivery_status

**Output Analytics Tables:**
- `fraud_detections`: Flagged transactions with fraud scores
- `risk_scores`: Customer risk scores (low/medium/high)
- `compliance_checks`: PCI DSS audit results
- `anomaly_detections`: Unusual patterns requiring investigation

**Fraud Detection Features:**
- Transaction amount (z-score)
- Time of transaction (unusual hours)
- Geographic location (IP vs. billing address)
- Payment method changes
- Velocity checks (transactions per hour)
- Device fingerprinting

**PCI DSS Compliance Checks:**
- Card number masking (PAN truncation)
- CVV not stored
- Encryption at rest
- Access logging
- Secure transmission (TLS 1.2+)

**Alternative Models:**
- **Autoencoders**: Neural network-based anomaly detection
- **One-Class SVM**: Alternative anomaly detection
- **LightGBM**: Faster alternative to Gradient Boosting
- **Graph Neural Networks**: For fraud ring detection
- **LSTM**: For sequential fraud pattern detection

---

#### 4. Global Market Pulse - Market Intelligence

**Purpose:** Market opportunity identification and competitive analysis

**AI Models Used:**

| Model | Purpose | Input | Output | Rationale |
|-------|---------|-------|--------|-----------|
| **Market Basket Analysis (Apriori)** | Product associations | Transaction baskets | Association rules (support, confidence, lift) | Identifies cross-sell opportunities, interpretable rules |
| **Multi-Criteria Decision Analysis** | Opportunity scoring | Market metrics (size, growth, competition) | Opportunity score (0-100) | Combines multiple factors, transparent scoring |
| **Time Series Decomposition** | Trend analysis | Sales time series | Trend + seasonal + residual components | Separates signal from noise, identifies patterns |
| **K-Means Clustering** | Regional segmentation | Geographic + demographic data | Regional clusters | Groups similar markets for targeted strategies |
| **Linear Regression** | Price comparison | Product prices across regions | Price gaps and opportunities | Simple, interpretable, sufficient for price analysis |

**Input Data:**
- `products` table: product_id, category, price
- `orders` table: order_date, total, customer_id
- `order_items` table: product_id, quantity
- `customers` table: location, demographics
- `categories` table: category hierarchy

**Output Analytics Tables:**
- `market_opportunities`: Scored opportunities with revenue estimates
- `regional_analysis`: Performance by geographic region
- `competitor_analysis`: Competitive positioning (requires external data)
- `market_share`: Category-level market share estimates
- `product_associations`: Cross-sell recommendations

**Opportunity Scoring Factors:**
- Market size (addressable customers)
- Growth rate (YoY trend)
- Competition intensity (product density)
- Profit margin potential
- Strategic fit

**Alternative Models:**
- **FP-Growth**: Faster alternative to Apriori for large datasets
- **Collaborative Filtering**: For product recommendations
- **Topic Modeling (LDA)**: For market segment discovery
- **Regression Trees**: For opportunity scoring with interactions
- **Neural Collaborative Filtering**: Deep learning for recommendations

---

#### 5. Retail Copilot - Conversational AI

**Purpose:** AI-powered assistant for retail teams with natural language interface

**AI Models Used:**

| Model | Purpose | Input | Output | Rationale |
|-------|---------|-------|--------|-----------|
| **BERT/DistilBERT** | Intent classification | User query text | Intent category + confidence | State-of-art NLP, contextual understanding, pre-trained |
| **Named Entity Recognition (NER)** | Entity extraction | User query text | Entities (products, dates, amounts) | Extracts structured data from unstructured text |
| **Sentence Transformers** | Semantic similarity | Query + knowledge base | Most similar documents | Finds relevant information for query answering |
| **GPT-based Models (AWS Bedrock)** | Response generation | Context + query | Natural language response | Generates human-like responses, conversational |
| **Pattern Mining** | Query pattern analysis | Historical queries | Common patterns + templates | Identifies frequent query types for optimization |

**Input Data:**
- `products` table: Product catalog
- `orders` table: Order history
- `customers` table: Customer information
- `inventory` table: Stock levels
- Conversation history (stored in DynamoDB)

**Output Analytics Tables:**
- `query_patterns`: Common query templates and frequencies
- `intent_distribution`: Distribution of user intents
- `conversation_analytics`: Conversation metrics (length, satisfaction)
- `user_behavior`: User interaction patterns

**Supported Intents:**
- Product search ("Show me laptops under $1000")
- Inventory check ("Do we have iPhone 15 in stock?")
- Order status ("What's the status of order #12345?")
- Sales reports ("Show me sales for last month")
- Customer lookup ("Find customer John Smith")
- Recommendations ("What products should I recommend?")

**NLP Pipeline:**
```
User Query
    ↓
Intent Classification (BERT)
    ↓
Entity Extraction (NER)
    ↓
Query Understanding
    ↓
Database Query (Natural Language to SQL)
    ↓
Response Generation (GPT)
    ↓
Natural Language Response
```

**Alternative Models:**
- **RoBERTa**: More robust BERT variant
- **ALBERT**: Lighter BERT alternative
- **T5**: Text-to-text transformer for query generation
- **BART**: For abstractive summarization
- **Rasa**: Open-source conversational AI framework
- **DialogFlow**: Google's conversational AI platform

---

### Model Training & Deployment

**Training Infrastructure:**
- AWS SageMaker for model training
- Hyperparameter tuning with SageMaker Automatic Model Tuning
- Model versioning with SageMaker Model Registry
- A/B testing for model comparison

**Model Monitoring:**
- CloudWatch metrics for model performance
- Data drift detection
- Model accuracy tracking
- Retraining triggers based on performance degradation

**Model Versioning:**
- Semantic versioning (v1.0.0, v1.1.0, v2.0.0)
- Model artifacts stored in S3
- Metadata tracked in DynamoDB
- Rollback capability for failed deployments

---

## Modules

### 1. AI Systems (5 Lambda Functions)

#### Market Intelligence Hub
**Purpose:** Time series forecasting and market analytics

**Features:**
- ARIMA, Prophet, LSTM forecasting models
- Automatic model selection
- Confidence intervals
- Performance metrics (RMSE, MAE, MAPE, R²)

**API Endpoints:**
- `POST /market-intelligence/forecast` - Generate forecasts
- `POST /market-intelligence/compare-models` - Compare model performance
- `GET /market-intelligence/trends` - Get market trends

**Tech Stack:** Python 3.11, scikit-learn, Prophet, TensorFlow

**Location:** `ai-systems/market-intelligence-hub/`

---

#### Demand Insights Engine
**Purpose:** Customer insights, demand forecasting, pricing optimization

**Features:**
- Customer segmentation (K-Means, RFM analysis)
- Demand forecasting (XGBoost)
- Price elasticity analysis
- Customer lifetime value (CLV) prediction
- Churn prediction

**API Endpoints:**
- `GET /demand-insights/segments` - Customer segmentation
- `POST /demand-insights/forecast` - Demand forecasting
- `POST /demand-insights/price-elasticity` - Price elasticity
- `POST /demand-insights/clv` - CLV prediction
- `POST /demand-insights/churn` - Churn prediction

**Tech Stack:** Python 3.11, XGBoost, scikit-learn, pandas

**Location:** `ai-systems/demand-insights-engine/`

---

#### Compliance Guardian
**Purpose:** Fraud detection, risk scoring, PCI DSS compliance

**Features:**
- Fraud detection (Isolation Forest)
- Risk scoring (Gradient Boosting)
- PCI DSS compliance monitoring
- Document understanding (NLP with transformers)
- Credit card masking

**API Endpoints:**
- `POST /compliance/fraud-detection` - Detect fraudulent transactions
- `POST /compliance/risk-score` - Calculate risk scores
- `GET /compliance/high-risk-transactions` - Get high-risk transactions
- `POST /compliance/pci-compliance` - Check PCI DSS compliance
- `GET /compliance/compliance-report` - Generate compliance report

**Tech Stack:** Python 3.11, scikit-learn, XGBoost, transformers

**Location:** `ai-systems/compliance-guardian/`

---

#### Retail Copilot
**Purpose:** AI-powered assistant for retail teams

**Features:**
- Natural language chat interface
- Natural language to SQL conversion
- Microsoft Copilot-like behavior
- Conversation history
- Product recommendations
- Sales reports

**API Endpoints:**
- `POST /copilot/chat` - Chat with copilot
- `GET /copilot/conversations` - Get conversation history
- `POST /copilot/conversation` - Create new conversation
- `GET /copilot/inventory` - Query inventory
- `GET /copilot/orders` - Query orders
- `POST /copilot/recommendations` - Get product recommendations

**Tech Stack:** Python 3.11, AWS Bedrock (Claude), boto3

**Location:** `ai-systems/retail-copilot/`

---

#### Global Market Pulse
**Purpose:** Global market trends and expansion opportunities

**Features:**
- Market trend analysis (time series decomposition)
- Regional price comparison
- Market opportunity scoring (MCDA)
- Competitor analysis
- Currency conversion support

**API Endpoints:**
- `GET /global-market/trends` - Market trends
- `GET /global-market/regional-prices` - Regional prices
- `POST /global-market/price-comparison` - Compare prices
- `POST /global-market/opportunities` - Market opportunities
- `POST /global-market/competitor-analysis` - Competitor analysis

**Tech Stack:** Python 3.11, scipy, statsmodels, pandas

**Location:** `ai-systems/global-market-pulse/`

---

### 2. Analytics Service

**Purpose:** Execute Athena queries and provide analytics endpoints

**Features:**
- Secure query execution with SQL injection prevention
- JWT authentication
- Multi-system support
- Athena integration

**API Endpoints:**
- `GET /analytics/{system}/query` - Execute Athena query
- `POST /analytics/{system}/forecast` - Generate forecast
- `GET /analytics/{system}/insights` - Get insights

**Tech Stack:** Python 3.11, boto3, PyAthena, pandas

**Location:** `analytics-service/`

---

### 3. Authentication Service

**Purpose:** User authentication and authorization

**Features:**
- User registration with email validation
- User login with JWT token generation
- Password reset via email
- JWT token verification
- Secure password hashing (BCrypt)

**API Endpoints:**
- `POST /auth/register` - Register new user
- `POST /auth/login` - Login and get JWT token
- `POST /auth/forgot-password` - Request password reset
- `POST /auth/reset-password` - Reset password
- `POST /auth/verify` - Verify JWT token

**Tech Stack:** Java 17, AWS Lambda, DynamoDB, Secrets Manager, SES

**Location:** `auth-service/`

---

### 4. Frontend Application

**Purpose:** React-based dashboard for all AI systems

**Features:**
- User authentication (login, register, forgot password)
- JWT token management
- Home page with 5 system cards
- Protected routes
- Dashboard navigation
- Responsive design

**Tech Stack:** React 18, TypeScript, Vite, Material-UI, React Router

**Location:** `frontend/`

---

### 5. Data Processing Pipeline

**Purpose:** Validate, transform, and run AI models to generate analytics

**Architecture:**
```
Raw Bucket (Shared)
    ↓
[Processor 1: raw_to_curated.py]
├─ Schema validation
├─ Data deduplication
├─ Business rules validation
└─ PCI DSS compliance checks
    ↓
Curated Bucket (Shared)
    ↓
[Processor 2: batch_ai_processor.py]
├─ Load ALL curated data
├─ Run 5 AI systems in parallel:
│   ├─ Market Intelligence Hub (ARIMA, Prophet, LSTM)
│   ├─ Demand Insights Engine (K-Means, XGBoost, Random Forest)
│   ├─ Compliance Guardian (Isolation Forest, Rule Engine)
│   ├─ Global Market Pulse (Market Basket, MCDA)
│   └─ Retail Copilot (BERT, NER, Pattern Mining)
└─ Write analytics to system-specific prod buckets
    ↓
5 Prod Buckets (System-Specific)
    ↓
Glue Crawlers (Auto-triggered)
    ↓
Athena Tables (Auto-created)
```

**Key Components:**

1. **raw_to_curated.py** - Data Validation
   - Schema validation against expected structure
   - Duplicate detection and removal
   - Business rules enforcement (e.g., price > 0)
   - PCI DSS compliance (card masking, encryption)
   - Data quality scoring

2. **curated_to_prod_ai.py** - AI Model Processor
   - System-specific AI model execution
   - Feature engineering for ML models
   - Model inference and prediction
   - Analytics DataFrame generation
   - Parquet file writing with compression

3. **batch_ai_processor.py** - Orchestrator
   - Parallel execution of 5 AI systems
   - Error handling and retry logic
   - Progress tracking and logging
   - Glue Crawler triggering
   - Performance metrics collection

**AI/ML Libraries:**
- scikit-learn 1.3.0 (K-Means, Random Forest, Isolation Forest)
- XGBoost 1.7.0 (Gradient Boosting)
- Prophet 1.1.4 (Time series forecasting)
- statsmodels 0.14.0 (ARIMA, SARIMA)
- TensorFlow 2.13.0 (LSTM, Neural Networks)
- transformers 4.30.0 (BERT, NER)
- pandas 2.0.0 (Data manipulation)
- pyarrow 12.0.0 (Parquet I/O)

**Deployment:**
- Docker container on AWS Batch
- Triggered by EventBridge on S3 uploads
- Scales automatically based on workload
- Logs to CloudWatch

**Tech Stack:** Python 3.11, pandas, pyarrow, scikit-learn, XGBoost, TensorFlow, Docker, AWS Batch

**Location:** `data-processing/`

---

### 6. Infrastructure (Terraform)

**Purpose:** Infrastructure as Code for all AWS resources

**Modules:**
- **VPC** - Network foundation with public/private subnets
- **KMS** - Encryption key management
- **IAM** - Identity and access management
- **S3 Data Lake** - Data storage for each AI system (15 buckets)
- **DMS** - Real-time data replication from MySQL to S3
- **API Gateway** - REST API with 60+ endpoints
- **CI/CD Pipeline** - Automated deployment pipeline
- **S3 Frontend** - Static website hosting

**Tech Stack:** Terraform 1.5+, AWS

**Location:** `terraform/`

---

### 7. Database

**Purpose:** MySQL database schema and setup scripts

**Features:**
- Main eCommerce schema (customers, products, orders, etc.)
- System-specific schemas for each AI system
- Sample data generator
- DMS replication setup

**Tech Stack:** MySQL 9.6, Python 3.11

**Location:** `database/`

---

## Quick Start Guide

### Prerequisites

#### Required Tools
- **AWS CLI** - Version 2.x or higher
- **Terraform** - Version 1.5 or higher
- **Git** - For repository access
- **PowerShell** - Windows PowerShell 5.1+ or PowerShell Core 7+
- **MySQL** - Version 9.6 (on-premises server)

#### AWS Account Requirements
- **Account ID:** 450133579764
- **Region:** us-east-2 (Ohio)
- **IAM Permissions:** Administrator access or equivalent

#### MySQL Server Requirements
- **Host:** 172.20.10.2
- **Port:** 3306
- **Database:** ecommerce
- **User:** dms_remote
- **Password:** SaiesaShanmukha@123
- **Bind Address:** 0.0.0.0 (must accept remote connections)

### Step 1: Verify MySQL Server

```powershell
# Verify MySQL bind address and connectivity
cd database
.\check-mysql-bind-address.ps1

# Verify MySQL is listening on all interfaces
netstat -ano | findstr :3306
# Should show: 0.0.0.0:3306

# Test dms_remote user connection
mysql -u dms_remote -p
# Enter password: SaiesaShanmukha@123
```

### Step 2: Run Prerequisite Scripts

These scripts create AWS resources that Terraform depends on:

```powershell
cd terraform

# 1. Create Terraform backend (S3 + DynamoDB)
.\create-backend-resources.ps1 -Region us-east-2

# 2. Create DMS VPC role (required by AWS DMS)
.\create-dms-vpc-role.ps1

# 3. Create MySQL password secret
.\create-mysql-secret.ps1 -MySQLPassword "SaiesaShanmukha@123" -Environment dev

# IMPORTANT: Copy the Secret ARN from output!
```

### Step 3: Configure Terraform Variables

Edit `terraform/terraform.dev.tfvars`:

```hcl
aws_region   = "us-east-2"
environment  = "dev"
project_name = "futureim-ecommerce-ai-platform"
vpc_cidr     = "10.0.0.0/16"

# GitHub Configuration
github_repo   = "futureimadmin/hackathons"
github_branch = "master"
github_token  = "ghp_your_token_here"

# MySQL Configuration
mysql_server_ip = "172.20.10.2"
mysql_port      = 3306
mysql_database  = "ecommerce"
mysql_username  = "dms_remote"
mysql_password_secret_arn = "arn:aws:secretsmanager:us-east-2:450133579764:secret:..."  # From Step 2
```

### Step 4: Deploy Infrastructure with Terraform

```powershell
cd terraform

# Initialize Terraform with backend configuration
terraform init -backend-config=backend.tfvars

# Review the execution plan
terraform plan -var-file="terraform.dev.tfvars"

# Deploy infrastructure (type 'yes' when prompted)
terraform apply -var-file="terraform.dev.tfvars"
```

**Deployment Time:** 20-25 minutes

### Step 5: Complete GitHub Connection

1. Open AWS Console
2. Navigate to: Developer Tools → Connections
3. Find connection: `futureim-github-dev`
4. Click "Update pending connection"
5. Authorize GitHub access
6. Verify status shows "AVAILABLE"

### Step 6: Start DMS Replication

```powershell
# List DMS replication tasks
aws dms describe-replication-tasks `
  --query 'ReplicationTasks[].ReplicationTaskIdentifier'

# Start each replication task
aws dms start-replication-task `
  --replication-task-arn <task-arn> `
  --start-replication-task-type start-replication
```

Or use AWS Console:
- DMS → Database migration tasks
- Select task → Actions → Start

### Step 7: Verify Deployment

```powershell
# Check Terraform outputs
terraform output

# Verify DMS replication
cd database
.\verify-dms-replication.ps1

# Check pipeline status
aws codepipeline get-pipeline-state `
  --name futureim-ecommerce-ai-platform-pipeline-dev
```

---

## Configuration

### Terraform Variables

Edit `terraform/terraform.dev.tfvars`:

```hcl
aws_region   = "us-east-2"
environment  = "dev"
project_name = "futureim-ecommerce-ai-platform"
vpc_cidr     = "10.0.0.0/16"

github_repo   = "futureimadmin/hackathons"
github_branch = "master"
github_token  = "ghp_your_token"

mysql_server_ip = "172.20.10.2"
mysql_port      = 3306
mysql_database  = "ecommerce"
mysql_username  = "dms_remote"
mysql_password_secret_arn = "arn:aws:secretsmanager:us-east-2:450133579764:secret:..."
```

### MySQL Configuration

```ini
# my.ini
[mysqld]
bind-address = 0.0.0.0
port = 3306
log_bin = mysql-bin
binlog_format = ROW
```

```sql
-- Create DMS user
CREATE USER 'dms_remote'@'%' IDENTIFIED BY 'SaiesaShanmukha@123';
GRANT REPLICATION SLAVE ON *.* TO 'dms_remote'@'%';
GRANT SELECT ON ecommerce.* TO 'dms_remote'@'%';
FLUSH PRIVILEGES;
```

---

### Model Performance & Metrics

#### Forecasting Models (Market Intelligence Hub)

**Evaluation Metrics:**
- **RMSE (Root Mean Square Error)**: Measures average prediction error
- **MAE (Mean Absolute Error)**: Average absolute difference
- **MAPE (Mean Absolute Percentage Error)**: Percentage-based error
- **R² Score**: Proportion of variance explained

**Target Performance:**
- MAPE < 10% for short-term forecasts (1-7 days)
- MAPE < 20% for medium-term forecasts (8-30 days)
- R² > 0.85 for model fit

**Model Selection Logic:**
```python
if data_has_strong_seasonality:
    use Prophet
elif data_is_stationary:
    use ARIMA
elif data_has_complex_patterns:
    use LSTM
else:
    use moving_average
```

#### Classification Models (Compliance Guardian, Demand Insights)

**Evaluation Metrics:**
- **Precision**: True positives / (True positives + False positives)
- **Recall**: True positives / (True positives + False negatives)
- **F1 Score**: Harmonic mean of precision and recall
- **AUC-ROC**: Area under ROC curve

**Target Performance:**
- Fraud Detection: Precision > 0.90, Recall > 0.85
- Churn Prediction: AUC-ROC > 0.80
- Risk Scoring: F1 Score > 0.75

**Handling Imbalanced Data:**
- SMOTE (Synthetic Minority Over-sampling)
- Class weights adjustment
- Ensemble methods
- Anomaly detection for rare events

#### Clustering Models (Demand Insights, Global Market Pulse)

**Evaluation Metrics:**
- **Silhouette Score**: Measures cluster cohesion (-1 to 1)
- **Davies-Bouldin Index**: Lower is better
- **Calinski-Harabasz Index**: Higher is better
- **Inertia**: Within-cluster sum of squares

**Target Performance:**
- Silhouette Score > 0.5
- Clear business interpretation of clusters
- Stable clusters across time periods

**Optimal Cluster Selection:**
- Elbow method for K-Means
- Silhouette analysis
- Business constraints (e.g., 4 customer tiers)

#### NLP Models (Retail Copilot)

**Evaluation Metrics:**
- **Intent Accuracy**: Correct intent classification rate
- **Entity F1 Score**: Entity extraction accuracy
- **Response Quality**: Human evaluation (1-5 scale)
- **Query Success Rate**: Queries successfully answered

**Target Performance:**
- Intent Accuracy > 0.90
- Entity F1 Score > 0.85
- Response Quality > 4.0/5.0
- Query Success Rate > 0.95

---

### Model Retraining Strategy

**Retraining Triggers:**
1. **Performance Degradation**: Metrics drop below threshold
2. **Data Drift**: Input distribution changes significantly
3. **Scheduled**: Monthly retraining for all models
4. **New Data**: Significant new data available (>20% increase)

**Retraining Process:**
```
1. Detect trigger (CloudWatch alarm or schedule)
2. Extract latest training data from curated bucket
3. Train new model version on SageMaker
4. Validate on holdout set
5. Compare with current production model
6. If better: Deploy new version
7. If worse: Alert data science team
8. Log all metrics to CloudWatch
```

**A/B Testing:**
- Deploy new model to 10% of traffic
- Monitor performance for 7 days
- Gradual rollout if successful (10% → 50% → 100%)
- Automatic rollback if metrics degrade

---

## Operations

### Daily Operations

```powershell
# Check Terraform state
cd terraform
terraform show

# Check DMS replication
cd database
.\verify-dms-replication.ps1

# Deploy code changes
git add .
git commit -m "Changes"
git push origin master
# Pipeline auto-triggers
```

### Maintenance

```powershell
# Update infrastructure
cd terraform
terraform plan -var-file="terraform.dev.tfvars"
terraform apply -var-file="terraform.dev.tfvars"

# Restart DMS replication
aws dms stop-replication-task --replication-task-arn <arn>
aws dms start-replication-task --replication-task-arn <arn> --start-replication-task-type start-replication

# Destroy environment (use with caution!)
terraform destroy -var-file="terraform.dev.tfvars"
```

---

## Troubleshooting

### DMS Cannot Connect to MySQL

```powershell
# 1. Check MySQL bind address
cd database
.\check-mysql-bind-address.ps1

# 2. Verify MySQL is listening
netstat -ano | findstr :3306

# 3. Test connection
Test-NetConnection -ComputerName 172.20.10.2 -Port 3306

# 4. Check MySQL user
mysql -h 172.20.10.2 -u dms_remote -p
```

### Pipeline Not Auto-Triggering

```powershell
# 1. Check GitHub connection
aws codestar-connections get-connection --connection-arn <arn>

# 2. Manually trigger
aws codepipeline start-pipeline-execution `
  --name futureim-ecommerce-ai-platform-pipeline-dev
```

### Lambda Timeout

```powershell
# Increase timeout
aws lambda update-function-configuration `
  --function-name <name> `
  --timeout 300

# Increase memory
aws lambda update-function-configuration `
  --function-name <name> `
  --memory-size 3008
```

### AI Model Performance Issues

```powershell
# Check Batch job logs
aws logs tail /aws/batch/job --follow

# Check model metrics in CloudWatch
aws cloudwatch get-metric-statistics `
  --namespace "AIModels" `
  --metric-name "ModelAccuracy" `
  --start-time 2026-02-01T00:00:00Z `
  --end-time 2026-02-02T00:00:00Z `
  --period 3600 `
  --statistics Average

# Verify Parquet files in prod buckets
aws s3 ls s3://market-intelligence-hub-prod-450133579764/analytics/ --recursive

# Check Glue Crawler status
aws glue get-crawler --name market-intelligence-hub-crawler

# Query Athena to verify data
aws athena start-query-execution `
  --query-string "SELECT COUNT(*) FROM market_intelligence_hub.forecasts" `
  --result-configuration "OutputLocation=s3://athena-results-450133579764/"
```

### Data Quality Issues

```powershell
# Check data validation logs
aws logs filter-log-events `
  --log-group-name /aws/batch/data-processing `
  --filter-pattern "VALIDATION_ERROR"

# Verify curated data quality
aws s3 cp s3://ecommerce-curated-450133579764/ecommerce/orders/orders_validated.parquet . 
# Then inspect locally with pandas

# Check for missing data
aws athena start-query-execution `
  --query-string "SELECT COUNT(*) FROM ecommerce_curated.orders WHERE total IS NULL"
```

### Model Training Failures

```powershell
# Check SageMaker training job status
aws sagemaker describe-training-job --training-job-name <job-name>

# View training logs
aws logs tail /aws/sagemaker/TrainingJobs --follow

# Check for data drift
aws cloudwatch get-metric-statistics `
  --namespace "DataQuality" `
  --metric-name "DataDrift" `
  --start-time 2026-02-01T00:00:00Z `
  --end-time 2026-02-02T00:00:00Z `
  --period 86400 `
  --statistics Maximum
```

---

### AI/ML Dependencies

The data processing pipeline includes comprehensive AI/ML libraries:

```txt
# Core Data Processing
pandas==2.0.0
pyarrow==12.0.0
boto3==1.26.0
s3fs==2023.5.0

# Machine Learning - Classical
scikit-learn==1.3.0          # K-Means, Random Forest, Isolation Forest
xgboost==1.7.0               # Gradient Boosting for CLV, Risk Scoring
lightgbm==4.0.0              # Alternative gradient boosting

# Time Series Forecasting
prophet==1.1.4               # Facebook Prophet for seasonal forecasting
statsmodels==0.14.0          # ARIMA, SARIMA, time series analysis
tensorflow==2.13.0           # LSTM, Neural Networks
keras==2.13.0                # High-level neural network API

# Natural Language Processing
transformers==4.30.0         # BERT, DistilBERT, NER models
sentence-transformers==2.2.2 # Semantic similarity
spacy==3.6.0                 # NLP pipeline, entity extraction
nltk==3.8.1                  # Text processing utilities

# Deep Learning
torch==2.0.1                 # PyTorch for custom models
torchvision==0.15.2          # Computer vision (future use)

# Data Validation & Quality
great-expectations==0.17.0   # Data quality validation
pydantic==2.0.0              # Data validation with type hints

# Utilities
numpy==1.24.0                # Numerical computing
scipy==1.11.0                # Scientific computing
matplotlib==3.7.0            # Visualization (for model analysis)
seaborn==0.12.0              # Statistical visualization
```

**Total Docker Image Size:** ~3.5 GB (optimized with multi-stage build)

---

## Project Structure

```
futureim-ecommerce-ai-platform/
├── ai-systems/                    # 5 AI Lambda functions
│   ├── compliance-guardian/       # Fraud detection & compliance
│   ├── demand-insights-engine/    # Customer insights & forecasting
│   ├── global-market-pulse/       # Market trends & opportunities
│   ├── market-intelligence-hub/   # Time series forecasting
│   └── retail-copilot/            # AI assistant
├── analytics-service/             # Analytics API service
├── auth-service/                  # Authentication service (Java)
├── frontend/                      # React dashboard
├── data-processing/               # Data pipeline (Docker)
├── database/                      # MySQL schema & scripts
├── terraform/                     # Infrastructure as Code
│   ├── create-backend-resources.ps1  # Prerequisite: Create S3 + DynamoDB
│   ├── create-dms-vpc-role.ps1       # Prerequisite: Create DMS IAM role
│   ├── create-mysql-secret.ps1       # Prerequisite: Create MySQL secret
│   └── modules/                   # Reusable modules
└── README.md                     # This file
```

---

## Key Scripts

### Prerequisite Scripts (Run Once)

```powershell
# Create Terraform backend resources
terraform\create-backend-resources.ps1 -Region us-east-2

# Create DMS VPC role
terraform\create-dms-vpc-role.ps1

# Create MySQL password secret
terraform\create-mysql-secret.ps1 -MySQLPassword "password" -Environment dev
```

### Database Scripts

```powershell
# Check MySQL configuration
database\check-mysql-bind-address.ps1

# Setup database schema
database\setup-database.ps1

# Verify DMS replication
database\verify-dms-replication.ps1
```

### Build Scripts

```powershell
# Build AI systems
ai-systems\<system-name>\build.ps1

# Build analytics service
analytics-service\build.ps1

# Build auth service
auth-service\build.ps1

# Build data processing
data-processing\build-and-push.ps1
```

---

## Monitoring

### CloudWatch Metrics

- Lambda invocations, errors, duration
- DMS replication lag, throughput
- API Gateway requests, errors, latency
- S3 object count, storage size

### CloudWatch Logs

```powershell
# Lambda logs
aws logs tail /aws/lambda/<function-name> --follow

# DMS logs
aws logs tail /aws/dms/futureim-ecommerce-ai-platform-dev --follow

# Search for errors
aws logs filter-log-events `
  --log-group-name /aws/lambda/<function-name> `
  --filter-pattern "ERROR"
```

---

## Security

### Security Features

- ✅ KMS encryption at rest
- ✅ TLS 1.2+ encryption in transit
- ✅ Secrets Manager for credentials
- ✅ IAM roles with least privilege
- ✅ VPC isolation for sensitive resources
- ✅ Security groups with minimal ports
- ✅ CloudTrail logging enabled
- ✅ VPC Flow Logs enabled

### Security Checklist

- [ ] All S3 buckets encrypted
- [ ] No hardcoded credentials
- [ ] API Gateway authentication enabled
- [ ] CloudTrail enabled
- [ ] VPC Flow Logs enabled
- [ ] Security groups follow least privilege
- [ ] Regular security audits

---

## Cost Optimization

### Current Monthly Costs (Estimated)

- DMS: ~$144/month (dms.t3.medium)
- Lambda: ~$50/month (pay per invocation)
- S3: ~$100/month (pay per GB)
- API Gateway: ~$30/month (pay per request)
- CodePipeline: $1/month
- **Total: ~$325/month**

### Cost Reduction Tips

1. Stop DMS when not replicating
2. Use S3 lifecycle policies for old data
3. Optimize Lambda memory allocation
4. Clean up old CloudWatch logs
5. Use reserved capacity for predictable workloads

---

## Future Enhancements

### AI Model Improvements

#### Market Intelligence Hub
- [ ] Implement ensemble forecasting (combine ARIMA + Prophet + LSTM)
- [ ] Add external data sources (economic indicators, weather, holidays)
- [ ] Implement automatic hyperparameter tuning
- [ ] Add forecast explainability (SHAP values)
- [ ] Multi-horizon forecasting (1-day, 7-day, 30-day, 90-day)

#### Demand Insights Engine
- [ ] Deep learning for CLV (Neural Networks with embeddings)
- [ ] Real-time customer segmentation updates
- [ ] Personalized product recommendations (Collaborative Filtering)
- [ ] Dynamic pricing optimization (Reinforcement Learning)
- [ ] Cohort analysis and retention curves

#### Compliance Guardian
- [ ] Real-time fraud detection (streaming with Kinesis)
- [ ] Graph Neural Networks for fraud ring detection
- [ ] Explainable AI for compliance decisions
- [ ] Automated compliance report generation
- [ ] Integration with external fraud databases

#### Global Market Pulse
- [ ] Web scraping for competitor pricing (with rate limiting)
- [ ] Sentiment analysis from social media
- [ ] Market basket analysis with FP-Growth
- [ ] Geographic expansion opportunity scoring
- [ ] Supply chain optimization

#### Retail Copilot
- [ ] Multi-turn conversation support
- [ ] Voice interface integration
- [ ] Proactive insights and alerts
- [ ] Integration with external knowledge bases
- [ ] Multi-language support

### Infrastructure Improvements
- [ ] SageMaker Pipelines for MLOps
- [ ] Feature Store for feature reuse
- [ ] Model Registry for version control
- [ ] Automated model monitoring and alerting
- [ ] Cost optimization for AI workloads

### Data Pipeline Improvements
- [ ] Real-time streaming with Kinesis
- [ ] Incremental processing (process only new data)
- [ ] Data lineage tracking
- [ ] Automated data quality monitoring
- [ ] Delta Lake for ACID transactions

---

## Support

### Documentation

- **Complete Operations Guide:** `docs/RUNBOOK.md`
- **Module READMEs:** Each module has detailed documentation
- **AWS Documentation:** https://docs.aws.amazon.com/

### Contact

- **Technical Support:** sales@futureim.in
- **AWS Support:** AWS Support Center

---

## Frequently Asked Questions (FAQ)

### Architecture Questions

**Q: Why do we have only 1 raw bucket instead of 5?**
A: Raw data is the same for all systems (ecommerce data from MySQL). Having 5 copies would be redundant and wasteful. All systems share the same raw data.

**Q: Why do we have only 1 curated bucket instead of 5?**
A: Curated data is validated/cleaned raw data, still the same for all systems. The differentiation happens at the AI processing stage, not the validation stage.

**Q: Why do we have 5 prod buckets?**
A: Each AI system generates unique analytics. Market Intelligence Hub creates forecasts, Demand Insights creates customer segments, etc. These are system-specific outputs.

**Q: Where are analytics tables stored?**
A: Analytics tables are ONLY in Athena (created automatically by Glue Crawlers from Parquet files). They are NOT in MySQL. MySQL only stores operational data.

**Q: How are Athena tables created?**
A: Glue Crawlers automatically scan Parquet files in prod buckets and infer schemas to create Athena tables. No manual table creation needed.

### AI Model Questions

**Q: Why use ARIMA instead of just Prophet?**
A: ARIMA is better for stationary time series without strong seasonality. Prophet excels with seasonal patterns and holidays. We use model selection to pick the best one for each dataset.

**Q: Why XGBoost for CLV instead of Linear Regression?**
A: CLV has non-linear relationships (e.g., diminishing returns, customer lifecycle stages). XGBoost captures these complex patterns better than linear models.

**Q: Why Isolation Forest for fraud detection?**
A: Fraud is rare (anomaly detection problem). Isolation Forest is specifically designed for anomaly detection and doesn't require labeled fraud examples.

**Q: Why BERT for intent classification instead of simpler models?**
A: BERT understands context and semantics, not just keywords. It can distinguish "show me orders" from "cancel my order" even though both contain "order".

**Q: How often are models retrained?**
A: Monthly scheduled retraining + automatic retraining when performance degrades or significant new data arrives.

**Q: Can I use different models?**
A: Yes! The architecture is modular. You can swap models by updating `curated_to_prod_ai.py`. See "Alternative Models" sections above.

### Data Pipeline Questions

**Q: Where does AI processing happen?**
A: In the data-processing pipeline (AWS Batch), NOT in Lambda functions. Lambda functions only query the pre-computed analytics.

**Q: How long does AI processing take?**
A: Depends on data volume. Typically 10-30 minutes for full processing of all 5 systems in parallel.

**Q: What triggers AI processing?**
A: EventBridge automatically triggers when new Parquet files land in the curated bucket.

**Q: Can I run AI processing manually?**
A: Yes, use `database/manual-pipeline-trigger.ps1` or trigger the Batch job directly via AWS Console.

**Q: How do I add a new AI model?**
A: 
1. Add model code to `curated_to_prod_ai.py`
2. Update `requirements.txt` with new dependencies
3. Rebuild Docker image: `data-processing/build-and-push.ps1`
4. Deploy and test

### Performance Questions

**Q: Why is forecasting slow?**
A: LSTM models are computationally expensive. Consider using ARIMA/Prophet for faster results, or increase Batch compute resources.

**Q: How can I improve model accuracy?**
A: 
1. Add more training data
2. Feature engineering (create better input features)
3. Hyperparameter tuning
4. Ensemble methods (combine multiple models)
5. Add external data sources

**Q: What if a model fails?**
A: The pipeline has error handling. Failed models are logged, but other models continue processing. Check CloudWatch logs for details.

### Cost Questions

**Q: How much do AI models cost to run?**
A: AWS Batch charges for compute time. Typical cost: $5-20 per full pipeline run, depending on data volume and model complexity.

**Q: How can I reduce AI processing costs?**
A: 
1. Use Spot instances for Batch
2. Optimize model code (vectorization, caching)
3. Process only changed data (incremental processing)
4. Use simpler models where appropriate
5. Schedule processing during off-peak hours

**Q: Do Lambda functions incur AI costs?**
A: No, Lambda functions only query pre-computed analytics. The AI processing cost is in Batch, not Lambda.

---

## License

Proprietary - FutureIM

---

## Version History

- **1.1** (February 2, 2026) - AI Models Implementation
  - Comprehensive AI/ML pipeline with 15+ models
  - Corrected architecture (1 raw, 1 curated, 5 prod buckets)
  - Market Intelligence Hub: ARIMA, Prophet, LSTM forecasting
  - Demand Insights Engine: K-Means, XGBoost, Random Forest
  - Compliance Guardian: Isolation Forest, fraud detection
  - Global Market Pulse: Market basket analysis, opportunity scoring
  - Retail Copilot: BERT, NER, conversational AI
  - Automated model retraining and monitoring
  - Comprehensive documentation and FAQ

- **1.0** (February 1, 2026) - Initial production release
  - 5 AI systems deployed
  - Complete CI/CD pipeline
  - Real-time data replication
  - React frontend
  - Comprehensive documentation

---

**Last Updated:** February 2, 2026  
**Status:** Production Ready with AI/ML Pipeline  
**Maintained By:** FutureIM Engineering Team
