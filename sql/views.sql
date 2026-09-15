-- =====================================================
-- Crystal Oil and Gas — Downstream Analytics
-- All 22 business-question views
-- Run schema.sql and import the CSV data first.
-- =====================================================

USE crystal_oil_gas;

-- =====================================================
-- SALES & REVENUE
-- =====================================================

-- Which stations generate the highest/lowest revenue, and by how much?
CREATE OR REPLACE VIEW vw_station_revenue AS
SELECT
    s.station_id,
    s.station_name,
    s.location,
    SUM(t.revenue) AS total_revenue
FROM sales_transactions t
JOIN stations s ON t.station_id = s.station_id
GROUP BY s.station_id, s.station_name, s.location
ORDER BY total_revenue DESC;

-- What is the sales trend by product over time?
CREATE OR REPLACE VIEW vw_product_monthly_trend AS
SELECT
    p.product_id,
    p.product_name,
    t.month,
    SUM(t.revenue) AS total_revenue,
    SUM(t.volume)  AS total_volume
FROM sales_transactions t
JOIN products p ON t.product_id = p.product_id
GROUP BY p.product_id, p.product_name, t.month
ORDER BY p.product_name, t.month;

-- Which product contributes the most to total revenue?
CREATE OR REPLACE VIEW vw_product_revenue AS
SELECT
    p.product_id,
    p.product_name,
    SUM(t.revenue) AS total_revenue
FROM sales_transactions t
JOIN products p ON t.product_id = p.product_id
GROUP BY p.product_id, p.product_name
ORDER BY total_revenue DESC;

-- What is the month-over-month revenue growth?
CREATE OR REPLACE VIEW vw_monthly_revenue_growth AS
SELECT
    month,
    SUM(revenue) AS total_revenue,
    LAG(SUM(revenue)) OVER (ORDER BY month) AS prev_month_revenue,
    SUM(revenue) - LAG(SUM(revenue)) OVER (ORDER BY month) AS revenue_change,
    ROUND(
        (SUM(revenue) - LAG(SUM(revenue)) OVER (ORDER BY month))
        / LAG(SUM(revenue)) OVER (ORDER BY month) * 100, 2
    ) AS growth_pct
FROM sales_transactions
GROUP BY month
ORDER BY month;

-- Which stations are underperforming relative to the network average?
CREATE OR REPLACE VIEW vw_station_vs_average AS
SELECT
    s.station_id,
    s.station_name,
    SUM(t.revenue) AS total_revenue,
    (SELECT AVG(station_total)
     FROM (SELECT SUM(revenue) AS station_total
           FROM sales_transactions
           GROUP BY station_id) AS station_totals) AS network_avg_revenue,
    SUM(t.revenue) - (SELECT AVG(station_total)
     FROM (SELECT SUM(revenue) AS station_total
           FROM sales_transactions
           GROUP BY station_id) AS station_totals) AS variance_from_avg,
    CASE
        WHEN SUM(t.revenue) < (SELECT AVG(station_total)
             FROM (SELECT SUM(revenue) AS station_total
                   FROM sales_transactions
                   GROUP BY station_id) AS station_totals)
        THEN 'Below Average'
        ELSE 'Above Average'
    END AS performance_flag
FROM sales_transactions t
JOIN stations s ON t.station_id = s.station_id
GROUP BY s.station_id, s.station_name
ORDER BY total_revenue ASC;


-- =====================================================
-- INVENTORY & STOCK
-- =====================================================

-- Which stations/products frequently run low on stock?
CREATE OR REPLACE VIEW vw_station_stockouts AS
SELECT
    s.station_id,
    s.station_name,
    p.product_name,
    COUNT(*) AS low_stock_days
FROM inventory_stock i
JOIN stations s ON i.station_id = s.station_id
JOIN products p ON i.product_id = p.product_id
WHERE i.closing_stock < 500
GROUP BY s.station_id, s.station_name, p.product_name
ORDER BY low_stock_days DESC;

