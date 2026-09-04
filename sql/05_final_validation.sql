-- ============================================================
-- FINAL VALIDATION
-- ============================================================
-- Confirm the accuracy and consistency of the main results
-- reported in the business analysis.

-- ============================================================
-- 01. PROCUREMENT TOTALS
-- Confirm the purchase order count, eligible order-line count
-- and total procurement value.

SELECT COUNT(DISTINCT po_id) AS purchase_orders,
       COUNT(*) AS eligible_order_lines,
       CAST (SUM(quantity_ordered * unit_cost_gbp) AS DECIMAL (18, 2)) AS total_procurement_value
FROM   purchase_orders_clean
WHERE  duplicate_analysis_flag = 1
       AND quantity_analysis_flag = 1;

-- VALIDATION RESULT:
-- 6,000 purchase orders and 17,975 eligible order lines.
-- Total procurement value is £1,537,753,741.97 (£1.54bn rounded).
-- These figures match the procurement overview.

-- ============================================================
-- 02. OVERALL OTIF
-- Confirm the overall OTIF result using completed order lines
-- that meet the delivery, quantity and duplicate rules.

SELECT COUNT(*) AS completed_order_lines,
       SUM(CASE WHEN received_date <= promised_date
                     AND quantity_received >= quantity_ordered THEN 1 ELSE 0 END) AS otif_order_lines,
       CAST (SUM(CASE WHEN received_date <= promised_date
                           AND quantity_received >= quantity_ordered THEN 1 ELSE 0 END) * 100.0 / COUNT(*) AS DECIMAL (10, 2)) AS overall_otif_pct
FROM   purchase_orders_clean
WHERE  order_status = 'Complete'
       AND duplicate_analysis_flag = 1
       AND delivery_analysis_flag = 1
       AND quantity_analysis_flag = 1;

-- VALIDATION RESULT:
-- 6,162 of the 16,487 eligible completed order lines met OTIF.
-- The overall OTIF rate is 37.37%, matching the business analysis.


-- ============================================================
-- 03. PRIORITY SUPPLIER SPEND
-- Confirm the procurement value associated with S006, S014,
-- S027 and S041 and their share of total spend.

SELECT CAST (SUM(CASE WHEN supplier_id_clean IN ('S006', 'S014', 'S027', 'S041') THEN quantity_ordered * unit_cost_gbp ELSE 0 END) AS DECIMAL (18, 2)) AS priority_supplier_spend,
       CAST (SUM(quantity_ordered * unit_cost_gbp) AS DECIMAL (18, 2)) AS total_procurement_spend,
       CAST (SUM(CASE WHEN supplier_id_clean IN ('S006', 'S014', 'S027', 'S041') THEN quantity_ordered * unit_cost_gbp ELSE 0 END) * 100.0 / SUM(quantity_ordered * unit_cost_gbp) AS DECIMAL (10, 2)) AS priority_spend_pct
FROM   purchase_orders_clean
WHERE  duplicate_analysis_flag = 1
       AND quantity_analysis_flag = 1;

-- VALIDATION RESULT:
-- S006, S014, S027 and S041 account for £121,705,243.06
-- of procurement spend, equal to 7.91% of the total.
-- These figures match the business analysis.


-- ============================================================
-- 04. PRIORITY SUPPLIERS' SHARE OF 2026 OTIF FAILURES
-- Confirm the number and percentage of 2026 OTIF failures
-- associated with the four priority suppliers.

WITH   failure_totals
AS     (SELECT SUM(CASE WHEN NOT (received_date <= promised_date
                                  AND quantity_received >= quantity_ordered) THEN 1 ELSE 0 END) AS total_2026_otif_failures,
               SUM(CASE WHEN supplier_id_clean IN ('S006', 'S014', 'S027', 'S041')
                             AND NOT (received_date <= promised_date
                                      AND quantity_received >= quantity_ordered) THEN 1 ELSE 0 END) AS priority_supplier_failures
        FROM   purchase_orders_clean
        WHERE  order_status = 'Complete'
               AND YEAR(order_date) = 2026
               AND duplicate_analysis_flag = 1
               AND delivery_analysis_flag = 1
               AND quantity_analysis_flag = 1)
