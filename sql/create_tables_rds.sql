-- ============================
-- 1) fact_orders_enriched
-- ============================
CREATE TABLE fact_orders_enriched (
    order_id          BIGINT        NOT NULL,
    customer_id       BIGINT        NOT NULL,
    order_time        DATETIME      NULL,
    total_usd         DOUBLE        NULL,
    discount_pct      BIGINT        NULL,
    order_country     VARCHAR(4)    NULL,
    device            VARCHAR(50)   NULL,
    source            VARCHAR(50)   NULL,
    age               BIGINT        NULL,
    customer_country  VARCHAR(4)    NULL,
    marketing_opt_in  TINYINT(1)    NULL,
    year              VARCHAR(10)   NULL,
    month             VARCHAR(10)   NULL,
    PRIMARY KEY (order_id)
);

-- ============================
-- 2) fact_order_items_enriched
-- ============================
CREATE TABLE fact_order_items_enriched (
    order_id        BIGINT       NOT NULL,
    product_id      BIGINT       NOT NULL,
    quantity        BIGINT       NULL,
    unit_price_usd  DOUBLE       NULL,
    line_total_usd  DOUBLE       NULL,
    category        VARCHAR(100) NULL,
    price_usd       DOUBLE       NULL,
    cost_usd        DOUBLE       NULL,
    profit_per_unit DOUBLE       NULL,
    total_profit    DOUBLE       NULL,
    PRIMARY KEY (order_id, product_id)
);

-- ============================
-- 3) agg_daily_sales
-- ============================
CREATE TABLE agg_daily_sales (
    day            INT          NOT NULL,
    daily_revenue  DOUBLE       NULL,
    num_orders     BIGINT       NULL,
    year           VARCHAR(10)  NOT NULL,
    month          VARCHAR(10)  NOT NULL,
    PRIMARY KEY (year, month, day)
);

-- ============================
-- 4) agg_top_products
-- ============================
CREATE TABLE agg_top_products (
    product_id    BIGINT        NOT NULL,
    category      VARCHAR(100)  NOT NULL,
    total_revenue DOUBLE        NULL,
    total_profit  DOUBLE        NULL,
    PRIMARY KEY (product_id, category)
);

-- ============================
-- 5) agg_funnel
-- ============================
CREATE TABLE agg_funnel (
    event_type  VARCHAR(50)  NOT NULL,
    num_events  BIGINT       NULL,
    PRIMARY KEY (event_type)
);