-- What is the average stock turnover rate per product/station?
CREATE OR REPLACE VIEW vw_stock_turnover AS
SELECT
    s.station_id,
    s.station_name,
    p.product_id,
    p.product_name,
    SUM(i.sold) AS total_sold,
    AVG((i.opening_stock + i.closing_stock) / 2) AS avg_stock_on_hand,
    ROUND(
        SUM(i.sold) / AVG((i.opening_stock + i.closing_stock) / 2), 2
    ) AS turnover_rate
FROM inventory_stock i
JOIN stations s ON i.station_id = s.station_id
JOIN products p ON i.product_id = p.product_id
GROUP BY s.station_id, s.station_name, p.product_id, p.product_name
ORDER BY turnover_rate DESC;

-- Are there products consistently overstocked or understocked?
CREATE OR REPLACE VIEW vw_product_stock_status AS
SELECT
    p.product_id,
    p.product_name,
    SUM(i.sold) AS total_sold,
    ROUND(AVG((i.opening_stock + i.closing_stock) / 2), 2) AS avg_stock_on_hand,
    ROUND(
        SUM(i.sold) / AVG((i.opening_stock + i.closing_stock) / 2), 2
    ) AS turnover_rate,
    CASE
        WHEN SUM(i.sold) / AVG((i.opening_stock + i.closing_stock) / 2) >= 50 THEN 'Fast-moving'
        WHEN SUM(i.sold) / AVG((i.opening_stock + i.closing_stock) / 2) < 38  THEN 'Slower-moving'
        ELSE 'Moderate'
    END AS stock_status
FROM inventory_stock i
JOIN products p ON i.product_id = p.product_id
GROUP BY p.product_id, p.product_name
ORDER BY turnover_rate DESC;

-- How does stock replenishment timing correlate with sales dips?
CREATE OR REPLACE VIEW vw_sales_vs_replenishment AS
SELECT
    s.station_id,
    s.station_name,
    p.product_id,
    p.product_name,
    i.stock_date,
    i.received,
    CASE WHEN i.received > 0 THEN 'Restocked' ELSE 'No Restock' END AS restock_flag,
    COALESCE(t.daily_volume_sold, 0) AS daily_volume_sold
FROM inventory_stock i
JOIN stations s ON i.station_id = s.station_id
JOIN products p ON i.product_id = p.product_id
LEFT JOIN (
    SELECT station_id, product_id, txn_date, SUM(volume) AS daily_volume_sold
    FROM sales_transactions
    GROUP BY station_id, product_id, txn_date
) t ON t.station_id = i.station_id
   AND t.product_id = i.product_id
   AND t.txn_date = i.stock_date
ORDER BY s.station_id, p.product_id, i.stock_date;

-- Which depot supplies the most stations, and is it near capacity?
CREATE OR REPLACE VIEW vw_depot_station_load AS
SELECT
    d.depot_id,
    d.depot_name,
    d.location,
    d.storage_capacity_litres,
    COUNT(s.station_id) AS stations_supplied
FROM depots d
LEFT JOIN stations s ON s.depot_id = d.depot_id
GROUP BY d.depot_id, d.depot_name, d.location, d.storage_capacity_litres
ORDER BY stations_supplied DESC;


-- =====================================================
-- PRICING & MARGINS
-- =====================================================

-- Which product yields the highest/lowest profit margin?
CREATE OR REPLACE VIEW vw_product_margin AS
SELECT
    p.product_id,
    p.product_name,
    ROUND(AVG(pr.cost_price), 2) AS avg_cost_price,
    ROUND(AVG(pr.selling_price), 2) AS avg_selling_price,
    ROUND(AVG(pr.margin), 2) AS avg_margin,
    ROUND(AVG(pr.margin_pct) * 100, 2) AS avg_margin_pct
FROM pricing pr
JOIN products p ON pr.product_id = p.product_id
GROUP BY p.product_id, p.product_name
ORDER BY avg_margin_pct DESC;

