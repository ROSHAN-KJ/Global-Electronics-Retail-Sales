/*
================================================================================
PROJECT      : Global Electronics Enterprise Data Warehousing & Analytics
FILE NAME    : 05_business_analysis.sql
MODULE       : Commercial Intelligence, Cohort Retention & Inventory Mix
AUTHOR       : Roshan Kumar
DATABASE     : global_electronics (MySQL 8.0+)
DEPENDENCIES : 04_core_metrics_and_views.sql (Requires vw_sales_enriched)
================================================================================
DESCRIPTION  :
  Executes in-depth commercial SQL queries answering 9 core business objectives: 
  longitudinal revenue velocity (YoY), channel split, category profitability, 
  store footprint density ($/sqm), customer demographic valuation, Pareto 80/20 
  SKU concentration, market basket cross-selling, cohort retention, and store age dynamics.

TABLE OF CONTENTS:
  1.0 Longitudinal Sales Velocity & YoY Growth Dynamics
  2.0 Omnichannel Performance (Online vs Physical Retail)
  3.0 Category & Subcategory Margin Contribution Matrix
  4.0 Territorial Footprint & Store Space Productivity ($/sqm)
  5.0 Demographic Customer Cohort Valuation
  6.0 Pareto 80/20 Inventory Analysis
      6.1 Top 15 SKUs Cumulative Revenue Contribution
      6.2 Core vs Long-Tail Product Summary
  7.0 Market Basket Analysis (Subcategory Cross-Sell Affinity)
  8.0 Customer Acquisition Cohort Retention Matrix
  9.0 Store Age vs Annualized Revenue Velocity
  10.0 Store Footprint & Distribution Channel Validation
================================================================================
*/

USE global_electronics;

-- ============================================================================
-- 1.0 LONGITUDINAL SALES VELOCITY & YOY GROWTH DYNAMICS
-- ============================================================================
WITH Yearly_Performance AS (
    SELECT 
        Order_Year,
        COUNT(DISTINCT Order_number) AS Total_Orders,
        SUM(Quantity) AS Total_Units_Sold,
        ROUND(SUM(Line_Revenue_USD), 2) AS Total_Revenue_USD,
        ROUND(SUM(Line_Profit_USD), 2) AS Total_Profit_USD,
        ROUND((SUM(Line_Profit_USD) / SUM(Line_Revenue_USD)) * 100, 2) AS Profit_Margin_Pct,
        ROUND(SUM(Line_Revenue_USD) / COUNT(DISTINCT Order_number), 2) AS AOV_USD
    FROM vw_sales_enriched
    GROUP BY Order_Year
)
SELECT 
    Order_Year,
    Total_Orders,
    Total_Units_Sold,
    Total_Revenue_USD,
    ROUND(
        ((Total_Revenue_USD - LAG(Total_Revenue_USD) OVER (ORDER BY Order_Year)) 
        / LAG(Total_Revenue_USD) OVER (ORDER BY Order_Year)) * 100, 
        2
    ) AS YoY_Revenue_Growth_Pct,
    Total_Profit_USD,
    Profit_Margin_Pct,
    AOV_USD
FROM Yearly_Performance
ORDER BY Order_Year ASC;


-- ============================================================================
-- 2.0 OMNICHANNEL PERFORMANCE (ONLINE VS PHYSICAL RETAIL)
-- ============================================================================
SELECT 
    Channel,
    COUNT(DISTINCT Order_number) AS Orders_Count,
    ROUND(COUNT(DISTINCT Order_number) * 100.0 / SUM(COUNT(DISTINCT Order_number)) OVER(), 2) AS Order_Share_Pct,
    SUM(Quantity) AS Units_Sold,
    ROUND(SUM(Line_Revenue_USD), 2) AS Revenue_USD,
    ROUND(SUM(Line_Revenue_USD) * 100.0 / SUM(SUM(Line_Revenue_USD)) OVER(), 2) AS Revenue_Share_Pct,
    ROUND(SUM(Line_Profit_USD), 2) AS Profit_USD,
    ROUND((SUM(Line_Profit_USD) / SUM(Line_Revenue_USD)) * 100, 2) AS Margin_Pct,
    ROUND(SUM(Line_Revenue_USD) / COUNT(DISTINCT Order_number), 2) AS AOV_USD,
    ROUND(AVG(Delivery_Days), 1) AS Avg_Delivery_Days
