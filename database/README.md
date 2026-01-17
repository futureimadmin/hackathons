# On-Premise MySQL Database Setup

This directory contains SQL schemas and data generation scripts for the eCommerce AI Analytics Platform on-premise MySQL database.

## Overview

The database consists of:
- **Main eCommerce Schema**: 10 core tables for customers, products, orders, payments, etc.
- **System-Specific Schemas**: 16 tables for the 5 AI systems
- **Sample Data Generator**: Python script to generate realistic test data

## Requirements

- MySQL 8.0+
- Python 3.8+
- pip (Python package manager)

## Quick Start

### 1. Install MySQL

If MySQL is not installed:

**Windows:**
```powershell
# Download MySQL installer from https://dev.mysql.com/downloads/installer/
# Or use Chocolatey:
choco install mysql
```

**Linux:**
```bash
sudo apt-get update
sudo apt-get install mysql-server
```

**macOS:**
```bash
brew install mysql
```

### 2. Start MySQL Service

**Windows:**
```powershell
net start MySQL80
```

**Linux/macOS:**
```bash
sudo systemctl start mysql
# or
sudo service mysql start
```

### 3. Create Database and Tables

```powershell
# Connect to MySQL
mysql -u root -p

# Run schema scripts
mysql -u root -p < schema/01_main_ecommerce_schema.sql
mysql -u root -p < schema/02_system_specific_schemas.sql
```

Or run from MySQL prompt:
```sql
source schema/01_main_ecommerce_schema.sql;
source schema/02_system_specific_schemas.sql;
```

### 4. Generate Sample Data

```powershell
# Navigate to data generator directory
cd data_generator

# Install Python dependencies
pip install -r requirements.txt

# Run data generator
python generate_sample_data.py
```

This will generate:
- 10,000 customers
- 50 categories
- 5,000 products
- 50,000 orders
- ~125,000 order items
- ~25,000 reviews
- 100 promotions

**Note**: Data generation takes approximately 5-10 minutes depending on your system.

## Database Schema

### Main eCommerce Tables (10)

1. **customers** - Customer profiles and contact information
2. **categories** - Product categories (hierarchical)
3. **products** - Product catalog with pricing
4. **inventory** - Stock levels and warehouse management
5. **orders** - Customer orders
6. **order_items** - Line items for each order
7. **payments** - Payment transactions (PCI DSS compliant)
8. **shipments** - Shipping and delivery tracking
9. **reviews** - Product reviews and ratings
10. **promotions** - Discount codes and campaigns

### System-Specific Tables (16)

#### Market Intelligence Hub (3 tables)
- **market_intelligence_forecasts** - Sales forecasts (ARIMA, Prophet, LSTM)
- **market_trends** - Market trend analysis
- **competitive_pricing** - Competitor price tracking

#### Demand Insights Engine (4 tables)
- **customer_segments** - RFM segmentation
- **demand_forecasts** - Product demand predictions
- **price_elasticity** - Price sensitivity analysis
- **customer_lifetime_value** - CLV predictions

#### Compliance Guardian (3 tables)
- **fraud_detections** - Fraud detection results
- **compliance_checks** - PCI DSS, GDPR compliance
- **risk_scores** - Transaction risk scoring

#### Retail Copilot (3 tables)
- **copilot_conversations** - Chat conversation history
- **copilot_messages** - Individual messages
- **product_recommendations** - AI-generated recommendations

#### Global Market Pulse (3 tables)
- **regional_market_data** - Regional market statistics
- **market_opportunities** - Market expansion opportunities
- **competitor_analysis** - Competitor intelligence

## Database Configuration

### Connection Details

- **Host**: localhost (or 172.20.10.4 for DMS)
- **Port**: 3306
- **Database**: ecommerce_platform
- **User**: root
- **Password**: Srikar@123

### For DMS Replication

The database is configured to work with AWS DMS for continuous replication to S3:

- **Source Endpoint**: MySQL on 172.20.10.4:3306
- **Target**: S3 buckets (raw, curated, prod)
- **Replication**: Full load + CDC (Change Data Capture)

## Data Generation Details

### Realistic Data Features

- **Customers**: Realistic names, addresses, emails (using Faker)
- **Products**: Varied pricing ($9.99 - $999.99)
- **Orders**: Realistic order patterns over 1 year
- **Referential Integrity**: All foreign keys maintained
- **Temporal Data**: Realistic timestamps and date ranges

