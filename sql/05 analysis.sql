-- =====================================================
-- 05_analysis.sql
-- Purpose : Answer the four business questions
-- Tables  : fact_orders, dim_customer, dim_store
-- =====================================================

USE starbucks_analysis;

-- =====================================================
-- Q1. Which ordering channel has the slowest service
--     and the lowest satisfaction?
-- =====================================================

-- Q1a. Service speed and satisfaction by channel
--      AVG(condition) = share of rows where the condition is true,
--      because the condition returns 1 (true) or 0 (false)
SELECT
    order_channel,
    COUNT(*)                                       AS orders,
    ROUND(AVG(fulfillment_time_min), 2)            AS avg_fulfillment_min,
    ROUND(AVG(customer_satisfaction), 2)           AS avg_satisfaction,
    ROUND(AVG(customer_satisfaction <= 2) * 100, 1) AS low_rating_pct
FROM fact_orders
GROUP BY order_channel
ORDER BY avg_fulfillment_min DESC;

-- Q1b. Satisfaction by waiting time
--      CASE checks the conditions from top to bottom and stops at the
--      first one that is true, so each order lands in exactly one bucket.
--      The number prefix keeps the buckets in the right order.
WITH orders_bucketed AS (
    SELECT
        order_channel,
        customer_satisfaction,
        CASE
            WHEN fulfillment_time_min <= 3 THEN '1. <=3 min'
            WHEN fulfillment_time_min <= 4 THEN '2. 3-4 min'
            WHEN fulfillment_time_min <= 5 THEN '3. 4-5 min'
            WHEN fulfillment_time_min <= 6 THEN '4. 5-6 min'
            WHEN fulfillment_time_min <= 7 THEN '5. 6-7 min'
            WHEN fulfillment_time_min <= 8 THEN '6. 7-8 min'
            ELSE                                '7. >8 min'
        END AS wait_bucket
    FROM fact_orders
)
SELECT
    wait_bucket,
    COUNT(*)                                        AS orders,
    ROUND(AVG(customer_satisfaction), 2)            AS avg_satisfaction,
    ROUND(AVG(customer_satisfaction <= 2) * 100, 1) AS low_rating_pct
FROM orders_bucketed
GROUP BY wait_bucket
ORDER BY wait_bucket;

-- Q1c. Satisfaction by waiting time WITHIN each channel
--      Checks whether Q1b is driven by waiting time itself or by the
--      channel mix (long waits happen mostly at the Drive-Thru).
--      AVG(CASE WHEN ... THEN value END) averages only the matching rows;
--      the other rows become NULL and AVG ignores NULL.
WITH orders_bucketed AS (
    SELECT
        order_channel,
        customer_satisfaction,
        CASE
            WHEN fulfillment_time_min <= 3 THEN '1. <=3 min'
            WHEN fulfillment_time_min <= 4 THEN '2. 3-4 min'
            WHEN fulfillment_time_min <= 5 THEN '3. 4-5 min'
            WHEN fulfillment_time_min <= 6 THEN '4. 5-6 min'
            WHEN fulfillment_time_min <= 7 THEN '5. 6-7 min'
            WHEN fulfillment_time_min <= 8 THEN '6. 7-8 min'
            ELSE                                '7. >8 min'
        END AS wait_bucket
    FROM fact_orders
)
SELECT
    wait_bucket,
    ROUND(AVG(CASE WHEN order_channel = 'Drive-Thru'       THEN customer_satisfaction END), 2) AS drive_thru,
    ROUND(AVG(CASE WHEN order_channel = 'In-Store Cashier' THEN customer_satisfaction END), 2) AS in_store_cashier,
    ROUND(AVG(CASE WHEN order_channel = 'Kiosk'            THEN customer_satisfaction END), 2) AS kiosk,
    ROUND(AVG(CASE WHEN order_channel = 'Mobile App'       THEN customer_satisfaction END), 2) AS mobile_app
FROM orders_bucketed
GROUP BY wait_bucket
ORDER BY wait_bucket;

-- =====================================================
-- Q2. Do more complex orders take longer to fulfill?
-- =====================================================

-- Q2a. Fulfillment time by number of customizations
SELECT
    num_customizations,
    COUNT(*)                            AS orders,
    ROUND(AVG(fulfillment_time_min), 2) AS avg_fulfillment_min
FROM fact_orders
GROUP BY num_customizations
ORDER BY num_customizations;

-- Q2b. Fulfillment time by cart size
SELECT
    cart_size,
    COUNT(*)                            AS orders,
    ROUND(AVG(fulfillment_time_min), 2) AS avg_fulfillment_min
FROM fact_orders
GROUP BY cart_size
ORDER BY cart_size;

-- =====================================================
-- Q3. Which factors increase order value?
-- =====================================================

