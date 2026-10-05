/*
================================================================================
PROJECT      : Global Electronics Enterprise Data Warehousing & Analytics
FILE NAME    : 03_data_validation.sql
MODULE       : Data Quality Assurance, Referential Integrity & Profiling
AUTHOR       : Roshan Kumar
DATABASE     : global_electronics (MySQL 8.0+)
DEPENDENCIES : 02_staging_setup.sql (Staging tables must be populated)
================================================================================
DESCRIPTION  :
  Executes an enterprise-grade Quality Assurance diagnostic suite. Validates 
  row cardinalities, monitors referential integrity (foreign key orphans), 
  detects chronology/pricing logic violations, profiles missing/whitespace values, 
  and checks categorical consistency across all entities.

TABLE OF CONTENTS:
  1.0 Master Row Count & Order Volume Audit
  2.0 Referential Integrity (Foreign Key Orphans)
  3.0 Numeric Pricing Sanity Sample
  4.0 Temporal Boundary & Annual Pacing
  5.0 Business Logic & Anomaly Screening
  6.0 Blanks & Whitespace Profiling
  7.0 Categorical Domain Verification
================================================================================
*/

USE global_electronics;

-- ============================================================================
-- 1.0 MASTER ROW COUNT & ORDER VOLUME AUDIT
-- ============================================================================
-- Targets: Customers=15,266 | Products=2,517 | Stores=67 | FX=11,215 | Sales=62,884
SELECT 'customers' AS Table_Name, COUNT(*) AS Total_Rows FROM customers_staging
UNION ALL
SELECT 'products', COUNT(*) FROM products_staging
UNION ALL
SELECT 'stores', COUNT(*) FROM stores_staging
UNION ALL
SELECT 'exchange_rates', COUNT(*) FROM exchange_rates_staging
UNION ALL
SELECT 'sales', COUNT(*) FROM sales_staging;

-- Distinct Order Reconciliation (Benchmark: Exactly 26,326)
SELECT COUNT(DISTINCT Order_number) AS Total_Unique_Orders FROM sales_staging;


-- ============================================================================
-- 2.0 REFERENTIAL INTEGRITY (FOREIGN KEY ORPHANS)
-- ============================================================================
-- All orphan counts must return 0
SELECT 
    COUNT(CASE WHEN c.Customerkey IS NULL THEN 1 END) AS Orphan_Customers,
    COUNT(CASE WHEN p.Productkey IS NULL THEN 1 END) AS Orphan_Products,
    COUNT(CASE WHEN s2.Storekey IS NULL THEN 1 END) AS Orphan_Stores
FROM sales_staging s
LEFT JOIN customers_staging c ON s.Customerkey = c.Customerkey
LEFT JOIN products_staging p ON s.Productkey = p.Productkey
LEFT JOIN stores_staging s2 ON s.Storekey = s2.Storekey;


-- ============================================================================
-- 3.0 NUMERIC PRICING SANITY SAMPLE
-- ============================================================================
SELECT 
    Productkey,
    Product_name,
    Unit_cost_USD,
    Unit_price_USD
FROM products_staging
LIMIT 5;


-- ============================================================================
-- 4.0 TEMPORAL BOUNDARY & ANNUAL PACING
-- ============================================================================
SELECT 
    YEAR(Order_date) AS Sales_Year,
    MIN(Order_date) AS Earliest_Order,
    MAX(Order_date) AS Latest_Order,
    COUNT(DISTINCT Order_number) AS Order_Count
FROM sales_staging
GROUP BY YEAR(Order_date)
ORDER BY Sales_Year ASC;


-- ============================================================================
-- 5.0 BUSINESS LOGIC & ANOMALY SCREENING
-- ============================================================================
-- All checks must return 0 flagged records
SELECT 
    'Zero or Negative Quantity' AS Issue_Description, 
    COUNT(*) AS Flagged_Records
FROM sales_staging 
WHERE Quantity <= 0

UNION ALL

SELECT 
    'Duplicate Fact PK (Order_number + Line_item)', 
    COUNT(*) - COUNT(DISTINCT CONCAT(Order_number, '-', Line_item))
FROM sales_staging

UNION ALL

SELECT 
    'Delivery Date Prior to Order Date', 
    COUNT(*)
FROM sales_staging 
WHERE Delivery_date IS NOT NULL 
  AND Delivery_date < Order_date

UNION ALL

SELECT 
    'Products with Zero or Negative Price', 
    COUNT(*) 