### Customization

Edit `data_generator/generate_sample_data.py` to customize:

```python
# Data generation parameters
NUM_CUSTOMERS = 10000
NUM_CATEGORIES = 50
NUM_PRODUCTS = 5000
NUM_ORDERS = 50000
NUM_ORDER_ITEMS_PER_ORDER = (1, 5)  # Min, Max
NUM_REVIEWS_PER_PRODUCT = (0, 10)
NUM_PROMOTIONS = 100
```

## Verification

### Check Table Counts

```sql
USE ecommerce_platform;

SELECT 'customers' as table_name, COUNT(*) as count FROM customers
UNION ALL
SELECT 'products', COUNT(*) FROM products
UNION ALL
SELECT 'orders', COUNT(*) FROM orders
UNION ALL
SELECT 'order_items', COUNT(*) FROM order_items
UNION ALL
SELECT 'payments', COUNT(*) FROM payments
UNION ALL
SELECT 'reviews', COUNT(*) FROM reviews;
```

### Sample Queries

```sql
-- Top 10 customers by lifetime value
SELECT customer_id, first_name, last_name, lifetime_value
FROM customers
ORDER BY lifetime_value DESC
LIMIT 10;

-- Orders by status
SELECT order_status, COUNT(*) as count, SUM(total_amount) as total_revenue
FROM orders
GROUP BY order_status;

-- Top selling products
SELECT p.product_name, COUNT(oi.order_item_id) as times_ordered, SUM(oi.quantity) as total_quantity
FROM products p
JOIN order_items oi ON p.product_id = oi.product_id
GROUP BY p.product_id, p.product_name
ORDER BY times_ordered DESC
LIMIT 10;
```

## DMS Replication Setup

After generating data, configure DMS replication:

1. **Create DMS Replication Instance** (via Terraform)
2. **Create Source Endpoint**: MySQL at 172.20.10.4:3306
3. **Create Target Endpoint**: S3 buckets
4. **Create Replication Task**: Full load + CDC
5. **Start Replication**

See `terraform/modules/dms/README.md` for detailed instructions.

## Troubleshooting

### Connection Refused

```powershell
# Check if MySQL is running
mysql --version
net start MySQL80  # Windows
sudo systemctl status mysql  # Linux
```

### Access Denied

```sql
-- Grant privileges
GRANT ALL PRIVILEGES ON ecommerce_platform.* TO 'root'@'localhost';
FLUSH PRIVILEGES;
```

### Data Generation Errors

```powershell
# Check Python version
python --version  # Should be 3.8+

# Reinstall dependencies
pip install --upgrade -r requirements.txt
```

### Slow Data Generation

- Reduce NUM_ORDERS and NUM_CUSTOMERS in the script
- Use batch inserts (already implemented)
- Disable indexes temporarily during bulk insert

## Maintenance

### Backup Database

```powershell
mysqldump -u root -p ecommerce_platform > backup.sql
```

### Restore Database

```powershell
mysql -u root -p ecommerce_platform < backup.sql
```

### Clear All Data

```sql
-- Disable foreign key checks
SET FOREIGN_KEY_CHECKS = 0;

-- Truncate all tables
TRUNCATE TABLE order_items;
TRUNCATE TABLE payments;
TRUNCATE TABLE shipments;
TRUNCATE TABLE orders;
TRUNCATE TABLE reviews;
TRUNCATE TABLE inventory;
TRUNCATE TABLE products;
TRUNCATE TABLE categories;
TRUNCATE TABLE customers;
TRUNCATE TABLE promotions;

-- Re-enable foreign key checks
SET FOREIGN_KEY_CHECKS = 1;
```

## Next Steps

1. ✅ Task 14.1 - Create main eCommerce schema
2. ✅ Task 14.2 - Create system-specific schemas
3. ✅ Task 14.3 - Generate sample data
4. ➡️ Task 14.4 - Verify DMS replication
5. ➡️ Task 15 - Verify end-to-end flow

## References

- [MySQL Documentation](https://dev.mysql.com/doc/)
- [Faker Documentation](https://faker.readthedocs.io/)
- [AWS DMS Documentation](https://docs.aws.amazon.com/dms/)
- [PCI DSS Compliance](https://www.pcisecuritystandards.org/)
