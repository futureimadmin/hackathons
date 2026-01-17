"""
Sample Data Generator for eCommerce Platform
Generates realistic sample data for all tables
Requirements: 14.4, 14.5, 14.6, 14.7, 14.8, 14.9
"""

import uuid
import random
import mysql.connector
from datetime import datetime, timedelta
from faker import Faker
import json
import os

# Initialize Faker
fake = Faker()

# Database connection configuration from environment variables
DB_CONFIG = {
    'host': os.environ.get('MYSQL_HOST', 'localhost'),
    'port': int(os.environ.get('MYSQL_PORT', '3306')),
    'user': os.environ.get('MYSQL_USER', 'root'),
    'password': os.environ.get('MYSQL_PASSWORD', 'Srikar@123'),
    'database': os.environ.get('MYSQL_DATABASE', 'ecommerce')
}

# Data generation parameters
# Scale based on target size (default 500MB)
TARGET_SIZE_MB = int(os.environ.get('TARGET_SIZE_MB', '500'))

# Adjust data volumes based on target size
# Base values are for ~500MB
SCALE_FACTOR = TARGET_SIZE_MB / 500.0

NUM_CUSTOMERS = int(10000 * SCALE_FACTOR)
NUM_CATEGORIES = 50  # Keep categories constant
NUM_PRODUCTS = int(5000 * SCALE_FACTOR)
NUM_ORDERS = int(50000 * SCALE_FACTOR)
NUM_ORDER_ITEMS_PER_ORDER = (1, 5)  # Min, Max
NUM_REVIEWS_PER_PRODUCT = (0, 10)
NUM_PROMOTIONS = int(100 * SCALE_FACTOR)

# Product categories
CATEGORY_NAMES = [
    'Electronics', 'Computers', 'Smartphones', 'Tablets', 'Cameras',
    'Home & Kitchen', 'Furniture', 'Appliances', 'Bedding', 'Decor',
    'Clothing', 'Men', 'Women', 'Kids', 'Shoes',
    'Sports & Outdoors', 'Fitness', 'Camping', 'Cycling', 'Water Sports',
    'Books', 'Fiction', 'Non-Fiction', 'Textbooks', 'Children',
    'Toys & Games', 'Action Figures', 'Board Games', 'Puzzles', 'Educational',
    'Beauty & Personal Care', 'Skincare', 'Makeup', 'Hair Care', 'Fragrances',
    'Automotive', 'Parts', 'Accessories', 'Tools', 'Car Care',
    'Pet Supplies', 'Dog', 'Cat', 'Fish', 'Bird',
    'Garden & Outdoor', 'Plants', 'Tools', 'Furniture', 'Grills'
]

BRANDS = [
    'TechPro', 'HomeEssentials', 'StyleMax', 'SportFit', 'BookWorld',
    'ToyLand', 'BeautyPlus', 'AutoParts', 'PetCare', 'GardenPro'
]

ORDER_STATUSES = ['pending', 'processing', 'shipped', 'delivered', 'cancelled']
PAYMENT_METHODS = ['credit_card', 'debit_card', 'paypal', 'apple_pay', 'google_pay']
PAYMENT_STATUSES = ['pending', 'completed', 'failed', 'refunded']
SHIPMENT_STATUSES = ['pending', 'in_transit', 'delivered', 'returned']
CARRIERS = ['FedEx', 'UPS', 'USPS', 'DHL']

def generate_uuid():
    """Generate UUID string"""
    return str(uuid.uuid4())

def connect_db():
    """Connect to MySQL database"""
    return mysql.connector.connect(**DB_CONFIG)

def generate_customers(conn, num_customers):
    """Generate customer records"""
    print(f"Generating {num_customers} customers...")
    cursor = conn.cursor()
    
    customers = []
    for i in range(num_customers):
        customer_id = generate_uuid()
        email = fake.email()
        first_name = fake.first_name()
        last_name = fake.last_name()
        phone = fake.phone_number()[:20]
        address_line1 = fake.street_address()
        city = fake.city()
        state = fake.state_abbr()
        postal_code = fake.postcode()
        country = 'US'
        created_at = fake.date_time_between(start_date='-2y', end_date='now')
        customer_segment = random.choice(['High Value', 'Medium Value', 'Low Value', 'New', 'At Risk'])
        lifetime_value = round(random.uniform(0, 10000), 2)
        
        customers.append((
            customer_id, email, first_name, last_name, phone,
            address_line1, None, city, state, postal_code, country,
            created_at, created_at, True, customer_segment, lifetime_value
        ))
        
        if (i + 1) % 1000 == 0:
            print(f"  Generated {i + 1} customers...")
    
    # Bulk insert
    query = """
        INSERT IGNORE INTO customers (
            customer_id, email, first_name, last_name, phone,
            address_line1, address_line2, city, state, postal_code, country,
            created_at, updated_at, is_active, customer_segment, lifetime_value
        ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
    """
    cursor.executemany(query, customers)
    conn.commit()
    print(f"✓ Inserted {num_customers} customers")
    
    return [c[0] for c in customers]  # Return customer IDs

