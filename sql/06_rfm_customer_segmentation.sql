/*
================================================================================
PROJECT      : Global Electronics Enterprise Data Warehousing & Analytics
FILE NAME    : 06_rfm_customer_segmentation.sql
MODULE       : RFM Customer Value Segmentation & Production BI View
AUTHOR       : Roshan Kumar
DATABASE     : global_electronics (MySQL 8.0+)
DEPENDENCIES : 04_core_metrics_and_views.sql (Requires vw_sales_enriched)
================================================================================
DESCRIPTION  :
  Implements a full Recency, Frequency, and Monetary (RFM) customer valuation model. 
  Scores all 15,266 customers across quintiles relative to the operational cutoff 
  date (2021-02-20), generates an executive segmentation summary, and builds the 
  production view (vw_customer_rfm_segments) for downstream Power BI consumption.

TABLE OF CONTENTS:
  1.0 RFM Customer Scoring Engine & Executive Summary
  2.0 Analytical View Definition: vw_customer_rfm_segments
  3.0 RFM Customer Segment Distribution & Revenue Contribution
================================================================================
*/

USE global_electronics;

-- ============================================================================
-- 1.0 RFM CUSTOMER SCORING ENGINE & EXECUTIVE SUMMARY
-- ============================================================================
WITH Customer_Raw_RFM AS (
    SELECT 
        Customerkey,
        Customer_Name,
        Customer_Country,
        DATEDIFF('2021-02-20', MAX(Order_date)) AS Recency_Days,
        COUNT(DISTINCT Order_number) AS Frequency,
        ROUND(SUM(Line_Revenue_USD), 2) AS Monetary_USD
    FROM vw_sales_enriched
    GROUP BY Customerkey, Customer_Name, Customer_Country
),
Customer_NTile_Scoring AS (
    SELECT 
        Customerkey,
        Customer_Name,
        Customer_Country,
        Recency_Days,
        Frequency,
        Monetary_USD,
        NTILE(5) OVER (ORDER BY Recency_Days DESC) AS R_Score,
        NTILE(5) OVER (ORDER BY Frequency ASC) AS F_Score,
        NTILE(5) OVER (ORDER BY Monetary_USD ASC) AS M_Score
    FROM Customer_Raw_RFM
),
Customer_Segmentation AS (
    SELECT 
        Customerkey,
        Customer_Name,
        Customer_Country,
        Recency_Days,
        Frequency,
        Monetary_USD,
        R_Score,
        F_Score,
        M_Score,
        ROUND((R_Score + F_Score + M_Score) / 3.0, 2) AS Composite_RFM_Score,
        CASE 
            WHEN R_Score >= 4 AND (F_Score + M_Score) >= 8 THEN 'Champions'
            WHEN R_Score >= 3 AND M_Score >= 4 THEN 'Loyal High-Spenders'
            WHEN R_Score >= 4 AND F_Score <= 2 THEN 'Recent New Customers'
            WHEN R_Score BETWEEN 2 AND 3 AND F_Score >= 3 THEN 'Potential Loyalists'
            WHEN R_Score <= 2 AND M_Score >= 4 THEN 'At Risk High-Value'
            WHEN R_Score = 1 AND F_Score <= 2 THEN 'Lost / Dormant'
            ELSE 'Standard Engaged'
        END AS Customer_Segment
    FROM Customer_NTile_Scoring
)
-- Executive Summary Aggregation
SELECT 
    Customer_Segment,
    COUNT(Customerkey) AS Total_Customers,
    ROUND((COUNT(Customerkey) * 100.0) / SUM(COUNT(Customerkey)) OVER(), 2) AS Customer_Share_Pct,
    ROUND(SUM(Monetary_USD), 2) AS Total_Revenue_Contributed_USD,
    ROUND((SUM(Monetary_USD) * 100.0) / SUM(SUM(Monetary_USD)) OVER(), 2) AS Revenue_Share_Pct,
    ROUND(AVG(Recency_Days), 0) AS Avg_Days_Since_Last_Order,
    ROUND(AVG(Frequency), 2) AS Avg_Order_Count,
    ROUND(AVG(Monetary_USD), 2) AS Avg_Customer_Spend_USD
FROM Customer_Segmentation
GROUP BY Customer_Segment
ORDER BY Total_Revenue_Contributed_USD DESC;


-- ============================================================================
-- 2.0 ANALYTICAL VIEW DEFINITION: vw_customer_rfm_segments
-- ============================================================================
CREATE OR REPLACE VIEW vw_customer_rfm_segments AS
WITH Customer_Raw_RFM AS (
    SELECT 
        Customerkey,
        Customer_Name,
        Customer_Country,
        DATEDIFF('2021-02-20', MAX(Order_date)) AS Recency_Days,
        COUNT(DISTINCT Order_number) AS Frequency,
        ROUND(SUM(Line_Revenue_USD), 2) AS Monetary_USD
    FROM vw_sales_enriched
    GROUP BY Customerkey, Customer_Name, Customer_Country
),
Customer_NTile_Scoring AS (
    SELECT 
        Customerkey,
        Customer_Name,
        Customer_Country,
        Recency_Days,
        Frequency,
        Monetary_USD,
        NTILE(5) OVER (ORDER BY Recency_Days DESC) AS R_Score,
        NTILE(5) OVER (ORDER BY Frequency ASC) AS F_Score,
        NTILE(5) OVER (ORDER BY Monetary_USD ASC) AS M_Score
    FROM Customer_Raw_RFM
)
SELECT 
    Customerkey,
    Customer_Name,
    Customer_Country,
    Recency_Days,
    Frequency,
    Monetary_USD,
    R_Score,
    F_Score,
    M_Score,
    ROUND((R_Score + F_Score + M_Score) / 3.0, 2) AS Composite_RFM_Score,
    CASE 
        WHEN R_Score >= 4 AND (F_Score + M_Score) >= 8 THEN 'Champions'
        WHEN R_Score >= 3 AND M_Score >= 4 THEN 'Loyal High-Spenders'
        WHEN R_Score >= 4 AND F_Score <= 2 THEN 'Recent New Customers'
        WHEN R_Score BETWEEN 2 AND 3 AND F_Score >= 3 THEN 'Potential Loyalists'
        WHEN R_Score <= 2 AND M_Score >= 4 THEN 'At Risk High-Value'
        WHEN R_Score = 1 AND F_Score <= 2 THEN 'Lost / Dormant'
        ELSE 'Standard Engaged'
    END AS Customer_Segment
FROM Customer_NTile_Scoring;


-- ============================================================================
-- 3.0 RFM Customer Segment Distribution & Revenue Contribution
-- ============================================================================
SELECT 
    Customer_Segment,
    COUNT(Customerkey) AS total_customers,
    ROUND(SUM(Monetary_USD), 2) AS total_segment_revenue,
    ROUND(AVG(Monetary_USD), 2) AS avg_ltv,
    ROUND(AVG(Recency_Days), 1) AS avg_recency_days
FROM vw_customer_rfm_segments
GROUP BY Customer_Segment
ORDER BY total_segment_revenue DESC;