FROM vw_sales_enriched
GROUP BY Channel;


-- ============================================================================
-- 3.0 CATEGORY & SUBCATEGORY MARGIN CONTRIBUTION MATRIX
-- ============================================================================
SELECT 
    Category,
    COUNT(DISTINCT Subcategory) AS Active_Subcategories,
    SUM(Quantity) AS Units_Sold,
    ROUND(SUM(Line_Revenue_USD), 2) AS Total_Revenue_USD,
    ROUND(SUM(Line_Revenue_USD) * 100.0 / SUM(SUM(Line_Revenue_USD)) OVER(), 2) AS Revenue_Contribution_Pct,
    ROUND(SUM(Line_Profit_USD), 2) AS Total_Profit_USD,
    ROUND((SUM(Line_Profit_USD) / SUM(Line_Revenue_USD)) * 100, 2) AS Margin_Pct
FROM vw_sales_enriched
GROUP BY Category
ORDER BY Total_Revenue_USD DESC;


-- ============================================================================
-- 4.0 TERRITORIAL FOOTPRINT & STORE SPACE PRODUCTIVITY ($/SQM)
-- ============================================================================
SELECT 
    st.Country AS Store_Country,
    COUNT(DISTINCT st.Storekey) AS Total_Stores,
    COUNT(DISTINCT s.Order_number) AS Total_Orders,
    SUM(s.Quantity) AS Units_Sold,
    ROUND(SUM(s.Line_Revenue_USD), 2) AS Revenue_USD,
    ROUND(SUM(s.Line_Revenue_USD) * 100.0 / SUM(SUM(s.Line_Revenue_USD)) OVER(), 2) AS Revenue_Share_Pct,
    ROUND(SUM(s.Line_Profit_USD), 2) AS Profit_USD,
    ROUND((SUM(Line_Profit_USD) / SUM(Line_Revenue_USD)) * 100, 2) AS Margin_Pct,
    ROUND(
        SUM(CASE WHEN s.Storekey != 0 THEN s.Line_Revenue_USD ELSE 0 END) / 
        NULLIF(SUM(DISTINCT CASE WHEN s.Storekey != 0 THEN st.Square_meters ELSE NULL END), 0),
        2
    ) AS Revenue_Per_SqMeter_USD
FROM vw_sales_enriched s
INNER JOIN stores_staging st ON s.Storekey = st.Storekey
GROUP BY st.Country
ORDER BY Revenue_USD DESC;


-- ============================================================================
-- 5.0 DEMOGRAPHIC CUSTOMER COHORT VALUATION
-- ============================================================================
WITH Customer_Cohort_Metrics AS (
    SELECT 
        CASE 
            WHEN Customer_Age_At_Order < 25 THEN 'Under 25'
            WHEN Customer_Age_At_Order BETWEEN 25 AND 34 THEN '25-34'
            WHEN Customer_Age_At_Order BETWEEN 35 AND 49 THEN '35-49'
            WHEN Customer_Age_At_Order BETWEEN 50 AND 64 THEN '50-64'
            ELSE '65+'
        END AS Age_Bracket,
        Gender,
        Customerkey,
        Order_number,
        Line_Revenue_USD,
        Line_Profit_USD
    FROM vw_sales_enriched
)
SELECT 
    Age_Bracket,
    Gender,
    COUNT(DISTINCT Customerkey) AS Unique_Purchasers,
    COUNT(DISTINCT Order_number) AS Total_Orders,
    ROUND(SUM(Line_Revenue_USD), 2) AS Total_Revenue_USD,
    ROUND(SUM(Line_Revenue_USD) * 100.0 / SUM(SUM(Line_Revenue_USD)) OVER(), 2) AS Revenue_Contribution_Pct,
    ROUND(SUM(Line_Revenue_USD) / COUNT(DISTINCT Order_number), 2) AS AOV_USD,
    ROUND((SUM(Line_Profit_USD) / SUM(Line_Revenue_USD)) * 100, 2) AS Margin_Pct