def generate_categories(conn):
    """Generate category records"""
    print(f"Generating {len(CATEGORY_NAMES)} categories...")
    cursor = conn.cursor()
    
    categories = []
    category_ids = []
    
    for name in CATEGORY_NAMES:
        category_id = generate_uuid()
        category_ids.append(category_id)
        created_at = fake.date_time_between(start_date='-3y', end_date='-2y')
        
        categories.append((
            category_id, name, None, f"Category for {name}",
            created_at, created_at, True
        ))
    
    query = """
        INSERT IGNORE INTO categories (
            category_id, category_name, parent_category_id, description,
            created_at, updated_at, is_active
        ) VALUES (%s, %s, %s, %s, %s, %s, %s)
    """
    cursor.executemany(query, categories)
    conn.commit()
    print(f"✓ Inserted {len(CATEGORY_NAMES)} categories")
    
    return category_ids

def generate_products(conn, category_ids, num_products):
    """Generate product records"""
    print(f"Generating {num_products} products...")
    cursor = conn.cursor()
    
    products = []
    product_ids = []
    
    for i in range(num_products):
        product_id = generate_uuid()
        product_ids.append(product_id)
        product_name = fake.catch_phrase()
        category_id = random.choice(category_ids)
        description = fake.text(max_nb_chars=200)
        sku = f"SKU-{fake.bothify(text='????-########')}"
        price = round(random.uniform(9.99, 999.99), 2)
        cost = round(price * random.uniform(0.4, 0.7), 2)
        weight = round(random.uniform(0.1, 50.0), 2)
        brand = random.choice(BRANDS)
        created_at = fake.date_time_between(start_date='-2y', end_date='-1y')
        
        products.append((
            product_id, product_name, category_id, description, sku,
            price, cost, weight, None, brand, None,
            created_at, created_at, True
        ))
        
        if (i + 1) % 1000 == 0:
            print(f"  Generated {i + 1} products...")
    
    query = """
        INSERT IGNORE INTO products (
            product_id, product_name, category_id, description, sku,
            price, cost, weight, dimensions, brand, manufacturer,
            created_at, updated_at, is_active
        ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
    """
    cursor.executemany(query, products)
    conn.commit()
    print(f"✓ Inserted {num_products} products")
    
    return product_ids

def generate_inventory(conn, product_ids):
    """Generate inventory records"""
    print(f"Generating inventory for {len(product_ids)} products...")
    cursor = conn.cursor()
    
    warehouses = ['Warehouse-East', 'Warehouse-West', 'Warehouse-Central']
    inventory = []
    
    for product_id in product_ids:
        warehouse = random.choice(warehouses)
        inventory_id = generate_uuid()
        quantity_available = random.randint(0, 1000)
        quantity_reserved = random.randint(0, min(50, quantity_available))
        reorder_point = random.randint(10, 50)
        reorder_quantity = random.randint(50, 200)
        last_restocked = fake.date_time_between(start_date='-6m', end_date='now')
        created_at = fake.date_time_between(start_date='-1y', end_date='-6m')
        
        inventory.append((
            inventory_id, product_id, warehouse, quantity_available,
            quantity_reserved, reorder_point, reorder_quantity,
            last_restocked, created_at, created_at
        ))
    
    query = """
        INSERT IGNORE INTO inventory (
            inventory_id, product_id, warehouse_location, quantity_available,
            quantity_reserved, reorder_point, reorder_quantity,
            last_restocked_at, created_at, updated_at
        ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
    """
    cursor.executemany(query, inventory)
    conn.commit()
    print(f"✓ Inserted {len(product_ids)} inventory records")

