-- ============================================================
-- 01. PROCUREMENT OVERVIEW
-- ============================================================

-- Business question: How much purchasing activity is included
-- in the analysis?
--

-- Duplicate rows and rows with invalid quantities are excluded
-- because a valid ordered quantity is needed to calculate spend.

SELECT SUM(quantity_ordered * unit_cost_gbp) AS total_procurement_value,
       COUNT(*) AS total_order_lines,
       COUNT(DISTINCT po_id) AS distinct_purchase_orders,
       COUNT(DISTINCT supplier_id) AS distinct_suppliers,
       COUNT(DISTINCT part_id) AS distinct_parts
FROM   purchase_orders_clean
WHERE  duplicate_analysis_flag = 1
       AND quantity_analysis_flag = 1;

-- FINDING:
-- The data contains 6,000 purchase orders and 17,975 usable
-- order lines, with a total value of £1.54bn.
-- It covers 48 known suppliers, an Unknown supplier group,
-- and 120 parts.


-- ============================================================
-- 02. SPEND BY SUPPLIER
-- ============================================================

-- Business question: Which suppliers account for the most spend?
--

-- Duplicate rows and rows with invalid quantities are excluded.

SELECT   po.supplier_id_clean,
         s.supplier_name,
         SUM(po.quantity_ordered * po.unit_cost_gbp) AS total_procurement_value,
         COUNT(*) AS order_lines,
         CAST (SUM(quantity_ordered * unit_cost_gbp) / SUM(SUM(quantity_ordered * unit_cost_gbp)) OVER () * 100 AS DECIMAL (10, 2)) AS spend_percentage
FROM     purchase_orders_clean AS po
         LEFT OUTER JOIN
         suppliers AS s
         ON po.supplier_id_clean = s.supplier_id
WHERE    duplicate_analysis_flag = 1
         AND quantity_analysis_flag = 1
GROUP BY po.supplier_id_clean, s.supplier_name
ORDER BY total_procurement_value DESC;

-- FINDING:
-- Spend is spread across many suppliers. S003 has the highest
-- spend at £38.83m, which is 2.53% of the total.
--

-- The five highest-spend suppliers make up about 11.84% of total
-- spend, so the business does not appear to depend heavily on one
-- supplier based on spend alone.


-- ============================================================
-- 03. OTIF PERFORMANCE BY SUPPLIER
-- ============================================================

-- Business question: Which suppliers are furthest below their
-- on-time, in-full (OTIF) targets?
--

-- This includes completed order lines with valid delivery and
-- quantity data. Duplicate rows are excluded.

SELECT   po.supplier_id_clean,
         s.supplier_name,
         COUNT(*) AS completed_order_lines,
         SUM(CASE WHEN po.received_date <= po.promised_date
                       AND po.quantity_received >= po.quantity_ordered THEN 1 ELSE 0 END) AS otif_orders,
         s.target_otif_pct * 100 AS target_otif_pct,
         ROUND(CAST (SUM(CASE WHEN po.received_date <= po.promised_date
                                   AND po.quantity_received >= po.quantity_ordered THEN 1 ELSE 0 END) AS DECIMAL (10, 2)) / COUNT(*) * 100, 2) AS actual_otif_pct,
         ROUND(CAST (SUM(CASE WHEN po.received_date <= po.promised_date
                                   AND po.quantity_received >= po.quantity_ordered THEN 1 ELSE 0 END) AS DECIMAL (10, 2)) / COUNT(*) * 100 - s.target_otif_pct * 100, 2) AS otif_gap
FROM     purchase_orders_clean AS po
         INNER JOIN
         suppliers AS s
         ON po.supplier_id_clean = s.supplier_id
WHERE    po.order_status = 'Complete'
         AND po.duplicate_analysis_flag = 1
         AND po.delivery_analysis_flag = 1
         AND po.quantity_analysis_flag = 1
GROUP BY po.supplier_id_clean, s.supplier_name, s.target_otif_pct
ORDER BY otif_gap ASC;

-- FINDING:
-- Several suppliers are well below their OTIF targets. S027 has
-- the largest gap, with an actual OTIF rate of 23.77% compared
-- with its 94% target, a gap of 70.23 percentage points.
--

-- S014, S041 and S006 also have large gaps and should be looked
-- at in more detail.


-- ============================================================
-- 04. OVERALL OTIF PERFORMANCE
-- ============================================================

-- Business question: What is the overall OTIF rate?
--

-- The same rules used in the supplier OTIF analysis are used here
-- so that the results can be compared fairly.

