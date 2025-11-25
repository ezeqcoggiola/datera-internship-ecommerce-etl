-- =====================================================================
-- 1) Crear base de datos y usarla
-- =====================================================================
CREATE DATABASE IF NOT EXISTS db_ecommerce;
USE db_ecommerce;

-- Opcional: por las dudas
SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;

-- =====================================================================
-- 2) Tablas maestras: customers, products
-- =====================================================================

DROP TABLE IF EXISTS order_items;
DROP TABLE IF EXISTS orders;
DROP TABLE IF EXISTS products;
DROP TABLE IF EXISTS customers;

-- -----------------------
-- Tabla: customers
-- -----------------------
CREATE TABLE customers (
  customer_id      INT           NOT NULL,
  name             VARCHAR(150)  NOT NULL,
  email            VARCHAR(255)  NOT NULL,
  country          CHAR(2)       NOT NULL,
  age              TINYINT UNSIGNED NOT NULL,
  signup_date      DATE          NOT NULL,
  marketing_opt_in TINYINT(1)    NOT NULL,  -- 0 = False, 1 = True
  PRIMARY KEY (customer_id),
  KEY idx_customers_country (country)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- -----------------------
-- Tabla: products
-- -----------------------
CREATE TABLE products (
  product_id   INT           NOT NULL,
  category     VARCHAR(100)  NOT NULL,
  name         VARCHAR(255)  NOT NULL,
  price_usd    DECIMAL(10,2) NOT NULL,
  cost_usd     DECIMAL(10,2) NOT NULL,
  margin_usd   DECIMAL(10,2) NOT NULL,
  PRIMARY KEY (product_id),
  KEY idx_products_category (category)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- =====================================================================
-- 3) Tablas transaccionales: orders, order_items
-- =====================================================================

-- -----------------------
-- Tabla: orders
-- -----------------------
CREATE TABLE orders (
  order_id       INT           NOT NULL,
  customer_id    INT           NOT NULL,
  order_time     DATETIME      NOT NULL,
  payment_method VARCHAR(20)   NOT NULL,
  discount_pct   INT           NOT NULL,
  subtotal_usd   DECIMAL(10,2) NOT NULL,
  total_usd      DECIMAL(10,2) NOT NULL,
  country        CHAR(2)       NOT NULL,
  device         VARCHAR(20)   NOT NULL,
  source         VARCHAR(50)   NOT NULL,
  PRIMARY KEY (order_id),
  KEY idx_orders_customer (customer_id),
  KEY idx_orders_country (country),
  CONSTRAINT fk_orders_customer
    FOREIGN KEY (customer_id) REFERENCES customers(customer_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- -----------------------
-- Tabla: order_items
-- -----------------------
CREATE TABLE order_items (
  order_id        INT           NOT NULL,
  product_id      INT           NOT NULL,
  unit_price_usd  DECIMAL(10,2) NOT NULL,
  quantity        INT           NOT NULL,
  line_total_usd  DECIMAL(10,2) NOT NULL,
  PRIMARY KEY (order_id, product_id),
  KEY idx_oi_product (product_id),
  CONSTRAINT fk_oi_order
    FOREIGN KEY (order_id) REFERENCES orders(order_id),
  CONSTRAINT fk_oi_product
    FOREIGN KEY (product_id) REFERENCES products(product_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- =====================================================================
-- 4) Carga de datos desde CSV con LOAD DATA LOCAL INFILE
--    (Ajustar rutas de archivos según tu máquina)
-- =====================================================================

-- Importante: conectarse con --local-infile=1
--   mysql --local-infile=1 -h <endpoint> -u <user> -p

-- ---------------------------------------------------------------------
-- customers.csv
-- ---------------------------------------------------------------------
LOAD DATA LOCAL INFILE './ecommerce/rds/customers.csv'
INTO TABLE customers
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(customer_id, name, email, country, age, signup_date, @marketing_opt_in_str)
SET marketing_opt_in = (@marketing_opt_in_str = 'True');

-- ---------------------------------------------------------------------
-- products.csv
-- ---------------------------------------------------------------------
LOAD DATA LOCAL INFILE './ecommerce/rds/products.csv'
INTO TABLE products
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(product_id, category, name, price_usd, cost_usd, margin_usd);

-- ---------------------------------------------------------------------
-- orders.csv
--  order_time viene como: 2024-02-19T01:17:50 (ISO con 'T')
-- ---------------------------------------------------------------------
LOAD DATA LOCAL INFILE './ecommerce/rds/orders.csv'
INTO TABLE orders
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(order_id,
 customer_id,
 @order_time_str,
 payment_method,
 discount_pct,
 subtotal_usd,
 total_usd,
 country,
 device,
 source)
SET order_time = STR_TO_DATE(REPLACE(@order_time_str, 'T', ' '),
                             '%Y-%m-%d %H:%i:%s');

-- ---------------------------------------------------------------------
-- order_items.csv
-- ---------------------------------------------------------------------
LOAD DATA LOCAL INFILE './ecommerce/rds/order_items.csv'
INTO TABLE order_items
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(order_id, product_id, unit_price_usd, quantity, line_total_usd);

SET FOREIGN_KEY_CHECKS = 1;
