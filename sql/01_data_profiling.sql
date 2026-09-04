-- DATASET OVERVIEW
-- Review the size, coverage and structure of the purchase
-- order dataset before carrying out detailed data quality checks.

SELECT COUNT(*) AS total_rows,
       COUNT(DISTINCT po_id) AS unique_purchase_orders,
       COUNT(DISTINCT supplier_id) AS unique_suppliers,
       COUNT(DISTINCT part_id) AS unique_parts,
       COUNT(DISTINCT warehouse_id) AS unique_warehouses,
       MIN(order_date) AS first_order_date,
       MAX(order_date) AS last_order_date
FROM   purchase_orders;

SELECT   order_status,
         COUNT(*) AS row_count
FROM     purchase_orders
GROUP BY order_status
ORDER BY row_count DESC;

-- FINDING:
-- The dataset contains 18,012 purchase order lines across
-- 6,000 purchase orders, covering January 2025 to August 2026.
-- It contains 49 supplier IDs, 120 parts and 5 warehouses.
--
-- Order status consists of 16,712 Complete, 696 Open and
-- 604 Partial records. These reconcile to the total row count.

-- The purchase-order data contains one more supplier ID than
-- the supplier master, indicating an unmatched supplier reference.

SELECT DISTINCT po.supplier_id
FROM   purchase_orders AS po
       LEFT OUTER JOIN
       suppliers AS s
       ON po.supplier_id = s.supplier_id
WHERE  po.supplier_id IS NOT NULL
       AND s.supplier_id IS NULL;

-- FINDING:
-- Purchase order data contains 49 distinct non-null supplier IDs,
-- compared with 48 suppliers in the supplier master.
--
-- Further investigation identified S999 as the unmatched supplier ID.
-- 25 purchase order lines reference S999, but no corresponding
-- supplier record exists in the supplier master.


-- 01. DUPLICATE CHECK
-- Check whether po_line_id contains duplicate records.

SELECT   po_line_id,
         COUNT(*) AS duplicate_count
FROM     purchase_orders
GROUP BY po_line_id
HAVING   COUNT(*) > 1
ORDER BY duplicate_count DESC;

-- 02. MISSING SUPPLIER IDs
-- Check for purchase order lines that do not contain a supplier ID.

SELECT COUNT(*) AS missing_supplier_count
FROM   purchase_orders
WHERE  supplier_id IS NULL;

-- 03. ORPHAN SUPPLIER REFERENCES
-- Check for supplier IDs in purchase_orders that do not match
-- a record in the supplier master table.

SELECT COUNT(*) AS orphan_supplier_count
FROM   purchase_orders AS po
       LEFT OUTER JOIN
       suppliers AS s
       ON po.supplier_id = s.supplier_id
WHERE  s.supplier_id IS NULL
       AND po.supplier_id IS NOT NULL;

-- 04. MISSING PART IDs
-- Check for purchase order lines that do not contain a part ID.

SELECT COUNT(*) AS missing_part_count
FROM   purchase_orders
WHERE  part_id IS NULL;

-- 05. ORPHAN PART REFERENCES
-- Check for part IDs in purchase_orders that do not match
-- a record in the parts master table.

SELECT COUNT(*) AS orphan_part_count
FROM   purchase_orders AS po
       LEFT OUTER JOIN
       parts AS p
       ON po.part_id = p.part_id
WHERE  p.part_id IS NULL
       AND po.part_id IS NOT NULL;

-- 06. INVALID DATE SEQUENCES
-- Check for records where delivery dates occur before the
-- original order date.

SELECT 'Promised Before Order' AS date_issue,
       COUNT(*) AS affected_rows
FROM   purchase_orders
WHERE  promised_date < order_date
UNION ALL
SELECT 'Received Before Order' AS date_issue,
       COUNT(*) AS affected_rows
FROM   purchase_orders
WHERE  received_date < order_date;

-- 07. QUANTITY INTEGRITY CHECKS
-- Check for invalid or unusual quantity values that may affect
-- fulfilment and OTIF calculations.

SELECT 'Non-Positive Quantity Ordered' AS quantity_issue,
       COUNT(*) AS affected_rows
FROM   purchase_orders
WHERE  quantity_ordered <= 0
UNION ALL
SELECT 'Negative Quantity Received' AS quantity_issue,
       COUNT(*) AS affected_rows
FROM   purchase_orders
WHERE  quantity_received < 0
UNION ALL
SELECT 'Received Greater Than Ordered' AS quantity_issue,
       COUNT(*) AS affected_rows