FROM products_staging 
WHERE Unit_price_USD <= 0

UNION ALL

SELECT 
    'Products with Negative Cost Basis', 
    COUNT(*) 
FROM products_staging 
WHERE Unit_cost_USD < 0

UNION ALL

SELECT 
    'Products with Cost > Price (Negative Margin SKUs)', 
    COUNT(*) 
FROM products_staging 
WHERE Unit_cost_USD > Unit_price_USD

UNION ALL

SELECT 
    'Customers with Future Birthday', 
    COUNT(*) 
FROM customers_staging 
WHERE Birthday > CURRENT_DATE

UNION ALL

SELECT 
    'Customers Unrealistically Old (>105 yrs) or Underage (<10 yrs)', 
    COUNT(*) 
FROM customers_staging 
WHERE TIMESTAMPDIFF(YEAR, Birthday, '2021-02-20') > 105 
   OR TIMESTAMPDIFF(YEAR, Birthday, '2021-02-20') < 10

UNION ALL

SELECT 
    'Transactions Missing Exchange Rates', 
    COUNT(*) 
FROM sales_staging s
LEFT JOIN exchange_rates_staging er 
    ON s.Currency_code = er.Currency 
    AND s.Order_date = er.`Date`
WHERE er.`Exchange` IS NULL;


-- ============================================================================
-- 6.0 BLANKS & WHITESPACE PROFILING
-- ============================================================================
-- 6.1 Critical Columns Missingness Audit
SELECT 'customers' AS Table_Name, 'Name' AS Column_Name, COUNT(*) AS Missing_Or_Blank_Count 
FROM customers_staging WHERE `Name` IS NULL OR TRIM(`Name`) = ''
UNION ALL
SELECT 'customers', 'Country', COUNT(*) FROM customers_staging WHERE Country IS NULL OR TRIM(Country) = ''
UNION ALL
SELECT 'customers', 'City', COUNT(*) FROM customers_staging WHERE City IS NULL OR TRIM(City) = ''
UNION ALL
SELECT 'customers', 'Birthday', COUNT(*) FROM customers_staging WHERE Birthday IS NULL
UNION ALL
SELECT 'products', 'Product_name', COUNT(*) FROM products_staging WHERE Product_name IS NULL OR TRIM(Product_name) = ''
UNION ALL
SELECT 'products', 'Category', COUNT(*) FROM products_staging WHERE Category IS NULL OR TRIM(Category) = ''
UNION ALL
SELECT 'products', 'Subcategory', COUNT(*) FROM products_staging WHERE Subcategory IS NULL OR TRIM(Subcategory) = ''
UNION ALL
SELECT 'stores', 'Country', COUNT(*) FROM stores_staging WHERE Country IS NULL OR TRIM(Country) = ''
UNION ALL
SELECT 'stores', 'Square_meters (Physical Stores Only)', COUNT(*) 
FROM stores_staging WHERE Storekey != 0 AND (Square_meters IS NULL OR Square_meters <= 0)
UNION ALL
SELECT 'sales', 'Currency_code', COUNT(*) FROM sales_staging WHERE Currency_code IS NULL OR TRIM(Currency_code) = ''
UNION ALL
SELECT 'sales', 'Delivery_date (Pending / Unfulfilled / In-Store)', COUNT(*) FROM sales_staging WHERE Delivery_date IS NULL;

-- 6.2 Leading/Trailing Whitespace Padding Screen
SELECT 'Customer Name Whitespaces' AS Whitespace_Check, COUNT(*) AS Records_With_Padding
FROM customers_staging WHERE LENGTH(`Name`) != LENGTH(TRIM(`Name`))
UNION ALL
SELECT 'Product Name Whitespaces', COUNT(*) 
FROM products_staging WHERE LENGTH(Product_name) != LENGTH(TRIM(Product_name))
UNION ALL
SELECT 'Product Category Whitespaces', COUNT(*) 
FROM products_staging WHERE LENGTH(Category) != LENGTH(TRIM(Category));


-- ============================================================================
-- 7.0 CATEGORICAL DOMAIN VERIFICATION
-- ============================================================================
SELECT Gender, COUNT(*) AS Count_Records FROM customers_staging GROUP BY Gender;
SELECT Currency_code, COUNT(*) AS Count_Records FROM sales_staging GROUP BY Currency_code;
SELECT Category, COUNT(*) AS Count_Records FROM products_staging GROUP BY Category;