-- =====================================================
-- 04_data_modeling.sql
-- Purpose : Split orders_clean into a star schema
--             dim_customer  (one row per customer)
--             dim_store     (one row per store)
--             fact_orders   (one row per order)
-- Input   : orders_clean (100,000 rows)
-- Note    : Safe to re-run. The fact table is dropped first
--           because it references the dimension tables.
-- =====================================================

USE starbucks_analysis;

DROP TABLE IF EXISTS fact_orders;
DROP TABLE IF EXISTS dim_customer;
DROP TABLE IF EXISTS dim_store;

-- -----------------------------------------------------
-- PART 1. Dimension tables
-- -----------------------------------------------------

-- 1.1 Customers: attributes that never change per customer
--     (verified in 02_data_understanding.sql, checks C3 and C4).
--     is_rewards_member is NOT included: it changes between
--     orders for 93% of customers, so it stays in fact_orders.
CREATE TABLE dim_customer (
    customer_id        VARCHAR(20) NOT NULL,
    customer_age_group VARCHAR(10) NOT NULL,
    customer_gender    VARCHAR(20) NOT NULL,
    PRIMARY KEY (customer_id)
);

-- DISTINCT keeps one row per unique combination.
-- If a customer had two different age groups, they would produce
-- two rows with the same customer_id and the PRIMARY KEY would
-- reject the insert. That is why the consistency checks mattered.
INSERT INTO dim_customer
SELECT DISTINCT customer_id, customer_age_group, customer_gender
FROM orders_clean;

-- 1.2 Stores: location attributes are fixed per store
--     (verified in checks C1 and C2)
CREATE TABLE dim_store (
    store_id            VARCHAR(20) NOT NULL,
    store_location_type VARCHAR(20) NOT NULL,
    region              VARCHAR(20) NOT NULL,
    PRIMARY KEY (store_id)
);

INSERT INTO dim_store
SELECT DISTINCT store_id, store_location_type, region
FROM orders_clean;

-- -----------------------------------------------------
-- PART 2. Fact table
--   Everything that describes a single order.
--   order_channel and drink_category stay here: they have only
--   4 and 6 values, so separate tables would add joins
--   without adding information.
-- -----------------------------------------------------

CREATE TABLE fact_orders (
    order_id              VARCHAR(20)      NOT NULL,
    customer_id           VARCHAR(20)      NOT NULL,
    store_id              VARCHAR(20)      NOT NULL,
    order_date            DATE             NOT NULL,
    order_time            TIME             NOT NULL,
    day_of_week           CHAR(3)          NOT NULL,
    order_channel         VARCHAR(30)      NOT NULL,
    drink_category        VARCHAR(20)      NOT NULL,
    is_rewards_member     BOOLEAN          NOT NULL,
    cart_size             TINYINT UNSIGNED NOT NULL,
    num_customizations    TINYINT UNSIGNED NOT NULL,
    has_food_item         BOOLEAN          NOT NULL,
    order_ahead           BOOLEAN          NOT NULL,
    total_spend           DECIMAL(6,2)     NOT NULL,
    fulfillment_time_min  DECIMAL(4,1)     NOT NULL,
    customer_satisfaction TINYINT UNSIGNED NOT NULL,
    PRIMARY KEY (order_id),
    FOREIGN KEY (customer_id) REFERENCES dim_customer (customer_id),
    FOREIGN KEY (store_id)    REFERENCES dim_store (store_id)
);

INSERT INTO fact_orders
SELECT
    order_id,
    customer_id,
    store_id,
    order_date,
    order_time,
    day_of_week,
    order_channel,
    drink_category,
    is_rewards_member,
    cart_size,
    num_customizations,
    has_food_item,
    order_ahead,
    total_spend,
    fulfillment_time_min,
    customer_satisfaction
FROM orders_clean;

-- -----------------------------------------------------
-- PART 3. Validation
-- -----------------------------------------------------

-- 3.1 Row counts (expected: 14988 | 500 | 100000)
SELECT
    (SELECT COUNT(*) FROM dim_customer) AS customers,
    (SELECT COUNT(*) FROM dim_store)    AS stores,
    (SELECT COUNT(*) FROM fact_orders)  AS orders;

-- 3.2 Total spend is unchanged (expected: 1486677.08)
SELECT SUM(total_spend) AS total_spend FROM fact_orders;

-- 3.3 Orphan check: orders whose customer is missing in dim_customer
--     LEFT JOIN keeps every order; if no matching customer exists,
--     the customer columns come back as NULL. Expected: 0
SELECT COUNT(*) AS orphan_customer_orders
FROM fact_orders f
LEFT JOIN dim_customer c ON f.customer_id = c.customer_id
WHERE c.customer_id IS NULL;

-- 3.4 EXERCISE: write the same orphan check for stores
--     (fact_orders -> dim_store). Expected: 0


-- 3.5 Rebuild test: orders per age group through a JOIN.
--     Must match the counts from check A4 in 02_data_understanding.sql
--     (18-24: 20274 | 25-34: 29782 | 35-44: 24543 | 45-54: 15382 | 55+: 10019)
SELECT c.customer_age_group, COUNT(*) AS total_orders
FROM fact_orders f
JOIN dim_customer c ON f.customer_id = c.customer_id
GROUP BY c.customer_age_group
ORDER BY c.customer_age_group;

-- 3.6 EXERCISE: orders per region through a JOIN with dim_store.
--     Must match check A3
--     (West 22608 | Southeast 20223 | Southwest 19663 | Midwest 19470 | Northeast 18036)