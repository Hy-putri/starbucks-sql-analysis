-- =====================================================
-- 06_export_for_powerbi.sql
-- Purpose : Export the star schema tables to CSV files
--           (fallback when Power BI cannot connect to MySQL directly)
-- Output  : 3 CSV files in the secure_file_priv folder
-- Note    : INTO OUTFILE fails if the file already exists.
--           Delete the old CSV files before running this again.
--           The first SELECT in each UNION writes the header row.
-- =====================================================

USE starbucks_analysis;

-- 1. dim_customer
SELECT 'customer_id', 'customer_age_group', 'customer_gender'
UNION ALL
SELECT customer_id, customer_age_group, customer_gender
FROM dim_customer
INTO OUTFILE 'C:/ProgramData/MySQL/MySQL Server 26.10/Uploads/dim_customer.csv'
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n';

-- 2. dim_store
SELECT 'store_id', 'store_location_type', 'region'
UNION ALL
SELECT store_id, store_location_type, region
FROM dim_store
INTO OUTFILE 'C:/ProgramData/MySQL/MySQL Server 26.10/Uploads/dim_store.csv'
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n';

-- 3. fact_orders
SELECT 'order_id', 'customer_id', 'store_id', 'order_date', 'order_time',
       'day_of_week', 'order_channel', 'drink_category', 'is_rewards_member',
       'cart_size', 'num_customizations', 'has_food_item', 'order_ahead',
       'total_spend', 'fulfillment_time_min', 'customer_satisfaction'
UNION ALL
SELECT order_id, customer_id, store_id, order_date, order_time,
       day_of_week, order_channel, drink_category, is_rewards_member,
       cart_size, num_customizations, has_food_item, order_ahead,
       total_spend, fulfillment_time_min, customer_satisfaction
FROM fact_orders
INTO OUTFILE 'C:/ProgramData/MySQL/MySQL Server 26.10/Uploads/fact_orders.csv'
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n';