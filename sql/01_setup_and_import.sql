-- =====================================================
-- 01_setup_and_import.sql
-- Purpose : Create the database and raw table, then import the CSV
-- Dataset : Starbucks Customer Ordering Patterns (Kaggle, synthetic data)
-- Note    : Safe to re-run (IF NOT EXISTS + TRUNCATE before LOAD)
-- =====================================================

-- 1. Create and select the database
CREATE DATABASE IF NOT EXISTS starbucks_analysis;
USE starbucks_analysis;

-- 2. Create the raw (staging) table.
--    All columns are VARCHAR so every row loads as-is;
--    data types are fixed later in the cleaning step.
CREATE TABLE IF NOT EXISTS raw_orders (
    customer_id           VARCHAR(20),
    order_id              VARCHAR(20),
    order_date            VARCHAR(20),
    order_time            VARCHAR(10),
    day_of_week           VARCHAR(10),
    order_channel         VARCHAR(30),
    store_id              VARCHAR(20),
    store_location_type   VARCHAR(30),
    region                VARCHAR(30),
    customer_age_group    VARCHAR(20),
    customer_gender       VARCHAR(30),
    is_rewards_member     VARCHAR(10),
    cart_size             VARCHAR(10),
    num_customizations    VARCHAR(10),
    total_spend           VARCHAR(20),
    fulfillment_time_min  VARCHAR(20),
    drink_category        VARCHAR(30),
    has_food_item         VARCHAR(10),
    order_ahead           VARCHAR(10),
    customer_satisfaction VARCHAR(10)
);

-- 3. Check the folder MySQL is allowed to read files from
SHOW VARIABLES LIKE 'secure_file_priv';

-- 4. Import the CSV (empty the table first to avoid duplicate loads)
TRUNCATE TABLE raw_orders;

LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 26.10/Uploads/starbucks_orders.csv'
INTO TABLE raw_orders
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES;

-- 5. Validate the import
--    Expected: 100000 rows = 100000 unique orders, 14988 customers,
--    500 stores, 2024-01-01 to 2025-12-30
SELECT
    COUNT(*)                    AS total_rows,
    COUNT(DISTINCT order_id)    AS unique_orders,
    COUNT(DISTINCT customer_id) AS unique_customers,
    COUNT(DISTINCT store_id)    AS unique_stores,
    MIN(order_date)             AS first_date,
    MAX(order_date)             AS last_date
FROM raw_orders;

-- 6. Check for hidden carriage-return characters in the last column
--    Expected: length = 1 (scores are a single digit, 1-5)
SELECT customer_satisfaction, LENGTH(customer_satisfaction) AS value_length
FROM raw_orders
LIMIT 5;    