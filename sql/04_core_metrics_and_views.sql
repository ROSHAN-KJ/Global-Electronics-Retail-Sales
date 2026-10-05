/*
================================================================================
PROJECT      : Global Electronics Enterprise Data Warehousing & Analytics
FILE NAME    : 04_core_metrics_and_views.sql
MODULE       : Semantic Layer Modeling & Executive KPI Reconciliation
AUTHOR       : Roshan Kumar
DATABASE     : global_electronics (MySQL 8.0+)
DEPENDENCIES : 02_staging_setup.sql, 03_data_validation.sql
================================================================================
DESCRIPTION  :
  Builds the primary denormalized semantic view (vw_sales_enriched). Joins fact 
  and dimension tables, classifies omnichannel paths, normalizes multi-currency 
  transactions to USD using historical daily FX rates, and reconciles top-line 
  revenue and gross margin against financial benchmarks.

TABLE OF CONTENTS:
  1.0 Semantic Modeling View: vw_sales_enriched
  2.0 Executive Financial Reconciliation Audit
================================================================================
*/

USE global_electronics;

-- ============================================================================
-- 1.0 SEMANTIC MODELING VIEW: vw_sales_enriched
-- ============================================================================
CREATE OR REPLACE VIEW vw_sales_enriched AS
SELECT 
    -- Transaction Keys & Identifiers
    s.Order_number,
    s.Line_item,
    s.Order_date,
    s.Delivery_date,
    
    -- Temporal Derivations
    YEAR(s.Order_date) AS Order_Year,
    QUARTER(s.Order_date) AS Order_Quarter,
    MONTH(s.Order_date) AS Order_Month,
    DATE_FORMAT(s.Order_date, '%Y-%m') AS Order_Year_Month,
    DATEDIFF(s.Delivery_date, s.Order_date) AS Delivery_Days,
    
    -- Channel Segregation
    CASE 
        WHEN s.Storekey = 0 THEN 'Online' 
        ELSE 'Physical Store' 
    END AS Channel,
    
    -- Foreign Keys
    s.Customerkey,
    s.Storekey,
    s.Productkey,
    
    -- Customer Attributes & Demographics
    c.`Name` AS Customer_Name,
    c.Gender,
    c.City AS Customer_City,
    c.State AS Customer_State,
    c.Country AS Customer_Country,
    c.Continent AS Customer_Continent,
    TIMESTAMPDIFF(YEAR, c.Birthday, s.Order_date) AS Customer_Age_At_Order,
    
    -- Retail Store Attributes
    st.Country AS Store_Country,
    st.State AS Store_State,
    st.Square_meters,
    
    -- Product Hierarchy
    p.Product_name,
    p.Brand,
    p.Color,
    p.Category,
    p.Subcategory,
    
    -- FX Rate Normalization
    s.Currency_code,
    COALESCE(er.`Exchange`, 1.0000) AS Exchange_Rate,
    
    -- Volume & Unit Economics (USD)
    s.Quantity,
    p.Unit_cost_USD,
    p.Unit_price_USD,
    
    -- Calculated Financial Line-Item Metrics (USD Normalized)
    ROUND(s.Quantity * p.Unit_price_USD, 2) AS Line_Revenue_USD,
    ROUND(s.Quantity * p.Unit_cost_USD, 2) AS Line_Cost_USD,
    ROUND((s.Quantity * p.Unit_price_USD) - (s.Quantity * p.Unit_cost_USD), 2) AS Line_Profit_USD,
    ROUND((((s.Quantity * p.Unit_price_USD) - (s.Quantity * p.Unit_cost_USD)) / (s.Quantity * p.Unit_price_USD)) * 100, 2) AS Line_Profit_Margin_Pct

FROM sales_staging s
INNER JOIN products_staging p 
    ON s.Productkey = p.Productkey
INNER JOIN customers_staging c 
    ON s.Customerkey = c.Customerkey
INNER JOIN stores_staging st 
    ON s.Storekey = st.Storekey
LEFT JOIN exchange_rates_staging er 
    ON s.Currency_code = er.Currency 
    AND s.Order_date = er.`Date`;


-- ============================================================================
-- 2.0 EXECUTIVE FINANCIAL RECONCILIATION AUDIT
-- ============================================================================
-- Benchmarks: Orders: 26,326 | Units: 197,757 | Revenue: $55.76M | Margin: 58.58%
SELECT 
    COUNT(DISTINCT Order_number) AS Total_Orders,
    SUM(Quantity) AS Total_Units_Sold,
    ROUND(SUM(Line_Revenue_USD), 2) AS Total_Revenue_USD,
    ROUND(SUM(Line_Cost_USD), 2) AS Total_Cost_USD,
    ROUND(SUM(Line_Profit_USD), 2) AS Total_Gross_Profit_USD,
    ROUND((SUM(Line_Profit_USD) / SUM(Line_Revenue_USD)) * 100, 2) AS Gross_Margin_Pct,
    ROUND(SUM(Line_Revenue_USD) / COUNT(DISTINCT Order_number), 2) AS Overall_AOV_USD
FROM vw_sales_enriched;