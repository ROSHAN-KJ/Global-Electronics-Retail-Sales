/*
================================================================================
PROJECT      : Global Electronics Enterprise Data Warehousing & Analytics
FILE NAME    : 01_database_setup.sql
MODULE       : Physical Schema DDL, Raw Ingestion & Date Harmonization
AUTHOR       : Roshan Kumar
DATABASE     : global_electronics (MySQL 8.0+)
DEPENDENCIES : Raw Source Files (Customers.csv, Products.csv, Stores.csv, 
               Exchange_Rates.csv, Sales.csv)
================================================================================
DESCRIPTION  :
  Initializes the analytical database environment, defines physical relational 
  DDL schemas with primary keys, ingests external CSV files via LOAD DATA INFILE 
  with real-time sanitization, and harmonizes string dates to native DATE types.

TABLE OF CONTENTS:
  1.0 Database Initialization
  2.0 Physical Schema Definitions (DDL)
      2.1 Customers Dimension Table
      2.2 Products Dimension Table
      2.3 Stores Dimension Table
      2.4 Exchange Rates Reference Table
      2.5 Sales Fact Table
  3.0 Bulk Data Ingestion (LOAD DATA INFILE)
      3.1 Customers Load
      3.2 Products Load (Clean $ and Commas)
      3.3 Stores Load (Clean Blank Square Meters)
      3.4 Exchange Rates Load
      3.5 Sales Load
  4.0 Data Type Harmonization & Performance Indexing
================================================================================
*/

-- ============================================================================
-- 1.0 DATABASE INITIALIZATION
-- ============================================================================
CREATE DATABASE IF NOT EXISTS global_electronics
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

USE global_electronics;


-- ============================================================================
-- 2.0 PHYSICAL SCHEMA DEFINITIONS (DDL)
-- ============================================================================

-- 2.1 CUSTOMERS DIMENSION TABLE
DROP TABLE IF EXISTS customers;
CREATE TABLE customers (
    Customerkey INT NOT NULL,
    Gender VARCHAR(20),
    `Name` VARCHAR(100),
    City VARCHAR(100),
    State_code VARCHAR(50),
    State VARCHAR(100),
    Zip_code VARCHAR(50),
    Country VARCHAR(100),
    Continent VARCHAR(50),
    Birthday VARCHAR(50),
    CONSTRAINT pk_customers PRIMARY KEY (Customerkey)
);

-- 2.2 PRODUCTS DIMENSION TABLE
DROP TABLE IF EXISTS products;
CREATE TABLE products (
    Productkey INT NOT NULL,
    Product_name VARCHAR(255),
    Brand VARCHAR(100),
    Color VARCHAR(50),
    Unit_cost_USD DECIMAL(12, 2) NOT NULL,
    Unit_price_USD DECIMAL(12, 2) NOT NULL,
    Subcategorykey INT,
    Subcategory VARCHAR(100),
    Categorykey INT,
    Category VARCHAR(100),
    CONSTRAINT pk_products PRIMARY KEY (Productkey)
);

-- 2.3 STORES DIMENSION TABLE
DROP TABLE IF EXISTS stores;
CREATE TABLE stores (
    Storekey INT NOT NULL,
    Country VARCHAR(100),
    State VARCHAR(100),
    Square_meters INT,
    Open_date VARCHAR(50),
    CONSTRAINT pk_stores PRIMARY KEY (Storekey)
);

-- 2.4 EXCHANGE RATES REFERENCE TABLE
DROP TABLE IF EXISTS exchange_rates;
CREATE TABLE exchange_rates (
    `Date` VARCHAR(50),
    Currency VARCHAR(10) NOT NULL,
    `Exchange` DECIMAL(12, 4) NOT NULL,
    CONSTRAINT pk_exchange_rates PRIMARY KEY (`Date`, Currency)
);

-- 2.5 SALES FACT TABLE
DROP TABLE IF EXISTS sales;
CREATE TABLE sales (
    Order_number INT NOT NULL,
    Line_item INT NOT NULL,
    Order_date VARCHAR(50),
    Delivery_date VARCHAR(50),
    Customerkey INT NOT NULL,
    Storekey INT NOT NULL,
    Productkey INT NOT NULL,
    Quantity INT NOT NULL,
    Currency_code VARCHAR(10) NOT NULL,
    CONSTRAINT pk_sales PRIMARY KEY (Order_number, Line_item)
);


-- ============================================================================
-- 3.0 BULK DATA INGESTION (LOAD DATA INFILE)
-- ============================================================================