-- How do margins vary across stations for the same product?
CREATE OR REPLACE VIEW vw_station_margin_variation AS
SELECT
    s.station_id,
    s.station_name,
    p.product_id,
    p.product_name,
    ROUND(AVG(t.unit_price), 2) AS avg_selling_price,
    ROUND(AVG(pr.cost_price), 2) AS avg_cost_price,
    ROUND(AVG(t.unit_price) - AVG(pr.cost_price), 2) AS avg_margin,
    ROUND(
        (AVG(t.unit_price) - AVG(pr.cost_price)) / AVG(pr.cost_price) * 100, 2
    ) AS avg_margin_pct
FROM sales_transactions t
JOIN stations s ON t.station_id = s.station_id
JOIN products p ON t.product_id = p.product_id
JOIN pricing pr ON pr.product_id = t.product_id AND pr.month = t.month
GROUP BY s.station_id, s.station_name, p.product_id, p.product_name
ORDER BY p.product_id, avg_margin_pct DESC;

-- Has pricing changed over time, and how did it affect sales volume?
CREATE OR REPLACE VIEW vw_price_vs_volume_trend AS
SELECT
    p.product_id,
    p.product_name,
    pr.month,
    pr.selling_price,
    SUM(t.volume) AS total_volume_sold,
    LAG(pr.selling_price) OVER (PARTITION BY p.product_id ORDER BY pr.month) AS prev_month_price,
    ROUND(
        pr.selling_price - LAG(pr.selling_price) OVER (PARTITION BY p.product_id ORDER BY pr.month), 2
    ) AS price_change
FROM pricing pr
JOIN products p ON pr.product_id = p.product_id
JOIN sales_transactions t ON t.product_id = pr.product_id AND t.month = pr.month
GROUP BY p.product_id, p.product_name, pr.month, pr.selling_price
ORDER BY p.product_id, pr.month;

-- Which stations have the best cost-to-revenue efficiency?
CREATE OR REPLACE VIEW vw_station_cost_efficiency AS
SELECT
    s.station_id,
    s.station_name,
    ROUND(SUM(t.revenue), 2) AS total_revenue,
    ROUND(SUM(t.volume * pr.cost_price), 2) AS total_cost,
    ROUND(SUM(t.revenue) - SUM(t.volume * pr.cost_price), 2) AS total_profit,
    ROUND(SUM(t.revenue) / SUM(t.volume * pr.cost_price), 2) AS revenue_to_cost_ratio
FROM sales_transactions t
JOIN stations s ON t.station_id = s.station_id
JOIN pricing pr ON pr.product_id = t.product_id AND pr.month = t.month
GROUP BY s.station_id, s.station_name
ORDER BY revenue_to_cost_ratio DESC;


-- =====================================================
-- HR & STAFF PERFORMANCE
-- =====================================================

-- Who are the top and bottom-performing staff by sales volume/revenue?
-- Note: includes all roles (Station Manager, Pump Attendant, Cashier) rather than
-- filtering to Pump Attendant only. Assumption documented in README.
CREATE OR REPLACE VIEW vw_staff_performance AS
SELECT
    s.staff_id,
    s.name,
    s.role,
    SUM(t.revenue) AS total_revenue,
    SUM(t.volume) AS total_volume
FROM sales_transactions t
JOIN staff s ON t.staff_id = s.staff_id
GROUP BY s.staff_id, s.name, s.role
ORDER BY total_revenue DESC;

-- Is there a correlation between staff tenure and sales performance?
CREATE OR REPLACE VIEW vw_staff_tenure_vs_performance AS
SELECT
    s.staff_id,
    s.name,
    s.role,
    s.tenure_years,
    SUM(t.revenue) AS total_revenue,
    SUM(t.volume) AS total_volume
FROM sales_transactions t
JOIN staff s ON t.staff_id = s.staff_id
GROUP BY s.staff_id, s.name, s.role, s.tenure_years
ORDER BY s.tenure_years DESC;

-- What is the attendance rate per staff/station, and does it affect sales?
CREATE OR REPLACE VIEW vw_staff_attendance_rate AS
SELECT
    s.staff_id,
    s.name,
    s.role,
    st.station_name,
    COUNT(a.attendance_id) AS total_days_logged,
    COUNT(CASE WHEN a.status = 'Present' THEN 1 END) AS days_present,
    ROUND(
        COUNT(CASE WHEN a.status = 'Present' THEN 1 END) / COUNT(a.attendance_id) * 100, 2
    ) AS attendance_rate_pct,
    COALESCE(sp.total_revenue, 0) AS total_revenue