-- Q3a. Average spend with vs without each factor (all orders)
--      UNION ALL stacks the results of several SELECTs into one table.
--      Every SELECT must return the same number of columns.
SELECT
    'Customization' AS factor,
    ROUND(AVG(CASE WHEN num_customizations > 0 THEN total_spend END), 2) AS avg_spend_with,
    ROUND(AVG(CASE WHEN num_customizations = 0 THEN total_spend END), 2) AS avg_spend_without,
    ROUND(AVG(CASE WHEN num_customizations > 0 THEN total_spend END)
        - AVG(CASE WHEN num_customizations = 0 THEN total_spend END), 2) AS difference
FROM fact_orders
UNION ALL
SELECT
    'Food item',
    ROUND(AVG(CASE WHEN has_food_item = 1 THEN total_spend END), 2),
    ROUND(AVG(CASE WHEN has_food_item = 0 THEN total_spend END), 2),
    ROUND(AVG(CASE WHEN has_food_item = 1 THEN total_spend END)
        - AVG(CASE WHEN has_food_item = 0 THEN total_spend END), 2)
FROM fact_orders
UNION ALL
SELECT
    'Order ahead',
    ROUND(AVG(CASE WHEN order_ahead = 1 THEN total_spend END), 2),
    ROUND(AVG(CASE WHEN order_ahead = 0 THEN total_spend END), 2),
    ROUND(AVG(CASE WHEN order_ahead = 1 THEN total_spend END)
        - AVG(CASE WHEN order_ahead = 0 THEN total_spend END), 2)
FROM fact_orders
UNION ALL
SELECT
    'Rewards account',
    ROUND(AVG(CASE WHEN is_rewards_member = 1 THEN total_spend END), 2),
    ROUND(AVG(CASE WHEN is_rewards_member = 0 THEN total_spend END), 2),
    ROUND(AVG(CASE WHEN is_rewards_member = 1 THEN total_spend END)
        - AVG(CASE WHEN is_rewards_member = 0 THEN total_spend END), 2)
FROM fact_orders;

-- Q3b. The same comparison, split into Mobile App vs other channels
--      Mobile App orders are larger AND contain most order-ahead and
--      Rewards orders. Comparing within the same channel group shows
--      which factors still matter once the channel is held constant.
WITH orders_grouped AS (
    SELECT
        *,
        CASE WHEN order_channel = 'Mobile App' THEN 'Mobile App'
             ELSE 'Other channels'
        END AS channel_group
    FROM fact_orders
)
SELECT
    'Customization' AS factor,
    channel_group,
    ROUND(AVG(CASE WHEN num_customizations > 0 THEN total_spend END), 2) AS avg_spend_with,
    ROUND(AVG(CASE WHEN num_customizations = 0 THEN total_spend END), 2) AS avg_spend_without,
    ROUND(AVG(CASE WHEN num_customizations > 0 THEN total_spend END)
        - AVG(CASE WHEN num_customizations = 0 THEN total_spend END), 2) AS difference
FROM orders_grouped
GROUP BY channel_group
UNION ALL
SELECT
    'Food item', channel_group,
    ROUND(AVG(CASE WHEN has_food_item = 1 THEN total_spend END), 2),
    ROUND(AVG(CASE WHEN has_food_item = 0 THEN total_spend END), 2),
    ROUND(AVG(CASE WHEN has_food_item = 1 THEN total_spend END)
        - AVG(CASE WHEN has_food_item = 0 THEN total_spend END), 2)
FROM orders_grouped
GROUP BY channel_group
UNION ALL
SELECT
    'Order ahead', channel_group,
    ROUND(AVG(CASE WHEN order_ahead = 1 THEN total_spend END), 2),
    ROUND(AVG(CASE WHEN order_ahead = 0 THEN total_spend END), 2),
    ROUND(AVG(CASE WHEN order_ahead = 1 THEN total_spend END)
        - AVG(CASE WHEN order_ahead = 0 THEN total_spend END), 2)
FROM orders_grouped
GROUP BY channel_group
UNION ALL
SELECT
    'Rewards account', channel_group,
    ROUND(AVG(CASE WHEN is_rewards_member = 1 THEN total_spend END), 2),
    ROUND(AVG(CASE WHEN is_rewards_member = 0 THEN total_spend END), 2),
    ROUND(AVG(CASE WHEN is_rewards_member = 1 THEN total_spend END)
        - AVG(CASE WHEN is_rewards_member = 0 THEN total_spend END), 2)
FROM orders_grouped
GROUP BY channel_group
ORDER BY factor, channel_group;

-- Q3c. Food attach rate by channel (share of orders that include food)
SELECT
    order_channel,
    COUNT(*)                              AS orders,
    ROUND(AVG(has_food_item) * 100, 1)    AS food_attach_pct,
    ROUND(AVG(total_spend), 2)            AS avg_spend
