-- =====================================================
-- Crystal Oil and Gas — Downstream Analytics Database
-- Run this first to create the schema, then import the
-- CSV files into each table in the order below.
-- =====================================================

CREATE DATABASE IF NOT EXISTS crystal_oil_gas;
USE crystal_oil_gas;

-- 1. Depots (no dependencies)
CREATE TABLE depots (
    depot_id                VARCHAR(10)   PRIMARY KEY,
    depot_name              VARCHAR(100)  NOT NULL,
    location                VARCHAR(50)   NOT NULL,
    storage_capacity_litres INT           NOT NULL
);

-- 2. Stations (depends on depots)
CREATE TABLE stations (
    station_id    VARCHAR(10)  PRIMARY KEY,
    station_name  VARCHAR(100) NOT NULL,
    location      VARCHAR(50)  NOT NULL,
    depot_id      VARCHAR(10)  NOT NULL,
    FOREIGN KEY (depot_id) REFERENCES depots(depot_id)
);

-- 3. Products (no dependencies)
CREATE TABLE products (
    product_id    VARCHAR(10)  PRIMARY KEY,
    product_name  VARCHAR(50)  NOT NULL,
    unit          VARCHAR(20)  NOT NULL
);

-- 4. Staff (depends on stations)
CREATE TABLE staff (
    staff_id      VARCHAR(10)   PRIMARY KEY,
    name          VARCHAR(100)  NOT NULL,
    role          VARCHAR(50)   NOT NULL,
    station_id    VARCHAR(10)   NOT NULL,
    hire_date     DATE          NOT NULL,
    status        VARCHAR(20)   NOT NULL,
    tenure_years  DECIMAL(5,2)  NOT NULL,
    FOREIGN KEY (station_id) REFERENCES stations(station_id)
);

-- 5. Pricing (depends on products)
CREATE TABLE pricing (
    pricing_id     VARCHAR(10)   PRIMARY KEY,
    product_id     VARCHAR(10)   NOT NULL,
    month          VARCHAR(7)    NOT NULL,   -- format: YYYY-MM
    cost_price     DECIMAL(10,2) NOT NULL,
    selling_price  DECIMAL(10,2) NOT NULL,
    margin         DECIMAL(10,2) NOT NULL,
    margin_pct     DECIMAL(6,4)  NOT NULL,
    FOREIGN KEY (product_id) REFERENCES products(product_id)
);

-- 6. Sales_Transactions (depends on stations, products, staff)
CREATE TABLE sales_transactions (
    transaction_id  VARCHAR(10)    PRIMARY KEY,
    txn_date        DATE           NOT NULL,
    month           VARCHAR(7)     NOT NULL,
    station_id      VARCHAR(10)    NOT NULL,
    product_id      VARCHAR(10)    NOT NULL,
    staff_id        VARCHAR(10)    NOT NULL,
    volume          DECIMAL(10,1)  NOT NULL,
    unit_price      DECIMAL(10,2)  NOT NULL,
    revenue         DECIMAL(14,2)  NOT NULL,
    FOREIGN KEY (station_id) REFERENCES stations(station_id),
    FOREIGN KEY (product_id) REFERENCES products(product_id),
    FOREIGN KEY (staff_id)   REFERENCES staff(staff_id)
);

-- 7. Inventory_Stock (depends on stations, products)
CREATE TABLE inventory_stock (
    record_id       VARCHAR(10)    PRIMARY KEY,
    stock_date      DATE           NOT NULL,
    station_id      VARCHAR(10)    NOT NULL,
    product_id      VARCHAR(10)    NOT NULL,
    opening_stock   DECIMAL(10,1)  NOT NULL,
    received        DECIMAL(10,1)  NOT NULL,
    sold            DECIMAL(10,1)  NOT NULL,
    closing_stock   DECIMAL(10,1)  NOT NULL,
    FOREIGN KEY (station_id) REFERENCES stations(station_id),
    FOREIGN KEY (product_id) REFERENCES products(product_id)
);

-- 8. Attendance (depends on staff)
CREATE TABLE attendance (
    attendance_id  VARCHAR(10)  PRIMARY KEY,
    staff_id       VARCHAR(10)  NOT NULL,
    att_date       DATE         NOT NULL,
    status         VARCHAR(20)  NOT NULL,
    FOREIGN KEY (staff_id) REFERENCES staff(staff_id)
);


-- =====================================================
-- IMPORT — run in this exact order (parents before children)
-- Adjust the file paths to wherever your CSVs are saved.
-- If LOAD DATA LOCAL INFILE is disabled on your server, use
-- MySQL Workbench's "Table Data Import Wizard" instead — same
-- order, same column mapping.
-- =====================================================

LOAD DATA LOCAL INFILE 'Depots.csv'
INTO TABLE depots
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

LOAD DATA LOCAL INFILE 'Stations.csv'
INTO TABLE stations
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

LOAD DATA LOCAL INFILE 'Products.csv'
INTO TABLE products
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

LOAD DATA LOCAL INFILE 'Staff.csv'
INTO TABLE staff
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

LOAD DATA LOCAL INFILE 'Pricing.csv'
INTO TABLE pricing
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

LOAD DATA LOCAL INFILE 'Sales_Transactions.csv'
INTO TABLE sales_transactions
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

LOAD DATA LOCAL INFILE 'Inventory_Stock.csv'
INTO TABLE inventory_stock
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

LOAD DATA LOCAL INFILE 'Attendance.csv'
INTO TABLE attendance
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

-- Quick sanity check after import
SELECT 'depots' AS tbl, COUNT(*) AS rows_loaded FROM depots
UNION ALL SELECT 'stations', COUNT(*) FROM stations
UNION ALL SELECT 'products', COUNT(*) FROM products
UNION ALL SELECT 'staff', COUNT(*) FROM staff
UNION ALL SELECT 'pricing', COUNT(*) FROM pricing
UNION ALL SELECT 'sales_transactions', COUNT(*) FROM sales_transactions
UNION ALL SELECT 'inventory_stock', COUNT(*) FROM inventory_stock
UNION ALL SELECT 'attendance', COUNT(*) FROM attendance;