FROM attendance a
JOIN staff s ON a.staff_id = s.staff_id
JOIN stations st ON s.station_id = st.station_id
LEFT JOIN vw_staff_performance sp ON sp.staff_id = s.staff_id
GROUP BY s.staff_id, s.name, s.role, st.station_name, sp.total_revenue
ORDER BY attendance_rate_pct DESC;

-- Which roles or stations have the highest staff attrition?
-- Note: staff table has no hire/termination date, only Active/Inactive status,
-- so this measures current attrition rate, not turnover over time.
CREATE OR REPLACE VIEW vw_staff_turnover_by_role AS
SELECT
    role,
    COUNT(*) AS total_staff,
    COUNT(CASE WHEN status = 'Inactive' THEN 1 END) AS inactive_staff,
    ROUND(
        COUNT(CASE WHEN status = 'Inactive' THEN 1 END) / COUNT(*) * 100, 2
    ) AS attrition_rate_pct
FROM staff
GROUP BY role
ORDER BY attrition_rate_pct DESC;

CREATE OR REPLACE VIEW vw_staff_turnover_by_station AS
SELECT
    s.station_id,
    st.station_name,
    COUNT(*) AS total_staff,
    COUNT(CASE WHEN s.status = 'Inactive' THEN 1 END) AS inactive_staff,
    ROUND(
        COUNT(CASE WHEN s.status = 'Inactive' THEN 1 END) / COUNT(*) * 100, 2
    ) AS attrition_rate_pct
FROM staff s
JOIN stations st ON s.station_id = st.station_id
GROUP BY s.station_id, st.station_name
ORDER BY attrition_rate_pct DESC;

-- How does headcount per station relate to station sales output?
CREATE OR REPLACE VIEW vw_headcount_vs_station_output AS
SELECT
    st.station_id,
    st.station_name,
    COUNT(s.staff_id) AS headcount,
    sr.total_revenue,
    ROUND(sr.total_revenue / COUNT(s.staff_id), 2) AS revenue_per_staff
FROM stations st
JOIN staff s ON s.station_id = st.station_id
JOIN vw_station_revenue sr ON sr.station_id = st.station_id
GROUP BY st.station_id, st.station_name, sr.total_revenue
ORDER BY revenue_per_staff DESC;


-- =====================================================
-- CROSS-DOMAIN / STRATEGIC
-- =====================================================

-- Which stations are top performers across sales, inventory, AND staff (all-round best)?
CREATE OR REPLACE VIEW vw_station_overall_performance AS
WITH revenue_scores AS (
    SELECT station_id, total_revenue
    FROM vw_station_revenue
),
turnover_scores AS (
    SELECT station_id, ROUND(AVG(turnover_rate), 2) AS avg_turnover
    FROM vw_stock_turnover
    GROUP BY station_id
),
attendance_scores AS (
    SELECT s.station_id, ROUND(AVG(a.attendance_rate_pct), 2) AS avg_attendance
    FROM vw_staff_attendance_rate a
    JOIN staff s ON a.staff_id = s.staff_id
    GROUP BY s.station_id
)
SELECT
    st.station_id,
    st.station_name,
    r.total_revenue,
    t.avg_turnover,
    a.avg_attendance,
    RANK() OVER (ORDER BY r.total_revenue DESC) AS revenue_rank,
    RANK() OVER (ORDER BY t.avg_turnover DESC) AS turnover_rank,
    RANK() OVER (ORDER BY a.avg_attendance DESC) AS attendance_rank,
    ROUND(
        (RANK() OVER (ORDER BY r.total_revenue DESC)
       + RANK() OVER (ORDER BY t.avg_turnover DESC)
       + RANK() OVER (ORDER BY a.avg_attendance DESC)) / 3, 2
    ) AS overall_avg_rank