FROM   purchase_orders
WHERE  quantity_received > quantity_ordered;

-- 08. MISSING CRITICAL DATES
-- Check for missing dates required for order and delivery
-- performance analysis.

SELECT 'Missing Order Date' AS date_issue,
       COUNT(*) AS affected_rows
FROM   purchase_orders
WHERE  order_date IS NULL
UNION ALL
SELECT 'Missing Promised Date' AS date_issue,
       COUNT(*) AS affected_rows
FROM   purchase_orders
WHERE  promised_date IS NULL
UNION ALL
SELECT 'Missing Received Date' AS date_issue,
       COUNT(*) AS affected_rows
FROM   purchase_orders
WHERE  received_date IS NULL;

-- 09. DELIVERY STATUS RECONCILIATION
-- Check that completed purchase order lines can be classified
-- as either on time or late.

SELECT COUNT(po_line_id) AS total_completed,
       SUM(CASE WHEN received_date <= promised_date THEN 1 ELSE 0 END) AS on_time_count,
       SUM(CASE WHEN received_date > promised_date THEN 1 ELSE 0 END) AS late_count,
       SUM(CASE WHEN received_date <= promised_date THEN 1 ELSE 0 END) + SUM(CASE WHEN received_date > promised_date THEN 1 ELSE 0 END) AS reconciled_count,
       COUNT(*) - (SUM(CASE WHEN received_date <= promised_date THEN 1 ELSE 0 END) + SUM(CASE WHEN received_date > promised_date THEN 1 ELSE 0 END)) AS reconciled_gap
FROM   purchase_orders
WHERE  order_status = 'Complete';

-- FINDING:
-- 16,712 completed order lines were identified.
-- 16,690 could be classified as either on time or late,
-- leaving a reconciliation gap of 22 records.
-- 10. DATA QUALITY SUMMARY
-- Combine the main data quality issues into one summary table
-- to provide an overall view of the issues identified.

SELECT 'Missing Part ID' AS issue_type,
       COUNT(*) AS affected_rows
FROM   purchase_orders
WHERE  part_id IS NULL
UNION ALL
SELECT 'Missing Supplier ID' AS issue_type,
       COUNT(*) AS affected_rows
FROM   purchase_orders
WHERE  supplier_id IS NULL
UNION ALL
SELECT 'Unmatched Supplier ID' AS issue_type,
       COUNT(*) AS affected_rows
FROM   purchase_orders AS po
       LEFT OUTER JOIN
       suppliers AS s
       ON po.supplier_id = s.supplier_id
WHERE  s.supplier_id IS NULL
       AND po.supplier_id IS NOT NULL
UNION ALL
SELECT 'Received Before Order' AS issue_type,
       COUNT(*) AS affected_rows
FROM   purchase_orders
WHERE  received_date < order_date
UNION ALL
SELECT 'Missing Received Date' AS issue_type,
       COUNT(*) AS affected_rows
FROM   purchase_orders
WHERE  received_date IS NULL
UNION ALL
SELECT 'Non-Positive Quantity Ordered' AS issue_type,
       COUNT(*) AS affected_rows
FROM   purchase_orders
WHERE  quantity_ordered <= 0
UNION ALL
SELECT 'Received Greater Than Ordered' AS issue_type,
       COUNT(*) AS affected_rows
FROM   purchase_orders
WHERE  quantity_received > quantity_ordered;

-- 11. INVESTIGATE RECONCILIATION GAP
-- Compare completed orders with missing delivery dates to
-- understand why some records are neither on time nor late.

SELECT SUM(CASE WHEN received_date <= promised_date THEN 1 ELSE 0 END) AS on_time,
       SUM(CASE WHEN received_date > promised_date THEN 1 ELSE 0 END) AS late,
       SUM(CASE WHEN received_date IS NULL THEN 1 ELSE 0 END) AS received_date_missing,
       SUM(CASE WHEN promised_date IS NULL THEN 1 ELSE 0 END) AS promised_date_missing
FROM   purchase_orders
WHERE  order_status = 'Complete';

-- FINDING:
-- The reconciliation gap is caused by completed order lines
-- with a missing received_date.
-- 12. REVIEW UNRECONCILED COMPLETED ORDERS
-- Review the completed order lines that could not be classified
-- as either on time or late.

SELECT po_line_id,
       po_id,
       order_status,
       supplier_id,
       part_id,
       order_date,
       promised_date,
       received_date
FROM   purchase_orders
WHERE  order_status = 'Complete'
       AND received_date IS NULL;