SELECT total_2026_otif_failures,
       priority_supplier_failures,
       CAST (priority_supplier_failures * 100.0 / total_2026_otif_failures AS DECIMAL (10, 2)) AS priority_failure_pct
FROM   failure_totals;

-- VALIDATION RESULT:
-- S006, S014, S027 and S041 account for 475 of the 3,832
-- failed OTIF order lines in 2026, equal to 12.40%.
-- These figures match the business analysis.


-- ============================================================
-- 05. PRIORITY SUPPLIER CATEGORY RECONCILIATION
-- Reconcile spend across the six part categories with the total
-- spend associated with the four priority suppliers.

WITH   category_spend
AS     (SELECT   p.category,
                 SUM(po.quantity_ordered * po.unit_cost_gbp) AS procurement_value
        FROM     purchase_orders_clean AS po
                 INNER JOIN
                 dbo.parts AS p
                 ON po.part_id_clean = p.part_id
        WHERE    po.supplier_id_clean IN ('S006', 'S014', 'S027', 'S041')
                 AND po.duplicate_analysis_flag = 1
                 AND po.quantity_analysis_flag = 1
        GROUP BY p.category)
SELECT COUNT(*) AS category_count,
       CAST (SUM(procurement_value) AS DECIMAL (18, 2)) AS total_category_spend
FROM   category_spend;

-- VALIDATION RESULT:
-- The four priority suppliers have spend across six part
-- categories. The category values total £121,705,243.06,
-- exactly matching the priority-supplier spend.


-- ============================================================
-- 06. LOWEST SUPPLIER OTIF RATES
-- Confirm that the four priority suppliers have the lowest
-- overall OTIF rates in the supplier results.

SELECT   TOP 4 po.supplier_id_clean,
               s.supplier_name,
               COUNT(*) AS completed_order_lines,
               CAST (SUM(CASE WHEN po.received_date <= po.promised_date
                                   AND po.quantity_received >= po.quantity_ordered THEN 1 ELSE 0 END) * 100.0 / COUNT(*) AS DECIMAL (10, 2)) AS actual_otif_pct
FROM     purchase_orders_clean AS po
         INNER JOIN
         dbo.suppliers AS s
         ON po.supplier_id_clean = s.supplier_id
WHERE    po.order_status = 'Complete'
         AND po.duplicate_analysis_flag = 1
         AND po.delivery_analysis_flag = 1
         AND po.quantity_analysis_flag = 1
GROUP BY po.supplier_id_clean, s.supplier_name
ORDER BY actual_otif_pct ASC;

-- VALIDATION RESULT:
-- S027, S014, S041 and S006 are the four suppliers with the
-- lowest overall OTIF rates. Their rates range from 23.77%
-- to 27.22%, matching the business analysis.


-- ============================================================
-- 07. WAREHOUSE OTIF RANGE
-- Confirm the range between the highest and lowest warehouse
-- OTIF results.

WITH   warehouse_otif
AS     (SELECT   po.warehouse_id,
                 CAST (SUM(CASE WHEN po.received_date <= po.promised_date
                                     AND po.quantity_received >= po.quantity_ordered THEN 1 ELSE 0 END) * 100.0 / COUNT(*) AS DECIMAL (10, 2)) AS warehouse_otif_pct
        FROM     purchase_orders_clean AS po
        WHERE    po.order_status = 'Complete'
                 AND po.duplicate_analysis_flag = 1
                 AND po.delivery_analysis_flag = 1
                 AND po.quantity_analysis_flag = 1
        GROUP BY po.warehouse_id)
SELECT COUNT(*) AS warehouse_count,
       MIN(warehouse_otif_pct) AS lowest_warehouse_otif_pct,
       MAX(warehouse_otif_pct) AS highest_warehouse_otif_pct,
       CAST (MAX(warehouse_otif_pct) - MIN(warehouse_otif_pct) AS DECIMAL (10, 2)) AS warehouse_otif_range_pp
FROM   warehouse_otif;


-- VALIDATION RESULT:
-- OTIF across the five warehouses ranges from 35.91% to 38.25%.
-- The difference is 2.34 percentage points, matching the
-- business analysis.



-- ============================================================
-- FINAL VALIDATION SUMMARY
-- ============================================================
-- All headline figures have been reconciled successfully with
-- the results reported in the business analysis.