-- 3.1 Load Customers (15,266 records)
LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/Customers.csv'
INTO TABLE customers
CHARACTER SET latin1
FIELDS TERMINATED BY ',' 
ENCLOSED BY '"' 
LINES TERMINATED BY '\r\n'
IGNORE 1 LINES;

-- 3.2 Load Products (2,517 records with currency sign cleaning)
LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/Products.csv'
INTO TABLE products
CHARACTER SET latin1
FIELDS TERMINATED BY ',' 
ENCLOSED BY '"' 
LINES TERMINATED BY '\r\n'
IGNORE 1 LINES
(
    Productkey, 
    Product_name, 
    Brand, 
    Color, 
    @raw_cost, 
    @raw_price, 
    Subcategorykey, 
    Subcategory, 
    Categorykey, 
    Category
)
SET 
    Unit_cost_USD  = CAST(REPLACE(REPLACE(TRIM(@raw_cost), '$', ''), ',', '') AS DECIMAL(12, 2)),
    Unit_price_USD = CAST(REPLACE(REPLACE(TRIM(@raw_price), '$', ''), ',', '') AS DECIMAL(12, 2));

-- 3.3 Load Stores (67 records with empty-string handling)
LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/Stores.csv'
INTO TABLE stores
CHARACTER SET latin1
FIELDS TERMINATED BY ',' 
ENCLOSED BY '"' 
LINES TERMINATED BY '\r\n'
IGNORE 1 LINES
(
    Storekey, 
    Country, 
    State, 
    @raw_square_meters, 
    Open_date
)
SET 
    Square_meters = NULLIF(TRIM(@raw_square_meters), '');

-- 3.4 Load Exchange Rates (11,215 records)
LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/Exchange_Rates.csv'
INTO TABLE exchange_rates
FIELDS TERMINATED BY ',' 
ENCLOSED BY '"' 
LINES TERMINATED BY '\r\n'
IGNORE 1 LINES;

-- 3.5 Load Sales (62,884 records)
LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/Sales.csv'
INTO TABLE sales
FIELDS TERMINATED BY ',' 
ENCLOSED BY '"' 
LINES TERMINATED BY '\r\n'
IGNORE 1 LINES;


-- ============================================================================
-- 4.0 DATA TYPE HARMONIZATION & PERFORMANCE INDEXING
-- ============================================================================
SET SQL_SAFE_UPDATES = 0;

-- 4.1 Convert Customers Birthday
UPDATE customers 
SET Birthday = STR_TO_DATE(Birthday, '%m/%d/%Y')
WHERE Birthday IS NOT NULL AND Birthday != '';

ALTER TABLE customers MODIFY COLUMN Birthday DATE NULL;

-- 4.2 Convert Stores Open_date
UPDATE stores 
SET Open_date = STR_TO_DATE(Open_date, '%m/%d/%Y')
WHERE Open_date IS NOT NULL AND Open_date != '';

ALTER TABLE stores MODIFY COLUMN Open_date DATE NULL;

-- 4.3 Convert Exchange Rates Date
UPDATE exchange_rates 
SET `Date` = STR_TO_DATE(`Date`, '%m/%d/%Y')
WHERE `Date` IS NOT NULL AND `Date` != '';

ALTER TABLE exchange_rates MODIFY COLUMN `Date` DATE NOT NULL;

-- 4.4 Convert Sales Dates & Clean In-Store Delivery Blanks
UPDATE sales 
SET Order_date = STR_TO_DATE(Order_date, '%m/%d/%Y')
WHERE Order_date IS NOT NULL AND Order_date != '';

UPDATE sales 
SET Delivery_date = STR_TO_DATE(Delivery_date, '%m/%d/%Y')
WHERE Delivery_date IS NOT NULL AND Delivery_date != '';

UPDATE sales
SET Delivery_date = NULL
WHERE Delivery_date = '' OR TRIM(Delivery_date) = '';

ALTER TABLE sales 
    MODIFY COLUMN Order_date DATE NOT NULL,
    MODIFY COLUMN Delivery_date DATE NULL;

-- 4.5 Foreign Key Performance Indexing
CREATE INDEX idx_sales_order_date ON sales (Order_date);
CREATE INDEX idx_sales_customer   ON sales (Customerkey);
CREATE INDEX idx_sales_product    ON sales (Productkey);
CREATE INDEX idx_sales_store      ON sales (Storekey);

SET SQL_SAFE_UPDATES = 1;