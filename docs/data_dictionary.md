# Data Dictionary & Enterprise Metric Catalog

**Project:** Global Electronics Retail Enterprise Analytics Suite  
**Architecture:** Analytical Star Schema  
**Currency Standard:** USD ($)  

---

## 1. Dimensional Model Overview

The reporting suite models transactional data via a multi-dimensional star schema connecting atomic sales line-items to descriptive customer, product, store, and temporal entities:

* **Central Fact Table**: `Fact_Sales`
* **Conformed Dimensions**:
  * `Dim_Calendar` (Order Date, Delivery Date, Fiscal Periods)
  * `Dim_Product` (SKUs, Categories, Subcategories, Unit Pricing)
  * `Dim_Store` (Store ID, Country, Region, Channel, Square Meters)
  * `Dim_Customer` (Demographics, Geography, Behavioral RFM Tiers)

---

## 2. Table Schemas & Column Definitions

### A. Fact_Sales (Transactional Orders)
* **`Order Number`** *(Integer / Key)*: Unique transaction order identifier.
* **`Line Item`** *(Integer)*: Sequential line item within a transaction.
* **`Order Date`** *(Date)*: Invoiced date of commercial purchase.
* **`Delivery Date`** *(Date)*: Fulfillment and delivery date.
* **`CustomerKey`** *(Integer / FK)*: Links to `Dim_Customer`.
* **`StoreKey`** *(Integer / FK)*: Links to `Dim_Store` (`0` designates Online fulfillment).
* **`ProductKey`** *(Integer / FK)*: Links to `Dim_Product`.
* **`Quantity`** *(Integer)*: Volume of product units purchased.
* **`Unit Price USD`** *(Decimal)*: Invoiced unit price after FX conversion.
* **`Net Price USD`** *(Decimal)*: Realized price after applying unit discounts.
* **`Unit Cost USD`** *(Decimal)*: Standard production/wholesale cost per SKU.

---

### B. Dim_Product (Product Catalog & SKU Economics)
* **`ProductKey`** *(Integer / PK)*: Primary SKU surrogate key.
* **`Product Name`** *(Varchar)*: Commercial SKU catalog description.
* **`Brand`** *(Varchar)*: Product manufacturing label.
* **`Color`** *(Varchar)*: Cosmetic color variant.
* **`Subcategory`** *(Varchar)*: Operational subgrouping (e.g., Laptops, Desktops, Audio).
* **`Category`** *(Varchar)*: Top-level department (Computers, Home Appliances, Cameras, Cell phones, Games and Toys, TV and Video).
* **`Unit Cost USD`** *(Decimal)*: Base supplier acquisition cost.
* **`Unit Price USD`** *(Decimal)*: Manufacturer suggested retail price (MSRP).

---

### C. Dim_Store (Footprint & Distribution Network)
* **`StoreKey`** *(Integer / PK)*: Unique identifier (`0` = Online Portal; `1–66` = Physical storefronts).
* **`Country`** *(Varchar)*: Host nation.
* **`State`** *(Varchar)*: Regional territorial designation.
* **`Square_meters`** *(Integer)*: Commercial floor area (0 or NULL for Online).
* **`Open_date`** *(Date)*: Commissioning and commercial launch date.

---

### D. Dim_Customer & RFM Segmentation
* **`CustomerKey`** *(Integer / PK)*: Unique account surrogate key.
* **`Gender`** *(Varchar)*: Customer demographic profile.
* **`Name`** *(Varchar)*: Account holder name.
* **`City` / `State` / `Country`** *(Varchar)*: Registered residential address.
* **`Birthday`** *(Date)*: Customer birth date for age cohort grouping.
* **`Customer_Segment`** *(Varchar)*: Behavioral tier mapped from RFM scoring:
  * **Champions**: High monetary spend, recent engagement, frequent order cadence.
  * **Loyal High-Spenders**: High lifetime value with steady buying habits.
  * **Potential Loyalists**: Recent transactors with moderate volume/spend.
  * **At Risk High-Value**: High historical spend with >365 days of inactivity.
  * **Standard Engaged**: Moderate spend velocity with steady historical interaction.
  * **Lost / Dormant**: Low spend and long purchase inactivity (>1,000 days).
  * **Recent New Customers**: First-time buyers with low initial order count.

---

## 3. Mathematical Formula Catalog (DAX & SQL)

| Metric Name | Business Definition | Formula |
| :--- | :--- | :--- |
| **Total Revenue** | Net invoiced top-line revenue | `SUM(Quantity * Net Price USD)` |
| **Total Cost** | Extended total cost of goods sold (COGS) | `SUM(Quantity * Unit Cost USD)` |
| **Gross Profit** | Realized earnings after product costs | `Total Revenue - Total Cost` |
| **Gross Margin %** | Operational gross profit margin | `(Gross Profit / Total Revenue) * 100` |
| **AOV** | Average dollar value generated per order | `Total Revenue / Distinct Orders` |
| **Physical Stores** | Active brick-and-mortar storefronts | `COUNT(StoreKey) WHERE StoreKey <> 0` |
| **Revenue per m²** | Sales density per square meter of retail space | `Physical Revenue / Physical Square Meters` |
| **Profit per m²** | Margin density per square meter of retail space | `Physical Gross Profit / Physical Square Meters` |