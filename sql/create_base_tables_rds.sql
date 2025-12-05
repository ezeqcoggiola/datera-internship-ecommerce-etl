-- CREATE TABLE statements for base processed tables (MySQL dialect)
-- Adjust charset/collation or engine as needed

CREATE TABLE IF NOT EXISTS customers (
  customer_id INT NOT NULL,
  name VARCHAR(255) NULL,
  email VARCHAR(255) NULL,
  country VARCHAR(100) NULL,
  age INT NULL,
  signup_date DATE NULL,
  marketing_opt_in TINYINT(1) NULL,
  year VARCHAR(10) NULL,
  month VARCHAR(10) NULL,
  day VARCHAR(10) NULL,
  PRIMARY KEY (customer_id),
  INDEX idx_customers_signup_date (signup_date)
);

CREATE TABLE IF NOT EXISTS products (
  product_id INT NOT NULL,
  category VARCHAR(255) NULL,
  name VARCHAR(255) NULL,
  price_usd DOUBLE NULL,
  cost_usd DOUBLE NULL,
  margin_usd DOUBLE NULL,
  PRIMARY KEY (product_id),
  INDEX idx_products_category (category)
);

CREATE TABLE IF NOT EXISTS orders (
  order_id INT NOT NULL,
  customer_id INT NULL,
  order_time TIMESTAMP NULL,
  payment_method VARCHAR(100) NULL,
  discount_pct INT NULL,
  subtotal_usd DOUBLE NULL,
  total_usd DOUBLE NULL,
  country VARCHAR(100) NULL,
  device VARCHAR(100) NULL,
  source VARCHAR(100) NULL,
  year VARCHAR(10) NULL,
  month VARCHAR(10) NULL,
  day VARCHAR(10) NULL,
  PRIMARY KEY (order_id),
  INDEX idx_orders_customer (customer_id),
  INDEX idx_orders_order_time (order_time)
);

CREATE TABLE IF NOT EXISTS order_items (
  order_id INT NOT NULL,
  product_id INT NOT NULL,
  unit_price_usd DOUBLE NULL,
  quantity INT NULL,
  line_total_usd DOUBLE NULL,
  PRIMARY KEY (order_id, product_id),
  INDEX idx_order_items_product (product_id)
);

CREATE TABLE IF NOT EXISTS sessions (
  session_id INT NOT NULL,
  customer_id INT NULL,
  start_time TIMESTAMP NULL,
  device VARCHAR(100) NULL,
  source VARCHAR(100) NULL,
  country VARCHAR(100) NULL,
  year VARCHAR(10) NULL,
  month VARCHAR(10) NULL,
  day VARCHAR(10) NULL,
  PRIMARY KEY (session_id),
  INDEX idx_sessions_customer (customer_id)
);

CREATE TABLE IF NOT EXISTS events (
  event_id INT NOT NULL,
  session_id INT NULL,
  `timestamp` TIMESTAMP NULL,
  event_type VARCHAR(100) NULL,
  product_id INT NULL,
  qty INT NULL,
  cart_size INT NULL,
  payment VARCHAR(100) NULL,
  discount_pct INT NULL,
  amount_usd DOUBLE NULL,
  year VARCHAR(10) NULL,
  month VARCHAR(10) NULL,
  day VARCHAR(10) NULL,
  PRIMARY KEY (event_id),
  INDEX idx_events_session (session_id),
  INDEX idx_events_product (product_id)
);

CREATE TABLE IF NOT EXISTS reviews (
  review_id INT NOT NULL,
  order_id INT NULL,
  product_id INT NULL,
  rating INT NULL,
  review_text TEXT NULL,
  review_time TIMESTAMP NULL,
  year VARCHAR(10) NULL,
  month VARCHAR(10) NULL,
  day VARCHAR(10) NULL,
  PRIMARY KEY (review_id),
  INDEX idx_reviews_order (order_id),
  INDEX idx_reviews_product (product_id)
);

-- Optional: add foreign keys if you want referential integrity (may affect load performance)
-- ALTER TABLE orders ADD CONSTRAINT fk_orders_customer FOREIGN KEY (customer_id) REFERENCES customers(customer_id);
-- ALTER TABLE order_items ADD CONSTRAINT fk_orderitems_order FOREIGN KEY (order_id) REFERENCES orders(order_id);
-- ALTER TABLE order_items ADD CONSTRAINT fk_orderitems_product FOREIGN KEY (product_id) REFERENCES products(product_id);
