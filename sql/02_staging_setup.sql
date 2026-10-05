/*
================================================================================
PROJECT      : Global Electronics Enterprise Data Warehousing & Analytics
FILE NAME    : 02_staging_setup.sql
MODULE       : Staging Layer Architecture & Immutable Table Cloning
AUTHOR       : Roshan Kumar
DATABASE     : global_electronics (MySQL 8.0+)
DEPENDENCIES : 01_database_setup.sql (Physical tables must exist and be populated)
================================================================================
DESCRIPTION  :
  Establishes an isolated staging environment by creating identical clones of all 
  physical tables. Decouples raw persistent tables from analytical views to protect 
  data lineage and maintain pipeline reproducibility.

TABLE OF CONTENTS:
  1.0 Customers Staging Table
  2.0 Products Staging Table
  3.0 Stores Staging Table
  4.0 Exchange Rates Staging Table
  5.0 Sales Staging Table
================================================================================
*/

USE global_electronics;

-- 1.0 CUSTOMERS STAGING TABLE
DROP TABLE IF EXISTS customers_staging;
CREATE TABLE customers_staging LIKE customers;
INSERT INTO customers_staging SELECT * FROM customers;

-- 2.0 PRODUCTS STAGING TABLE
DROP TABLE IF EXISTS products_staging;
CREATE TABLE products_staging LIKE products;
INSERT INTO products_staging SELECT * FROM products;

-- 3.0 STORES STAGING TABLE
DROP TABLE IF EXISTS stores_staging;
CREATE TABLE stores_staging LIKE stores;
INSERT INTO stores_staging SELECT * FROM stores;

-- 4.0 EXCHANGE RATES STAGING TABLE
DROP TABLE IF EXISTS exchange_rates_staging;
CREATE TABLE exchange_rates_staging LIKE exchange_rates;
INSERT INTO exchange_rates_staging SELECT * FROM exchange_rates;

-- 5.0 SALES STAGING TABLE
DROP TABLE IF EXISTS sales_staging;
CREATE TABLE sales_staging LIKE sales;
INSERT INTO sales_staging SELECT * FROM sales;