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
--
-- The 49 supplier IDs require further investigation because
-- the supplier master contains 48 suppliers.
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
-- Return the affected records so they can be inspected before
-- deciding how they should be handled during cleaning.
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