SELECT COUNT(*) AS completed_order_lines,
       SUM(CASE WHEN received_date <= promised_date
                     AND quantity_received >= quantity_ordered THEN 1 ELSE 0 END) AS otif_orders,
       CAST (ROUND(CAST (SUM(CASE WHEN received_date <= promised_date
                                       AND quantity_received >= quantity_ordered THEN 1 ELSE 0 END) AS DECIMAL (10, 2)) / COUNT(*) * 100, 2) AS DECIMAL (10, 2)) AS Overall_otif_pct
FROM   purchase_orders_clean
WHERE  order_status = 'Complete'
       AND duplicate_analysis_flag = 1
       AND delivery_analysis_flag = 1
       AND quantity_analysis_flag = 1;

-- FINDING:
-- Overall OTIF is 37.37%. Of 16,487 completed and usable order
-- lines, 6,162 were delivered on time and in full.
-- This gives a company-wide result to compare with each supplier.


-- ============================================================
-- 05. MONTHLY OTIF TREND
-- ============================================================

-- Business question: How has OTIF changed from month to month?
--

-- The same completed-order and data-quality rules are used as in
-- the earlier OTIF queries.

WITH   monthly_supplier
AS     (SELECT   DATEFROMPARTS(YEAR(order_date), MONTH(order_date), 1) AS order_month,
                 COUNT(*) AS completed_order_lines,
                 SUM(CASE WHEN received_date <= promised_date
                               AND quantity_received >= quantity_ordered THEN 1 ELSE 0 END) AS otif_orders
        FROM     purchase_orders_clean
        WHERE    order_status = 'Complete'
                 AND duplicate_analysis_flag = 1
                 AND delivery_analysis_flag = 1
                 AND quantity_analysis_flag = 1
        GROUP BY DATEFROMPARTS(YEAR(order_date), MONTH(order_date), 1)),
       monthly_metrics
AS     (SELECT order_month,
               completed_order_lines,
               otif_orders,
               CAST (otif_orders * 100.0 / completed_order_lines AS DECIMAL (10, 2)) AS monthly_otif_pct
        FROM   monthly_supplier)
SELECT -- Show the previous month's rate and the change from that
       -- month so that rises and falls are easy to see.
       order_month,
       completed_order_lines,
       otif_orders,
       monthly_otif_pct,
       LAG(monthly_otif_pct) OVER (ORDER BY order_month) AS previous_month_otif_pct,
       CAST (monthly_otif_pct - LAG(monthly_otif_pct) OVER (ORDER BY order_month) AS DECIMAL (10, 2)) AS mom_otif_change_pp
FROM   monthly_metrics;

-- FINDING:
-- OTIF moves up and down during 2025 rather than following a clear
-- upward or downward trend. It ranges from 35.51% to 40.81% in
-- the months shown, with several monthly changes above three
-- percentage points.


-- ============================================================
-- 06. MONTHLY OTIF FOR THE LOWEST-PERFORMING SUPPLIERS
-- ============================================================

-- Business question: When did OTIF worsen for S006, S014, S027
-- and S041?
--

-- This includes completed order lines with valid delivery and
-- quantity data. Duplicate rows are excluded.

WITH     monthly_supplier_totals
AS       (SELECT   po.supplier_id_clean AS supplier_id,
                   s.supplier_name,
                   DATEFROMPARTS(YEAR(po.order_date), MONTH(po.order_date), 1) AS order_month,
                   COUNT(*) AS completed_order_lines,
                   SUM(CASE WHEN po.received_date <= po.promised_date
                                 AND po.quantity_received >= po.quantity_ordered THEN 1 ELSE 0 END) AS otif_orders
          FROM     purchase_orders_clean AS po
                   INNER JOIN
                   suppliers AS s
                   ON po.supplier_id_clean = s.supplier_id
          WHERE    po.order_status = 'Complete'
                   AND po.duplicate_analysis_flag = 1
                   AND po.delivery_analysis_flag = 1
                   AND po.quantity_analysis_flag = 1
          GROUP BY DATEFROMPARTS(YEAR(po.order_date), MONTH(po.order_date), 1), po.supplier_id_clean, s.supplier_name)
SELECT   order_month,
         supplier_id,
         supplier_name,
         completed_order_lines,
         otif_orders,
         CAST (otif_orders * 100.0 / completed_order_lines AS DECIMAL (10, 2)) AS monthly_otif_pct
FROM     monthly_supplier_totals
WHERE    supplier_id IN ('S006', 'S014', 'S027', 'S041')
ORDER BY supplier_id, order_month;

-- FINDING:
-- OTIF drops sharply for S006, S014, S027 and S041 from January
-- 2026. During 2025, each supplier regularly achieved monthly
-- rates above 30%. From January 2026, their monthly rates are
-- mostly between 0% and 11%.
--

