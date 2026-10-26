-- =====================================================
-- 02_data_understanding.sql
-- Purpose : Profile every column in raw_orders before cleaning
-- Table   : raw_orders (all columns stored as VARCHAR)
-- =====================================================

USE starbucks_analysis;

-- -----------------------------------------------------
-- A. Categorical columns: distinct values and counts
--    Look for: spelling variants of the same category,
--    blank values, unexpected categories
-- -----------------------------------------------------

-- A1. Order channel
SELECT order_channel, COUNT(*) AS total_orders
FROM raw_orders
GROUP BY order_channel
ORDER BY total_orders DESC;

-- A2. Store location type
SELECT store_location_type, COUNT(*) AS total_orders
FROM raw_orders
GROUP BY store_location_type
ORDER BY total_orders DESC;

-- A3. Region
SELECT region, COUNT(*) AS total_orders
FROM raw_orders
GROUP BY region
ORDER BY total_orders DESC;

-- A4. Customer age group (sorted by age, not by count)
SELECT customer_age_group, COUNT(*) AS total_orders
FROM raw_orders
GROUP BY customer_age_group
ORDER BY customer_age_group;

-- A5. Customer gender
SELECT customer_gender, COUNT(*) AS total_orders
FROM raw_orders
GROUP BY customer_gender
ORDER BY total_orders DESC;

-- A6. Rewards membership
SELECT is_rewards_member, COUNT(*) AS total_orders
FROM raw_orders
GROUP BY is_rewards_member
ORDER BY total_orders DESC;

-- A7. Drink category
SELECT drink_category, COUNT(*) AS total_orders
FROM raw_orders
GROUP BY drink_category
ORDER BY total_orders DESC;

-- A8. Has food item
SELECT has_food_item, COUNT(*) AS total_orders
FROM raw_orders
GROUP BY has_food_item
ORDER BY total_orders DESC;

-- A9. Order ahead
SELECT order_ahead, COUNT(*) AS total_orders
FROM raw_orders
GROUP BY order_ahead
ORDER BY total_orders DESC;

-- A10. Customer satisfaction (sorted by score)
SELECT customer_satisfaction, COUNT(*) AS total_orders
FROM raw_orders
GROUP BY customer_satisfaction
ORDER BY customer_satisfaction;

-- A11. Day of week
SELECT day_of_week, COUNT(*) AS total_orders
FROM raw_orders
GROUP BY day_of_week
ORDER BY total_orders DESC;

-- A12. Blank values in every column
--      (column = '') returns 1 when blank and 0 otherwise,
--      so SUM() counts the blank rows. Expected: all 0
SELECT
    SUM(TRIM(customer_id) = '')           AS blank_customer_id,
    SUM(TRIM(order_id) = '')              AS blank_order_id,
    SUM(TRIM(order_date) = '')            AS blank_order_date,
    SUM(TRIM(order_time) = '')            AS blank_order_time,
    SUM(TRIM(day_of_week) = '')           AS blank_day_of_week,
    SUM(TRIM(order_channel) = '')         AS blank_order_channel,
    SUM(TRIM(store_id) = '')              AS blank_store_id,
    SUM(TRIM(store_location_type) = '')   AS blank_store_location_type,
    SUM(TRIM(region) = '')                AS blank_region,
    SUM(TRIM(customer_age_group) = '')    AS blank_customer_age_group,
    SUM(TRIM(customer_gender) = '')       AS blank_customer_gender,
    SUM(TRIM(is_rewards_member) = '')     AS blank_is_rewards_member,
    SUM(TRIM(cart_size) = '')             AS blank_cart_size,
    SUM(TRIM(num_customizations) = '')    AS blank_num_customizations,
    SUM(TRIM(total_spend) = '')           AS blank_total_spend,
    SUM(TRIM(fulfillment_time_min) = '')  AS blank_fulfillment_time_min,
    SUM(TRIM(drink_category) = '')        AS blank_drink_category,
    SUM(TRIM(has_food_item) = '')         AS blank_has_food_item,
    SUM(TRIM(order_ahead) = '')           AS blank_order_ahead,
    SUM(TRIM(customer_satisfaction) = '') AS blank_customer_satisfaction
FROM raw_orders;

-- -----------------------------------------------------
-- B. Numeric columns: min, max, average
--    Text must be converted with CAST first, otherwise
--    MySQL compares character by character ('9.52' > '40.31')
--    Look for: zero/negative values, impossible ranges
-- -----------------------------------------------------