-- FINDING:
-- 22 completed order lines have a missing received_date.
-- These records cannot currently be classified as either
-- on time or late.
-- CLEANING DECISION:
-- Retain the records, but exclude them from delivery performance
-- calculations that require a valid received_date.


-- SUPPLIER MASTER PROFILING

-- Check supplier master data for duplicate IDs, missing values
-- and invalid lead-time or OTIF target values.


SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT supplier_id) AS unique_supplier_ids,
    SUM(CASE WHEN supplier_id IS NULL THEN 1 ELSE 0 END) AS missing_supplier_id,
    SUM(CASE WHEN supplier_name IS NULL THEN 1 ELSE 0 END) AS missing_supplier_name,
    SUM(CASE WHEN supplier_region IS NULL THEN 1 ELSE 0 END) AS missing_supplier_region,
    SUM(CASE WHEN agreed_lead_time_days IS NULL THEN 1 ELSE 0 END) AS missing_agreed_lead_time_days,
    SUM(CASE WHEN target_otif_pct IS NULL THEN 1 ELSE 0 END) AS missing_target_otif_pct,
    SUM(CASE WHEN agreed_lead_time_days <= 0 THEN 1 ELSE 0 END) lead_time_error,
    SUM(CASE WHEN target_otif_pct < 0
               OR target_otif_pct > 1 THEN 1 ELSE 0 END) AS invalid_otif_target
    
FROM suppliers;

-- FINDING:
-- The supplier master contains 48 records with 48 unique
-- supplier IDs.
-- No missing values were identified in the key supplier fields.
-- All agreed lead times are positive and all OTIF targets fall
-- within the expected 0 to 1 range.


-- PARTS MASTER PROFILING

SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT part_id) AS unique_part_ids,
    COUNT(DISTINCT criticality) AS unique_criticality,
    COUNT(DISTINCT category) AS unique_categories,
    SUM(CASE WHEN part_id IS NULL THEN 1 ELSE 0 END) AS missing_part_id,
    SUM(CASE WHEN part_name IS NULL THEN 1 ELSE 0 END) AS missing_part_name,
    SUM(CASE WHEN category IS NULL THEN 1 ELSE 0 END) AS missing_category,
    SUM(CASE WHEN unit_cost_gbp IS NULL THEN 1 ELSE 0 END) AS missing_units_cost_gbp,
    SUM(CASE WHEN unit_cost_gbp <= 0 THEN 1 ELSE 0 END) AS invalid_unit_cost,
    MIN(unit_cost_gbp) AS minimum_price,
    MAX(unit_cost_gbp) AS maximum_price,
    SUM(CASE WHEN criticality IS NULL THEN 1 ELSE 0 END) AS missing_criticality
FROM parts;

-- FINDING:
-- The parts master contains 120 unique part IDs across
-- 6 categories and 4 criticality levels.
-- No missing values were identified in the key part fields.
-- Unit costs range from £11.52 to £645.06 and no non-positive
-- unit costs were identified.



-- WAREHOUSE MASTER PROFILING

-- Check the warehouse master for duplicate IDs, missing values
-- and regional coverage.

SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT warehouse_id) AS unique_warehouse_ids,
    COUNT(DISTINCT region) AS unique_regions,
    SUM(CASE WHEN warehouse_id IS NULL THEN 1 ELSE 0 END) AS missing_warehouse_id,
    SUM(CASE WHEN warehouse_name IS NULL THEN 1 ELSE 0 END) AS missing_warehouse_name,
    SUM(CASE WHEN region IS NULL THEN 1 ELSE 0 END) AS missing_region
FROM warehouses;

-- FINDING:
-- The warehouse master contains 5 records with 5 unique
-- warehouse IDs across 5 regions.
-- No missing values were identified in the key warehouse fields.



-- DATA PROFILING SUMMARY

-- Profiling identified several data quality issues within the
-- purchase order data that require consideration before analysis.

-- Key issues identified:
-- - 25 records have a missing supplier_id.
-- - 25 records reference supplier S999, which does not exist
--   in the supplier master.
-- - 25 records have a missing part_id.
-- - 185 records have a received_date before the order_date.
-- - 25 records have a missing received_date.
-- - 25 records have a non-positive quantity_ordered.
-- - 25 records have quantity_received greater than quantity_ordered.
--
-- Completed-order reconciliation identified 22 records that
-- could not be classified as on time or late. Investigation
-- confirmed these records have a missing received_date.
--
-- The supplier, parts and warehouse master tables passed the
-- profiling checks, with no missing values or
-- duplicate key issues identified.