FROM Customer_Cohort_Metrics
GROUP BY Age_Bracket, Gender
ORDER BY 
    FIELD(Age_Bracket, 'Under 25', '25-34', '35-49', '50-64', '65+'),
    Gender ASC;


-- ============================================================================
-- 6.0 PARETO 80/20 INVENTORY ANALYSIS
-- ============================================================================

-- 6.1 Top 15 SKUs Cumulative Revenue Contribution
WITH Product_Revenue AS (
    SELECT 
        Productkey,
        Product_name,
        Category,
        Subcategory,
        ROUND(SUM(Line_Revenue_USD), 2) AS Product_Revenue_USD,
        ROUND(SUM(Line_Profit_USD), 2) AS Product_Profit_USD
    FROM vw_sales_enriched
    GROUP BY Productkey, Product_name, Category, Subcategory
),
Product_Pareto AS (
    SELECT 
        Productkey,
        Product_name,
        Category,
        Subcategory,
        Product_Revenue_USD,
        Product_Profit_USD,
        ROUND(
            (SUM(Product_Revenue_USD) OVER (ORDER BY Product_Revenue_USD DESC) * 100.0) 
            / SUM(Product_Revenue_USD) OVER (), 
            2
        ) AS Cumulative_Revenue_Pct
    FROM Product_Revenue
)
SELECT 
    Productkey,
    Product_name,
    Category,
    Subcategory,
    Product_Revenue_USD,
    Cumulative_Revenue_Pct,
    CASE 
        WHEN Cumulative_Revenue_Pct <= 80.0 THEN 'Top 80% (Core Driver)'
        ELSE 'Long-tail 20%'
    END AS Pareto_Class
FROM Product_Pareto
ORDER BY Product_Revenue_USD DESC
LIMIT 15;

-- 6.2 Core vs Long-Tail Product Summary
WITH Product_Revenue AS (
    SELECT 
        Productkey,
        SUM(Line_Revenue_USD) AS Product_Revenue_USD
    FROM vw_sales_enriched
    GROUP BY Productkey
),
Product_Pareto AS (
    SELECT 
        Productkey,
        Product_Revenue_USD,
        ROUND(
            (SUM(Product_Revenue_USD) OVER (ORDER BY Product_Revenue_USD DESC) * 100.0) 
            / SUM(Product_Revenue_USD) OVER (), 
            2
        ) AS Cumulative_Revenue_Pct
    FROM Product_Revenue
)
SELECT 
    COUNT(CASE WHEN Cumulative_Revenue_Pct <= 80.0 THEN 1 END) AS Core_80Pct_SKUs,
    COUNT(CASE WHEN Cumulative_Revenue_Pct > 80.0 THEN 1 END) AS Long_Tail_SKUs,
    COUNT(*) AS Total_Active_SKUs,
    ROUND(
        (COUNT(CASE WHEN Cumulative_Revenue_Pct <= 80.0 THEN 1 END) * 100.0) / COUNT(*), 
        2
    ) AS Core_SKU_Pct_Share
FROM Product_Pareto;


-- ============================================================================
-- 7.0 MARKET BASKET ANALYSIS (SUBCATEGORY CROSS-SELL AFFINITY)
-- ============================================================================
WITH Order_Subcategories AS (
    SELECT DISTINCT 
        Order_number,
        Subcategory
    FROM vw_sales_enriched
)
SELECT 
    a.Subcategory AS Item_A,
    b.Subcategory AS Item_B,
    COUNT(*) AS Times_Bought_Together
FROM Order_Subcategories a
INNER JOIN Order_Subcategories b 
    ON a.Order_number = b.Order_number
   AND a.Subcategory < b.Subcategory -- Eliminates identical self-pairs and permutations
GROUP BY a.Subcategory, b.Subcategory
ORDER BY Times_Bought_Together DESC
LIMIT 10;


