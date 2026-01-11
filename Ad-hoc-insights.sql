
===============================================================================
Project Name : Consumer Goods Ad-hoc Insights
Database     : gdb023
Domain       : Consumer Goods | Business Analytics
Tool         : SQL (MySQL Compatible)

Description:
This SQL file contains solutions to 10 ad-hoc business questions designed to
extract meaningful insights for executive-level decision-making.
===============================================================================
*/

-- =============================================================================
-- Database Selection
-- =============================================================================
SHOW DATABASES;
USE gdb023;

-- =============================================================================
-- 1. Markets where "Atliq Exclusive" operates in APAC region
-- =============================================================================
SELECT DISTINCT 
    market
FROM dim_customer
WHERE customer = 'Atliq Exclusive'
  AND region = 'APAC';


-- =============================================================================
-- 2. Percentage increase in unique products (2021 vs 2020)
-- =============================================================================
WITH product_count AS (
    SELECT 
        fiscal_year,
        COUNT(DISTINCT product_code) AS unique_product_count
    FROM fact_gross_price
    GROUP BY fiscal_year
)
SELECT 
    p2020.unique_product_count AS unique_products_2020,
    p2021.unique_product_count AS unique_products_2021,
    ROUND(
        (p2021.unique_product_count - p2020.unique_product_count) 
        / p2020.unique_product_count * 100, 
        2
    ) AS percentage_chg
FROM product_count p2020
JOIN product_count p2021
  ON p2020.fiscal_year = 2020
 AND p2021.fiscal_year = 2021;


-- =============================================================================
-- 3. Unique product count per segment (descending order)
-- =============================================================================
SELECT 
    segment,
    COUNT(DISTINCT product_code) AS product_count
FROM dim_product
GROUP BY segment
ORDER BY product_count DESC;


-- =============================================================================
-- 4. Segment-wise increase in unique products (2021 vs 2020)
-- =============================================================================
WITH segment_products AS (
    SELECT 
        p.segment,
        s.fiscal_year,
        COUNT(DISTINCT s.product_code) AS product_count
    FROM fact_sales_monthly s
    JOIN dim_product p
        ON s.product_code = p.product_code
    GROUP BY p.segment, s.fiscal_year
)
SELECT
    sp2020.segment,
    sp2020.product_count AS product_count_2020,
    sp2021.product_count AS product_count_2021,
    sp2021.product_count - sp2020.product_count AS difference
FROM segment_products sp2020
JOIN segment_products sp2021
  ON sp2020.segment = sp2021.segment
 AND sp2020.fiscal_year = 2020
 AND sp2021.fiscal_year = 2021
ORDER BY difference DESC;


-- =============================================================================
-- 5. Products with highest and lowest manufacturing cost
-- =============================================================================
SELECT 
    mc.product_code,
    CONCAT(p.product, ' (', p.variant, ')') AS product,
    mc.manufacturing_cost
FROM fact_manufacturing_cost mc
JOIN dim_product p
    ON mc.product_code = p.product_code
WHERE mc.manufacturing_cost = (
        SELECT MAX(manufacturing_cost) FROM fact_manufacturing_cost
    )
   OR mc.manufacturing_cost = (
        SELECT MIN(manufacturing_cost) FROM fact_manufacturing_cost
    )
ORDER BY mc.manufacturing_cost DESC;


-- =============================================================================
-- 6. Top 5 customers with highest average pre-invoice discount (India, FY 2021)
-- =============================================================================
SELECT 
    c.customer_code,
    c.customer,
    ROUND(AVG(d.pre_invoice_discount_pct), 3) AS average_discount_percentage
FROM fact_pre_invoice_deductions d
JOIN dim_customer c
    ON d.customer_code = c.customer_code
WHERE c.market = 'India'
  AND d.fiscal_year = 2021
GROUP BY c.customer_code, c.customer
ORDER BY average_discount_percentage DESC
LIMIT 5;


-- =============================================================================
-- 7. Monthly gross sales for "Atliq Exclusive"
-- =============================================================================
WITH sales_data AS (
    SELECT 
        MONTHNAME(s.date) AS month,
        MONTH(s.date) AS month_number,
        YEAR(s.date) AS year,
        s.sold_quantity * g.gross_price AS gross_sales
    FROM fact_sales_monthly s
    JOIN fact_gross_price g
        ON s.product_code = g.product_code
       AND s.fiscal_year = g.fiscal_year
    JOIN dim_customer c
        ON s.customer_code = c.customer_code
    WHERE c.customer = 'Atliq Exclusive'
)
SELECT 
    month,
    year,
    CONCAT(ROUND(SUM(gross_sales) / 1000000, 2), ' M') AS gross_sales_amount
FROM sales_data
GROUP BY year, month, month_number
ORDER BY year, month_number;


-- =============================================================================
-- 8. Quarter with maximum sold quantity in FY 2020
-- =============================================================================
WITH sales_quarter AS (
    SELECT 
        sold_quantity,
        CASE 
            WHEN MONTH(date) IN (9,10,11) THEN 'Q1'
            WHEN MONTH(date) IN (12,1,2)  THEN 'Q2'
            WHEN MONTH(date) IN (3,4,5)   THEN 'Q3'
            ELSE 'Q4'
        END AS quarter
    FROM fact_sales_monthly
    WHERE fiscal_year = 2020
)
SELECT 
    quarter,
    SUM(sold_quantity) AS total_sold_quantity
FROM sales_quarter
GROUP BY quarter
ORDER BY total_sold_quantity DESC;


-- =============================================================================
-- 9. Channel contribution to gross sales (FY 2021)
-- =============================================================================
WITH channel_sales AS (
    SELECT 
        c.channel,
        ROUND(
            SUM(s.sold_quantity * g.gross_price) / 1000000, 
            2
        ) AS gross_sales_mln
    FROM dim_customer c
    JOIN fact_sales_monthly s
        ON c.customer_code = s.customer_code
    JOIN fact_gross_price g
        ON s.product_code = g.product_code
       AND s.fiscal_year = g.fiscal_year
    WHERE s.fiscal_year = 2021
    GROUP BY c.channel
)
SELECT 
    channel,
    gross_sales_mln,
    CONCAT(
        ROUND(gross_sales_mln * 100 / SUM(gross_sales_mln) OVER (), 2),
        '%'
    ) AS percentage
FROM channel_sales
ORDER BY gross_sales_mln DESC;


-- =============================================================================
-- 10. Top 3 products per division by sold quantity (FY 2021)
-- =============================================================================
WITH product_rank AS (
    SELECT 
        p.division,
        s.product_code,
        CONCAT(p.product, ' (', p.variant, ')') AS product,
        SUM(s.sold_quantity) AS total_sold_quantity,
        RANK() OVER (
            PARTITION BY p.division
            ORDER BY SUM(s.sold_quantity) DESC
        ) AS rank_order
    FROM fact_sales_monthly s
    JOIN dim_product p
        ON s.product_code = p.product_code
    WHERE s.fiscal_year = 2021
    GROUP BY p.division, s.product_code, p.product, p.variant
)
SELECT 
    division,
    product_code,
    product,
    total_sold_quantity,
    rank_order
FROM product_rank
WHERE rank_order <= 3
ORDER BY division, rank_order;