-- This fall happens at the same time as weaker overall OTIF in
-- 2026, so these suppliers are worth investigating further.


-- ============================================================
-- 07. SUPPLIERS TO REVIEW FIRST
-- ============================================================

-- Business question: Which suppliers combine low OTIF with a
-- meaningful level of spend?
--

-- Spend and OTIF use separate data-quality rules because delivery
-- dates are not needed to calculate purchasing value.

WITH     supplier_spend
AS       (SELECT   po.supplier_id_clean AS supplier_id,
                   s.supplier_name,
                   SUM(po.quantity_ordered * po.unit_cost_gbp) AS procurement_value
          FROM     purchase_orders_clean AS po
                   INNER JOIN
                   suppliers AS s
                   ON po.supplier_id_clean = S.supplier_id
          WHERE    po.duplicate_analysis_flag = 1
                   AND po.quantity_analysis_flag = 1
          GROUP BY po.supplier_id_clean, s.supplier_name),
         supplier_otif
AS       (SELECT   po.supplier_id_clean AS supplier_id,
                   s.supplier_name,
                   COUNT(*) AS completed_order_lines,
                   SUM(CASE WHEN po.received_date <= po.promised_date
                                 AND po.quantity_received >= po.quantity_ordered THEN 1 ELSE 0 END) AS otif_orders,
                   CAST (ROUND(CAST (SUM(CASE WHEN po.received_date <= po.promised_date
                                                   AND po.quantity_received >= po.quantity_ordered THEN 1 ELSE 0 END) AS DECIMAL (10, 2)) / COUNT(*) * 100, 2) AS DECIMAL (10, 2)) AS actual_otif_pct
          FROM     purchase_orders_clean AS po
                   INNER JOIN
                   suppliers AS s
                   ON po.supplier_id_clean = s.supplier_id
          WHERE    po.order_status = 'Complete'
                   AND po.duplicate_analysis_flag = 1
                   AND po.delivery_analysis_flag = 1
                   AND po.quantity_analysis_flag = 1
          GROUP BY po.supplier_id_clean, s.supplier_name)
SELECT   ss.supplier_id,
         ss.supplier_name,
         ss.procurement_value,
         so.completed_order_lines,
         so.otif_orders,
         so.actual_otif_pct
FROM     supplier_spend AS ss
         INNER JOIN
         supplier_otif AS so
         ON ss.supplier_id = so.supplier_id
ORDER BY so.actual_otif_pct ASC, ss.procurement_value DESC;

-- FINDING:
-- S027, S014, S041 and S006 have the four lowest supplier OTIF
-- rates, ranging from 23.77% to 27.22%. Together, they account
-- for about £121.7m of spend.
--

-- Their low OTIF, level of spend and decline from January 2026
-- make them the first suppliers to review.

-- Business question: What share of total spend comes from these
-- four suppliers?

SELECT SUM(CASE WHEN supplier_id_clean IN ('S006', 'S014', 'S027', 'S041') THEN quantity_ordered * unit_cost_gbp ELSE 0 END) AS priority_supplier_spend,
       SUM(quantity_ordered * unit_cost_gbp) AS total_procurement_spend,
       CAST (SUM(CASE WHEN supplier_id_clean IN ('S006', 'S014', 'S027', 'S041') THEN quantity_ordered * unit_cost_gbp ELSE 0 END) * 100.0 / SUM(quantity_ordered * unit_cost_gbp) AS DECIMAL (10, 2)) AS priority_spend_pct
FROM   purchase_orders_clean
WHERE  duplicate_analysis_flag = 1
       AND quantity_analysis_flag = 1;

-- FINDING:
-- The four suppliers account for about £121.7m, or 7.91%, of
-- total spend. This is enough financial exposure to support a
-- closer review of their delivery performance.


-- ============================================================
-- 08. OTIF PERFORMANCE BY WAREHOUSE
-- ============================================================

-- Business question: Is poor OTIF mainly linked to one warehouse?
--

-- This includes completed order lines with valid delivery and
-- quantity data. Duplicate rows are excluded.

SELECT   w.warehouse_name,
         COUNT(*) AS completed_order_lines,
         SUM(CASE WHEN po.received_date <= po.promised_date
                       AND po.quantity_received >= po.quantity_ordered THEN 1 ELSE 0 END) AS otif_orders,
         CAST (ROUND(CAST (SUM(CASE WHEN po.received_date <= po.promised_date
                                         AND po.quantity_received >= po.quantity_ordered THEN 1 ELSE 0 END) AS DECIMAL (10, 2)) / COUNT(*) * 100, 2) AS DECIMAL (10, 2)) AS warehouse_otif_pct
