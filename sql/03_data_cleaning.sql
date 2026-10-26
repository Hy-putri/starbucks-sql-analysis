-- =====================================================
-- 03_data_cleaning.sql
-- Purpose : Validate raw values, then build orders_clean
--           with correct data types
-- Input   : raw_orders  (all VARCHAR, 100,000 rows)
-- Output  : orders_clean (typed, 100,000 rows)
-- Note    : Safe to re-run (DROP TABLE IF EXISTS before CREATE)
-- =====================================================

USE starbucks_analysis;

-- -----------------------------------------------------
-- PART 1. Pre-conversion validation
--   Make sure every value can be converted safely.
--   Expected result for every check: 0
-- -----------------------------------------------------

-- 1.1 Dates that are not valid YYYY-MM-DD dates
SELECT COUNT(*) AS invalid_dates
FROM raw_orders
WHERE STR_TO_DATE(order_date, '%Y-%m-%d') IS NULL;

-- 1.2 Times that are not in HH:MM format
SELECT COUNT(*) AS invalid_times
FROM raw_orders
WHERE order_time NOT REGEXP '^[0-2][0-9]:[0-5][0-9]$';

-- 1.3 day_of_week that does not match the actual date
--     DATE_FORMAT(..., '%a') returns the short day name (Mon, Tue, ...)
SELECT COUNT(*) AS day_mismatch
FROM raw_orders
WHERE DATE_FORMAT(STR_TO_DATE(order_date, '%Y-%m-%d'), '%a') <> day_of_week;

-- 1.4 Numeric columns containing non-numeric text
--     '^[0-9]+$'               = whole number only
--     '^[0-9]+(\\.[0-9]+)?$'   = number with optional decimals
SELECT
    SUM(cart_size             NOT REGEXP '^[0-9]+$')              AS bad_cart_size,
    SUM(num_customizations    NOT REGEXP '^[0-9]+$')              AS bad_customizations,
    SUM(customer_satisfaction NOT REGEXP '^[0-9]+$')              AS bad_satisfaction,
    SUM(total_spend           NOT REGEXP '^[0-9]+(\\.[0-9]+)?$')  AS bad_total_spend,
    SUM(fulfillment_time_min  NOT REGEXP '^[0-9]+(\\.[0-9]+)?$')  AS bad_fulfillment
FROM raw_orders;

-- 1.5 Boolean columns containing anything other than True/False
SELECT
    SUM(is_rewards_member NOT IN ('True', 'False')) AS bad_rewards,
    SUM(has_food_item     NOT IN ('True', 'False')) AS bad_food,
    SUM(order_ahead       NOT IN ('True', 'False')) AS bad_order_ahead
FROM raw_orders;

-- -----------------------------------------------------
-- PART 2. Create the clean table with proper data types
-- -----------------------------------------------------

DROP TABLE IF EXISTS orders_clean;

CREATE TABLE orders_clean (
    order_id              VARCHAR(20)      NOT NULL,
    customer_id           VARCHAR(20)      NOT NULL,
    order_date            DATE             NOT NULL,
    order_time            TIME             NOT NULL,
    day_of_week           CHAR(3)          NOT NULL,
    order_channel         VARCHAR(30)      NOT NULL,
    store_id              VARCHAR(20)      NOT NULL,
    store_location_type   VARCHAR(20)      NOT NULL,
    region                VARCHAR(20)      NOT NULL,
    customer_age_group    VARCHAR(10)      NOT NULL,
    customer_gender       VARCHAR(20)      NOT NULL,
    is_rewards_member     BOOLEAN          NOT NULL,
    cart_size             TINYINT UNSIGNED NOT NULL,
    num_customizations    TINYINT UNSIGNED NOT NULL,
    total_spend           DECIMAL(6,2)     NOT NULL,
    fulfillment_time_min  DECIMAL(4,1)     NOT NULL,
    drink_category        VARCHAR(20)      NOT NULL,
    has_food_item         BOOLEAN          NOT NULL,
    order_ahead           BOOLEAN          NOT NULL,
    customer_satisfaction TINYINT UNSIGNED NOT NULL,
    PRIMARY KEY (order_id),
    CHECK (customer_satisfaction BETWEEN 1 AND 5),
    CHECK (total_spend > 0),
    CHECK (fulfillment_time_min > 0)
);

-- -----------------------------------------------------
-- PART 3. Convert and copy the data
--   TRIM()        removes accidental spaces
--   STR_TO_DATE   text -> DATE
--   CAST          text -> TIME / number
--   = 'True'      text -> 1 (true) or 0 (false)
-- -----------------------------------------------------

INSERT INTO orders_clean
SELECT
    TRIM(order_id),
    TRIM(customer_id),
    STR_TO_DATE(order_date, '%Y-%m-%d'),
    CAST(order_time AS TIME),
    TRIM(day_of_week),
    TRIM(order_channel),
    TRIM(store_id),
    TRIM(store_location_type),
    TRIM(region),
    TRIM(customer_age_group),
    TRIM(customer_gender),
    is_rewards_member = 'True',
    CAST(cart_size AS UNSIGNED),
    CAST(num_customizations AS UNSIGNED),
    CAST(total_spend AS DECIMAL(6,2)),
    CAST(fulfillment_time_min AS DECIMAL(4,1)),
    TRIM(drink_category),
    has_food_item = 'True',
    order_ahead = 'True',
    CAST(customer_satisfaction AS UNSIGNED)
FROM raw_orders;

-- -----------------------------------------------------
-- PART 4. Post-conversion validation
--   Compare raw vs clean: nothing should be lost or changed
-- -----------------------------------------------------

-- 4.1 Row count (expected: 100000)
SELECT COUNT(*) AS clean_rows FROM orders_clean;

-- 4.2 Totals must match the raw table exactly
--     Expected: spend 1486677.08 | fulfillment 454608.0 |
--               cart 374151 | satisfaction 368753
SELECT
    (SELECT SUM(CAST(total_spend AS DECIMAL(10,2)))        FROM raw_orders)   AS raw_spend,
    (SELECT SUM(total_spend)                               FROM orders_clean) AS clean_spend,
    (SELECT SUM(CAST(fulfillment_time_min AS DECIMAL(10,1))) FROM raw_orders) AS raw_fulfillment,
    (SELECT SUM(fulfillment_time_min)                      FROM orders_clean) AS clean_fulfillment,
    (SELECT SUM(cart_size)                                 FROM orders_clean) AS clean_cart,
    (SELECT SUM(customer_satisfaction)                     FROM orders_clean) AS clean_satisfaction;

-- 4.3 Boolean conversions (expected: 47717 | 31581 | 29793)
SELECT
    SUM(is_rewards_member) AS rewards_orders,
    SUM(has_food_item)     AS food_orders,
    SUM(order_ahead)       AS order_ahead_orders
FROM orders_clean;

-- 4.4 Date range (expected: 2024-01-01 to 2025-12-30)
SELECT MIN(order_date) AS first_date, MAX(order_date) AS last_date
FROM orders_clean;

-- 4.5 Check the final column types
DESCRIBE orders_clean;