FROM stations st
JOIN revenue_scores r ON r.station_id = st.station_id
JOIN turnover_scores t ON t.station_id = st.station_id
JOIN attendance_scores a ON a.station_id = st.station_id
ORDER BY overall_avg_rank ASC;

-- Are there stations with strong sales but weak inventory management (or vice versa)?
CREATE OR REPLACE VIEW vw_sales_vs_inventory_mismatch AS
SELECT
    station_id,
    station_name,
    total_revenue,
    revenue_rank,
    avg_turnover,
    turnover_rank,
    (CAST(revenue_rank AS SIGNED) - CAST(turnover_rank AS SIGNED)) AS rank_gap,
    CASE
        WHEN CAST(revenue_rank AS SIGNED) <= CAST(turnover_rank AS SIGNED) - 2 THEN 'Strong sales, weak inventory'
        WHEN CAST(turnover_rank AS SIGNED) <= CAST(revenue_rank AS SIGNED) - 2 THEN 'Strong inventory, weak sales'
        ELSE 'Balanced'
    END AS mismatch_flag
FROM vw_station_overall_performance
ORDER BY ABS(CAST(revenue_rank AS SIGNED) - CAST(turnover_rank AS SIGNED)) DESC;

-- What is the overall network health picture combining all four areas? (capstone view)
CREATE OR REPLACE VIEW vw_network_health_overview AS
WITH revenue_scores AS (
    SELECT station_id, total_revenue
    FROM vw_station_revenue
),
turnover_scores AS (
    SELECT station_id, ROUND(AVG(turnover_rate), 2) AS avg_turnover
    FROM vw_stock_turnover
    GROUP BY station_id
),
attendance_scores AS (
    SELECT s.station_id, ROUND(AVG(a.attendance_rate_pct), 2) AS avg_attendance
    FROM vw_staff_attendance_rate a
    JOIN staff s ON a.staff_id = s.staff_id
    GROUP BY s.station_id
),
margin_scores AS (
    SELECT station_id, ROUND(AVG(avg_margin_pct), 2) AS avg_margin_pct
    FROM vw_station_margin_variation
    GROUP BY station_id
)
SELECT
    st.station_id,
    st.station_name,
    r.total_revenue,
    t.avg_turnover,
    a.avg_attendance,
    m.avg_margin_pct,
    RANK() OVER (ORDER BY r.total_revenue DESC) AS revenue_rank,
    RANK() OVER (ORDER BY t.avg_turnover DESC) AS turnover_rank,
    RANK() OVER (ORDER BY a.avg_attendance DESC) AS attendance_rank,
    RANK() OVER (ORDER BY m.avg_margin_pct DESC) AS margin_rank,
    ROUND(
        (RANK() OVER (ORDER BY r.total_revenue DESC)
       + RANK() OVER (ORDER BY t.avg_turnover DESC)
       + RANK() OVER (ORDER BY a.avg_attendance DESC)
       + RANK() OVER (ORDER BY m.avg_margin_pct DESC)) / 4, 2
    ) AS network_health_score,
    CASE
        WHEN (RANK() OVER (ORDER BY r.total_revenue DESC)
            + RANK() OVER (ORDER BY t.avg_turnover DESC)
            + RANK() OVER (ORDER BY a.avg_attendance DESC)
            + RANK() OVER (ORDER BY m.avg_margin_pct DESC)) / 4 <= 2.5 THEN 'Healthy'
        WHEN (RANK() OVER (ORDER BY r.total_revenue DESC)
            + RANK() OVER (ORDER BY t.avg_turnover DESC)
            + RANK() OVER (ORDER BY a.avg_attendance DESC)
            + RANK() OVER (ORDER BY m.avg_margin_pct DESC)) / 4 <= 4.0 THEN 'Needs Attention'
        ELSE 'At Risk'
    END AS health_status
FROM stations st
JOIN revenue_scores r ON r.station_id = st.station_id
JOIN turnover_scores t ON t.station_id = st.station_id
JOIN attendance_scores a ON a.station_id = st.station_id
JOIN margin_scores m ON m.station_id = st.station_id
ORDER BY network_health_score ASC;