def generate_orders_and_items(conn, customer_ids, product_ids, num_orders):
    """Generate orders and order items"""
    print(f"Generating {num_orders} orders with items...")
    cursor = conn.cursor()
    
    orders = []
    order_items = []
    payments = []
    shipments = []
    order_ids = []
    
    for i in range(num_orders):
        order_id = generate_uuid()
        order_ids.append(order_id)
        customer_id = random.choice(customer_ids)
        order_date = fake.date_time_between(start_date='-1y', end_date='now')
        order_status = random.choice(ORDER_STATUSES)
        
        # Generate order items
        num_items = random.randint(*NUM_ORDER_ITEMS_PER_ORDER)
        order_total = 0
        
        for _ in range(num_items):
            order_item_id = generate_uuid()
            product_id = random.choice(product_ids)
            quantity = random.randint(1, 5)
            unit_price = round(random.uniform(9.99, 999.99), 2)
            discount = round(random.uniform(0, unit_price * 0.2), 2)
            tax = round((unit_price - discount) * quantity * 0.08, 2)
            total = round((unit_price - discount) * quantity + tax, 2)
            order_total += total
            
            order_items.append((
                order_item_id, order_id, product_id, quantity,
                unit_price, discount, tax, total,
                order_date, order_date
            ))
        
        # Order details
        tax_amount = round(order_total * 0.08, 2)
        shipping_amount = round(random.uniform(0, 25), 2)
        discount_amount = round(random.uniform(0, order_total * 0.1), 2)
        total_amount = round(order_total + shipping_amount - discount_amount, 2)
        
        payment_method = random.choice(PAYMENT_METHODS)
        
        orders.append((
            order_id, customer_id, order_date, order_status,
            total_amount, tax_amount, shipping_amount, discount_amount,
            payment_method,
            fake.street_address(), None, fake.city(), fake.state_abbr(),
            fake.postcode(), 'US',
            order_date, order_date
        ))
        
        # Generate payment
        payment_id = generate_uuid()
        payment_status = 'completed' if order_status in ['shipped', 'delivered'] else random.choice(PAYMENT_STATUSES)
        card_last_four = fake.credit_card_number()[-4:]
        card_type = random.choice(['Visa', 'Mastercard', 'Amex', 'Discover'])
        
        payments.append((
            payment_id, order_id, payment_method, payment_status,
            total_amount, fake.uuid4(), card_last_four, card_type,
            order_date, order_date, order_date
        ))
        
        # Generate shipment if order is shipped or delivered
        if order_status in ['shipped', 'delivered']:
            shipment_id = generate_uuid()
            carrier = random.choice(CARRIERS)
            tracking_number = fake.bothify(text='??########??')
            shipment_status = 'delivered' if order_status == 'delivered' else 'in_transit'
            shipped_date = order_date + timedelta(days=random.randint(1, 3))
            estimated_delivery = shipped_date + timedelta(days=random.randint(3, 7))
            actual_delivery = estimated_delivery if order_status == 'delivered' else None
            
            shipments.append((
                shipment_id, order_id, carrier, tracking_number,
                shipment_status, shipped_date, estimated_delivery,
                actual_delivery, shipping_amount,
                order_date, order_date
            ))
        
        if (i + 1) % 5000 == 0:
            print(f"  Generated {i + 1} orders...")
    
    # Bulk insert orders
    order_query = """
        INSERT IGNORE INTO orders (
            order_id, customer_id, order_date, order_status,
            total_amount, tax_amount, shipping_amount, discount_amount,
            payment_method,
            shipping_address_line1, shipping_address_line2, shipping_city,
            shipping_state, shipping_postal_code, shipping_country,
            created_at, updated_at
        ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
    """
    cursor.executemany(order_query, orders)
    conn.commit()
    print(f"✓ Inserted {num_orders} orders")
    
    # Bulk insert order items
    item_query = """
        INSERT IGNORE INTO order_items (
            order_item_id, order_id, product_id, quantity,
            unit_price, discount_amount, tax_amount, total_amount,
            created_at, updated_at
        ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
    """
    cursor.executemany(item_query, order_items)
    conn.commit()
    print(f"✓ Inserted {len(order_items)} order items")
    
    # Bulk insert payments
    payment_query = """
        INSERT IGNORE INTO payments (
            payment_id, order_id, payment_method, payment_status,
            amount, transaction_id, card_last_four, card_type,
            payment_date, created_at, updated_at
        ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
    """
    cursor.executemany(payment_query, payments)
    conn.commit()
    print(f"✓ Inserted {len(payments)} payments")
    
    # Bulk insert shipments
    if shipments:
        shipment_query = """
            INSERT IGNORE INTO shipments (
                shipment_id, order_id, carrier, tracking_number,
                shipment_status, shipped_date, estimated_delivery_date,
                actual_delivery_date, shipping_cost,
                created_at, updated_at
            ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
        """
        cursor.executemany(shipment_query, shipments)
        conn.commit()
        print(f"✓ Inserted {len(shipments)} shipments")
    
    return order_ids