-- B1. Total spend (decimal)
SELECT
    MIN(CAST(total_spend AS DECIMAL(10,2))) AS min_spend,
    MAX(CAST(total_spend AS DECIMAL(10,2))) AS max_spend,
    AVG(CAST(total_spend AS DECIMAL(10,2))) AS avg_spend
FROM raw_orders;

-- B2. Cart size (whole number)
SELECT
    MIN(CAST(cart_size AS UNSIGNED)) AS min_cart_size,
    MAX(CAST(cart_size AS UNSIGNED)) AS max_cart_size,
    AVG(CAST(cart_size AS UNSIGNED)) AS avg_cart_size
FROM raw_orders;

-- B3. Number of customizations (whole number)
SELECT
    MIN(CAST(num_customizations AS UNSIGNED)) AS min_customizations,
    MAX(CAST(num_customizations AS UNSIGNED)) AS max_customizations,
    AVG(CAST(num_customizations AS UNSIGNED)) AS avg_customizations
FROM raw_orders;

-- B4. Fulfillment time in minutes (decimal)
SELECT
    MIN(CAST(fulfillment_time_min AS DECIMAL(5,1))) AS min_fulfillment,
    MAX(CAST(fulfillment_time_min AS DECIMAL(5,1))) AS max_fulfillment,
    AVG(CAST(fulfillment_time_min AS DECIMAL(5,1))) AS avg_fulfillment
FROM raw_orders;

-- B5. Customer satisfaction score (whole number, expected range 1-5)
SELECT
    MIN(CAST(customer_satisfaction AS UNSIGNED)) AS min_satisfaction,
    MAX(CAST(customer_satisfaction AS UNSIGNED)) AS max_satisfaction,
    AVG(CAST(customer_satisfaction AS UNSIGNED)) AS avg_satisfaction
FROM raw_orders;

-- -----------------------------------------------------
-- C. Consistency checks
--    Attributes that describe a store or a customer should
--    never change between orders. An empty result = consistent.
--    These results decide which attributes can move into
--    store and customer tables during data modeling.
-- -----------------------------------------------------

-- C1. Is every store always in the same region?
SELECT store_id, COUNT(DISTINCT region) AS region_count
FROM raw_orders
GROUP BY store_id
HAVING COUNT(DISTINCT region) > 1;

-- C2. Does every store always have the same location type?
SELECT store_id, COUNT(DISTINCT store_location_type) AS location_type_count
FROM raw_orders
GROUP BY store_id
HAVING COUNT(DISTINCT store_location_type) > 1;

-- C3. Does every customer always have the same age group?
--     The outer SELECT COUNT(*) counts how many customers
--     the inner query returns (a subquery must have an alias: t)
SELECT COUNT(*) AS inconsistent_customers
FROM (
    SELECT customer_id
    FROM raw_orders
    GROUP BY customer_id
    HAVING COUNT(DISTINCT customer_age_group) > 1
) AS t;

-- C4. Does every customer always have the same gender?
SELECT COUNT(*) AS inconsistent_customers
FROM (
    SELECT customer_id
    FROM raw_orders
    GROUP BY customer_id
    HAVING COUNT(DISTINCT customer_gender) > 1
) AS t;

-- C5. Does every customer always have the same rewards status?
SELECT COUNT(*) AS inconsistent_customers
FROM (
    SELECT customer_id
    FROM raw_orders
    GROUP BY customer_id
    HAVING COUNT(DISTINCT is_rewards_member) > 1
) AS t;

-- C6. If C5 is not zero: look at one example customer in detail
SELECT customer_id, order_date, is_rewards_member
FROM raw_orders
WHERE customer_id = (
    SELECT customer_id
    FROM raw_orders
    GROUP BY customer_id
    HAVING COUNT(DISTINCT is_rewards_member) > 1
    LIMIT 1
)
ORDER BY order_date;

-- C7. Share of orders flagged as Rewards, by order channel
--     Tests the assumption that is_rewards_member means
--     "a Rewards account was used on this order"
SELECT
    order_channel,
    COUNT(*)                                             AS total_orders,
    SUM(is_rewards_member = 'True')                      AS rewards_orders,
    ROUND(SUM(is_rewards_member = 'True') / COUNT(*) * 100, 1) AS rewards_pct
FROM raw_orders
GROUP BY order_channel
ORDER BY rewards_pct DESC;

-- C8. Order-ahead orders by channel
--     Logic check: ordering ahead should only be possible via the Mobile App
SELECT
    order_channel,
    order_ahead,
    COUNT(*) AS total_orders
FROM raw_orders
GROUP BY order_channel, order_ahead
ORDER BY order_channel, order_ahead;