FROM     purchase_orders_clean AS po
         INNER JOIN
         warehouses AS w
         ON po.warehouse_id = w.warehouse_id
WHERE    po.order_status = 'Complete'
         AND duplicate_analysis_flag = 1
         AND quantity_analysis_flag = 1
         AND delivery_analysis_flag = 1
GROUP BY po.warehouse_id, w.warehouse_name;

-- FINDING:
-- OTIF is similar across the five warehouses, ranging from 35.91%
-- to 38.25%. Central DC has the lowest rate, but the gap between
-- the highest and lowest warehouse is only 2.34 percentage points.
-- Poor OTIF therefore does not appear to be limited to one site.


-- ============================================================
-- 09. SPEND WITH PRIORITY SUPPLIERS BY PART CATEGORY
-- ============================================================

-- Business question: Which part categories have the most spend
-- with S006, S014, S027 and S041?
--

-- Duplicate rows and rows with invalid quantities are excluded.

SELECT   p.category,
         SUM(po.quantity_ordered * po.unit_cost_gbp) AS procurement_value,
         COUNT(*) AS order_lines
FROM     purchase_orders_clean AS po
         INNER JOIN
         parts AS p
         ON po.part_id_clean = p.part_id
WHERE    po.supplier_id_clean IN ('S006', 'S014', 'S027', 'S041')
         AND po.duplicate_analysis_flag = 1
         AND po.quantity_analysis_flag = 1
GROUP BY p.category
ORDER BY procurement_value DESC;

-- FINDING:
-- The £121.7m spent with the four suppliers covers all six part
-- categories. Mechanical has the highest value at about £27.0m,
-- followed by Cold Chain at £23.8m and Electrical at £20.8m.
-- This means delivery problems with these suppliers could affect
-- several purchasing areas, not just one category.


-- ============================================================
-- 10. PRIORITY SUPPLIERS' SHARE OF 2026 OTIF FAILURES
-- ============================================================

-- Business question: What share of failed OTIF order lines in
-- 2026 came from the four priority suppliers?
--

-- This includes completed order lines with valid delivery and
-- quantity data. Duplicate rows are excluded.

WITH   failure_totals
AS     (SELECT SUM(CASE WHEN NOT (received_date <= promised_date
                                  AND quantity_received >= quantity_ordered) THEN 1 ELSE 0 END) AS total_2026_otif_failures,
               SUM(CASE WHEN supplier_id_clean IN ('S006', 'S014', 'S027', 'S041')
                             AND NOT (received_date <= promised_date
                                      AND quantity_received >= quantity_ordered) THEN 1 ELSE 0 END) AS priority_supplier_failures
        FROM   purchase_orders_clean
        WHERE  order_status = 'Complete'
               AND delivery_analysis_flag = 1
               AND duplicate_analysis_flag = 1
               AND quantity_analysis_flag = 1
               AND YEAR(order_date) = 2026)
SELECT total_2026_otif_failures,
       priority_supplier_failures,
       CAST (priority_supplier_failures * 100.0 / total_2026_otif_failures AS DECIMAL (10, 2)) AS priority_failure_pct
FROM   failure_totals;

-- FINDING:
-- The four suppliers account for 475 of the 3,832 failed OTIF
-- order lines in 2026, or 12.40% of the total.
--

-- This is higher than their 7.91% share of spend, so they account
-- for a larger share of failures than their share of spend.


-- ============================================================
-- 11. SUMMARY AND RECOMMENDATION
-- ============================================================

-- Which suppliers should be reviewed first based on the findings
-- above?
--

-- FINDING:
-- S006, S014, S027 and S041 stand out for further review. They
-- have the four lowest overall supplier OTIF rates, from 23.77%
-- to 27.22%, and their monthly OTIF drops sharply from January
-- 2026.
--

-- Together, they account for about £121.7m, or 7.91%, of total
-- spend and 12.40% of failed OTIF order lines in 2026. Their spend
-- covers all six part categories, with the highest values in
-- Mechanical, Cold Chain and Electrical.
--

-- OTIF is similar across all five warehouses, so the available
-- data does not point to one warehouse as the main cause.
--

-- RECOMMENDATION:
-- Review delivery performance with S006, S014, S027 and S041,
-- starting with the sharp fall seen from January 2026. Give extra
-- attention to Mechanical, Cold Chain and Electrical because they
-- have the most spend with these suppliers.
--

-- More supplier and operational information would be needed to
-- understand why OTIF fell.