FROM fact_orders
GROUP BY order_channel
ORDER BY food_attach_pct DESC;

-- =====================================================
-- Q4. How is revenue distributed across customers?
-- =====================================================

-- Q4a. Revenue by purchase-frequency segment
--      Step 1 (CTE customer_summary): one row per customer
--      Step 2 (CTE segmented): label each customer with a segment
--      Step 3: summarize per segment.
--      SUM(...) OVER () is a window function: it calculates the grand
--      total across all result rows without collapsing them, so each
--      segment can be divided by the total to get its share.
WITH customer_summary AS (
    SELECT
        customer_id,
        COUNT(*)         AS total_orders,
        SUM(total_spend) AS revenue
    FROM fact_orders
    GROUP BY customer_id
),
segmented AS (
    SELECT
        customer_id,
        revenue,
        CASE
            WHEN total_orders <= 3 THEN '1. 1-3 orders'
            WHEN total_orders <= 6 THEN '2. 4-6 orders'
            WHEN total_orders <= 9 THEN '3. 7-9 orders'
            ELSE                        '4. 10+ orders'
        END AS frequency_segment
    FROM customer_summary
)
SELECT
    frequency_segment,
    COUNT(*)                                                  AS customers,
    ROUND(COUNT(*) * 100 / SUM(COUNT(*)) OVER (), 2)          AS customer_pct,
    SUM(revenue)                                              AS revenue,
    ROUND(SUM(revenue) * 100 / SUM(SUM(revenue)) OVER (), 2)  AS revenue_pct,
    ROUND(AVG(revenue), 2)                                    AS avg_revenue_per_customer
FROM segmented
GROUP BY frequency_segment
ORDER BY frequency_segment;

-- Q4b. Revenue share by customer decile (top 10%, next 10%, ...)
--      NTILE(10) splits the customers, sorted by revenue from high
--      to low, into 10 groups of (almost) equal size.
WITH customer_revenue AS (
    SELECT customer_id, SUM(total_spend) AS revenue
    FROM fact_orders
    GROUP BY customer_id
),
ranked AS (
    SELECT
        customer_id,
        revenue,
        NTILE(10) OVER (ORDER BY revenue DESC) AS revenue_decile
    FROM customer_revenue
)
SELECT
    revenue_decile,
    COUNT(*)                                                 AS customers,
    SUM(revenue)                                             AS revenue,
    ROUND(SUM(revenue) * 100 / SUM(SUM(revenue)) OVER (), 2) AS revenue_pct
FROM ranked
GROUP BY revenue_decile
ORDER BY revenue_decile;

-- Q4c. Customer value by age group (JOIN with dim_customer)
WITH customer_summary AS (
    SELECT
        customer_id,
        COUNT(*)         AS total_orders,
        SUM(total_spend) AS revenue
    FROM fact_orders
    GROUP BY customer_id
)
SELECT
    c.customer_age_group,
    COUNT(*)                     AS customers,
    ROUND(AVG(cs.total_orders), 2) AS avg_orders_per_customer,
    ROUND(AVG(cs.revenue), 2)    AS avg_revenue_per_customer
FROM customer_summary cs
JOIN dim_customer c ON cs.customer_id = c.customer_id
GROUP BY c.customer_age_group
ORDER BY c.customer_age_group;

-- =====================================================
-- Appendix. Scope check: dimensions excluded from the analysis
--   Confirms that region, store location type, drink category and
--   month show near-identical values (see business_questions.md)
-- =====================================================

SELECT 'Region' AS dimension, s.region AS value,
       COUNT(*) AS orders, ROUND(AVG(f.total_spend), 2) AS avg_spend,
       ROUND(AVG(f.customer_satisfaction), 2) AS avg_satisfaction
FROM fact_orders f
JOIN dim_store s ON f.store_id = s.store_id
GROUP BY s.region
UNION ALL
SELECT 'Location type', s.store_location_type,
       COUNT(*), ROUND(AVG(f.total_spend), 2), ROUND(AVG(f.customer_satisfaction), 2)
FROM fact_orders f
JOIN dim_store s ON f.store_id = s.store_id
GROUP BY s.store_location_type
UNION ALL
SELECT 'Drink category', drink_category,
       COUNT(*), ROUND(AVG(total_spend), 2), ROUND(AVG(customer_satisfaction), 2)
FROM fact_orders
GROUP BY drink_category
ORDER BY dimension, value;

-- Monthly revenue (flat across both years)
SELECT
    DATE_FORMAT(order_date, '%Y-%m') AS order_month,
    COUNT(*)                         AS orders,
    SUM(total_spend)                 AS revenue
FROM fact_orders
GROUP BY order_month
ORDER BY order_month;