-- ============================================================================
-- 8.0 CUSTOMER ACQUISITION COHORT RETENTION MATRIX
-- ============================================================================
WITH Customer_First_Purchase AS (
    SELECT 
        Customerkey,
        MIN(Order_date) AS First_Order_Date,
        DATE_FORMAT(MIN(Order_date), '%Y-%m-01') AS Cohort_Month
    FROM vw_sales_enriched
    GROUP BY Customerkey
),
Customer_Activities AS (
    SELECT 
        s.Customerkey,
        c.Cohort_Month,
        PERIOD_DIFF(
            DATE_FORMAT(s.Order_date, '%Y%m'), 
            DATE_FORMAT(c.First_Order_Date, '%Y%m')
        ) AS Month_Number
    FROM vw_sales_enriched s
    INNER JOIN Customer_First_Purchase c ON s.Customerkey = c.Customerkey
    GROUP BY s.Customerkey, c.Cohort_Month, Month_Number
)
SELECT 
    Cohort_Month,
    COUNT(DISTINCT CASE WHEN Month_Number = 0 THEN Customerkey END) AS Cohort_Size,
    ROUND((COUNT(DISTINCT CASE WHEN Month_Number = 1 THEN Customerkey END) * 100.0) / 
          COUNT(DISTINCT CASE WHEN Month_Number = 0 THEN Customerkey END), 2) AS Retention_M1_Pct,
    ROUND((COUNT(DISTINCT CASE WHEN Month_Number = 3 THEN Customerkey END) * 100.0) / 
          COUNT(DISTINCT CASE WHEN Month_Number = 0 THEN Customerkey END), 2) AS Retention_M3_Pct,
    ROUND((COUNT(DISTINCT CASE WHEN Month_Number = 6 THEN Customerkey END) * 100.0) / 
          COUNT(DISTINCT CASE WHEN Month_Number = 0 THEN Customerkey END), 2) AS Retention_M6_Pct,
    ROUND((COUNT(DISTINCT CASE WHEN Month_Number = 12 THEN Customerkey END) * 100.0) / 
          COUNT(DISTINCT CASE WHEN Month_Number = 0 THEN Customerkey END), 2) AS Retention_M12_Pct
FROM Customer_Activities
GROUP BY Cohort_Month
ORDER BY Cohort_Month ASC
LIMIT 12;


-- ============================================================================
-- 9.0 STORE AGE VS ANNUALIZED REVENUE VELOCITY
-- ============================================================================
SELECT 
    st.Storekey,
    st.Country,
    st.State,
    st.Square_meters,
    st.Open_date,
    TIMESTAMPDIFF(YEAR, st.Open_date, '2021-02-20') AS Store_Age_Years,
    COUNT(DISTINCT s.Order_number) AS Total_Orders,
    ROUND(SUM(s.Line_Revenue_USD), 2) AS Lifetime_Revenue_USD,
    ROUND(SUM(s.Line_Revenue_USD) / NULLIF(st.Square_meters, 0), 2) AS Revenue_Per_SqM,
    ROUND(
        SUM(s.Line_Revenue_USD) / NULLIF(TIMESTAMPDIFF(YEAR, st.Open_date, '2021-02-20'), 0), 
        2
    ) AS Annualized_Revenue_USD
FROM stores_staging st
INNER JOIN vw_sales_enriched s ON st.Storekey = s.Storekey
WHERE st.Storekey != 0
GROUP BY st.Storekey, st.Country, st.State, st.Square_meters, st.Open_date
ORDER BY Revenue_Per_SqM DESC
LIMIT 10;

SELECT COUNT(*)
FROM stores_staging
WHERE StoreKey <> 0
;


-- ============================================================================
-- 10.0 Store Footprint & Distribution Channel Validation
-- ============================================================================
SELECT 
	CASE 
		WHEN StoreKey = 0 THEN 'Online'
        ELSE 'Physical Store'
	END AS channel,
    COUNT(StoreKey) AS Total_stores,
    SUM(Square_meters) AS Total_Square_meters
FROM stores_staging
GROUP BY 
	CASE
		WHEN Storekey = 0 THEN 'Online'
        ELSE 'Physical Store'
	END;