def generate_reviews(conn, product_ids, customer_ids):
    """Generate product reviews"""
    print("Generating product reviews...")
    cursor = conn.cursor()
    
    reviews = []
    for product_id in product_ids:
        num_reviews = random.randint(*NUM_REVIEWS_PER_PRODUCT)
        for _ in range(num_reviews):
            review_id = generate_uuid()
            customer_id = random.choice(customer_ids)
            rating = random.randint(1, 5)
            review_title = fake.sentence(nb_words=6)
            review_text = fake.text(max_nb_chars=300)
            is_verified = random.choice([True, False])
            helpful_count = random.randint(0, 50)
            created_at = fake.date_time_between(start_date='-1y', end_date='now')
            
            reviews.append((
                review_id, product_id, customer_id, rating,
                review_title, review_text, is_verified, helpful_count,
                created_at, created_at
            ))
    
    query = """
        INSERT IGNORE INTO reviews (
            review_id, product_id, customer_id, rating,
            review_title, review_text, is_verified_purchase, helpful_count,
            created_at, updated_at
        ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
    """
    cursor.executemany(query, reviews)
    conn.commit()
    print(f"✓ Inserted {len(reviews)} reviews")

def generate_promotions(conn, num_promotions):
    """Generate promotion records"""
    print(f"Generating {num_promotions} promotions...")
    cursor = conn.cursor()
    
    promotions = []
    for i in range(num_promotions):
        promotion_id = generate_uuid()
        promotion_code = fake.bothify(text='PROMO-????-####').upper()
        promotion_name = fake.catch_phrase()
        description = fake.text(max_nb_chars=150)
        discount_type = random.choice(['percentage', 'fixed'])
        discount_value = round(random.uniform(5, 50), 2) if discount_type == 'percentage' else round(random.uniform(5, 100), 2)
        min_purchase = round(random.uniform(0, 100), 2)
        max_discount = round(random.uniform(50, 200), 2) if discount_type == 'percentage' else None
        start_date = fake.date_time_between(start_date='-6m', end_date='now')
        end_date = start_date + timedelta(days=random.randint(7, 90))
        usage_limit = random.randint(100, 10000)
        usage_count = random.randint(0, usage_limit // 2)
        is_active = random.choice([True, False])
        created_at = start_date - timedelta(days=random.randint(1, 30))
        
        promotions.append((
            promotion_id, promotion_code, promotion_name, description,
            discount_type, discount_value, min_purchase, max_discount,
            start_date, end_date, usage_limit, usage_count, is_active,
            created_at, created_at
        ))
    
    query = """
        INSERT IGNORE INTO promotions (
            promotion_id, promotion_code, promotion_name, description,
            discount_type, discount_value, min_purchase_amount, max_discount_amount,
            start_date, end_date, usage_limit, usage_count, is_active,
            created_at, updated_at
        ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
    """
    cursor.executemany(query, promotions)
    conn.commit()
    print(f"✓ Inserted {num_promotions} promotions")

def main():
    """Main execution function"""
    print("=" * 60)
    print("eCommerce Platform Sample Data Generator")
    print("=" * 60)
    print()
    print(f"Database Configuration:")
    print(f"  Host:     {DB_CONFIG['host']}")
    print(f"  Port:     {DB_CONFIG['port']}")
    print(f"  User:     {DB_CONFIG['user']}")
    print(f"  Database: {DB_CONFIG['database']}")
    print(f"  Target Size: {TARGET_SIZE_MB}MB")
    print()
    
    try:
        # Connect to database
        print("Connecting to database...")
        conn = connect_db()
        print("✓ Connected to database")
        print()
        
        # Generate data
        customer_ids = generate_customers(conn, NUM_CUSTOMERS)
        print()
        
        category_ids = generate_categories(conn)
        print()
        
        product_ids = generate_products(conn, category_ids, NUM_PRODUCTS)
        print()
        
        generate_inventory(conn, product_ids)
        print()
        
        order_ids = generate_orders_and_items(conn, customer_ids, product_ids, NUM_ORDERS)
        print()
        
        generate_reviews(conn, product_ids, customer_ids)
        print()
        
        generate_promotions(conn, NUM_PROMOTIONS)
        print()
        
        # Summary
        print("=" * 60)
        print("Data Generation Complete!")
        print("=" * 60)
        print(f"Customers:    {NUM_CUSTOMERS:,}")
        print(f"Categories:   {len(CATEGORY_NAMES):,}")
        print(f"Products:     {NUM_PRODUCTS:,}")
        print(f"Orders:       {NUM_ORDERS:,}")
        print(f"Order Items:  ~{NUM_ORDERS * 2.5:,.0f} (avg 2.5 per order)")
        print(f"Promotions:   {NUM_PROMOTIONS:,}")
        print("=" * 60)
        
        conn.close()
        
    except Exception as e:
        print(f"✗ Error: {e}")
        raise

if __name__ == "__main__":
    main()
