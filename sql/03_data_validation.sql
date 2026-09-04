
-- 03. DATA VALIDATION
-- ============================================================
-- Validate the cleaned purchase order view before using it
-- for supplier and procurement analysis.

-- 01. ROW COUNT RECONCILIATION
-- ============================================================
-- Confirm that creating the clean view has not removed
-- records from the raw dataset.

SELECT (SELECT COUNT(*)
        FROM   purchase_orders) AS raw_rows,
       (SELECT COUNT(*)
        FROM   purchase_orders_clean) AS clean_view_rows;

-- VALIDATION RESULT:
-- Raw and cleaned datasets both contain 18,012 rows.


-- 02. ANALYSIS FLAG VALIDATION
-- ============================================================
-- Check the number of records included and excluded by each
-- analysis flag.

SELECT   duplicate_analysis_flag,
         COUNT(*) AS row_count
FROM     purchase_orders_clean
GROUP BY duplicate_analysis_flag;

SELECT   delivery_analysis_flag,
         COUNT(*) AS row_count
FROM     purchase_orders_clean
GROUP BY delivery_analysis_flag;

SELECT   quantity_analysis_flag,
         COUNT(*) AS row_count
FROM     purchase_orders_clean
GROUP BY quantity_analysis_flag;

-- 12 duplicate copies are excluded.
-- 210 records are excluded from delivery analysis.
-- 25 records are excluded from quantity analysis.


-- 03. UNKNOWN ID VALIDATION
-- ============================================================
-- Confirm the number of supplier and part records classified
-- as Unknown during cleaning.

SELECT 'Unknown Suppliers' AS validation_check,
       COUNT(*) AS row_count
FROM   purchase_orders_clean
WHERE  supplier_id_clean = 'Unknown';

SELECT 'Unknown Parts' AS validation_check,
       COUNT(*) AS row_count
FROM   purchase_orders_clean
WHERE  part_id_clean = 'Unknown';

-- 50 records have an Unknown supplier ID.
-- 25 records have an Unknown part ID.


-- 04. REFERENTIAL INTEGRITY
-- ============================================================
-- Check that all cleaned supplier and part IDs, excluding
-- Unknown values, match their master tables.

SELECT po.supplier_id_clean
FROM   purchase_orders_clean AS po
       LEFT OUTER JOIN
       suppliers AS s
       ON po.supplier_id_clean = s.supplier_id
WHERE  po.supplier_id_clean <> 'Unknown'
       AND s.supplier_id IS NULL;

SELECT po.part_id_clean
FROM   purchase_orders_clean AS po
       LEFT OUTER JOIN
       parts AS p
       ON po.part_id_clean = p.part_id
WHERE  po.part_id_clean <> 'Unknown'
       AND p.part_id IS NULL;

-- Both checks returned 0 rows.
-- All known supplier and part IDs match their master tables.


-- 05. DUPLICATE VALIDATION
-- ============================================================
-- Confirm that one row per purchase order line remains after
-- applying the duplicate analysis flag.

SELECT COUNT(*) AS total_rows_retained,
       COUNT(DISTINCT po_line_id) AS distinct_po_line_id_values
FROM   purchase_orders_clean
WHERE  duplicate_analysis_flag = 1;

-- 18,000 rows remain and all 18,000 po_line_id values are unique.


-- 06. DELIVERY FLAG VALIDATION
-- ============================================================
-- Confirm that records marked as eligible for delivery analysis
-- do not contain missing or invalid received dates.

SELECT SUM(CASE WHEN received_date IS NULL THEN 1 ELSE 0 END) AS missing_received_date,
       SUM(CASE WHEN received_date < order_date THEN 1 ELSE 0 END) AS received_before_order_date
FROM   purchase_orders_clean
WHERE  delivery_analysis_flag = 1;

-- Both checks returned 0.


-- 07. QUANTITY FLAG VALIDATION
-- ============================================================
-- Confirm that records marked as eligible for quantity analysis
-- do not contain the quantity issues identified during profiling.

SELECT SUM(CASE WHEN quantity_ordered <= 0 THEN 1 ELSE 0 END) AS invalid_quantity_ordered,
       SUM(CASE WHEN quantity_received > quantity_ordered THEN 1 ELSE 0 END) AS invalid_quantity_received
FROM   purchase_orders_clean
WHERE  quantity_analysis_flag = 1;

-- Both checks returned 0.


-- 08. FULL ANALYSIS ELIGIBILITY
-- ============================================================
-- Count records that pass all three core analysis checks.

SELECT COUNT(*) AS row_count
FROM   purchase_orders_clean
WHERE  duplicate_analysis_flag = 1
       AND delivery_analysis_flag = 1
       AND quantity_analysis_flag = 1;

-- 17,765 records pass all three analysis checks.


-- 09. PROCUREMENT VALUE RECONCILIATION
-- ============================================================
-- Calculate procurement value using records with valid
-- quantities and excluding duplicate copies.

SELECT CAST (SUM(quantity_ordered * unit_cost_gbp) AS DECIMAL (18, 2)) AS total_procurement_value
FROM   purchase_orders_clean
WHERE  duplicate_analysis_flag = 1
       AND quantity_analysis_flag = 1;

-- Deduplicated procurement value = £1,537,753,741.97.
-- Compare against procurement value before duplicate exclusion.

SELECT CAST (SUM(quantity_ordered * unit_cost_gbp) AS DECIMAL (18, 2)) AS total_procurement_value_before_deduplication
FROM   purchase_orders_clean
WHERE  quantity_analysis_flag = 1;


-- Procurement value before duplicate exclusion = £1,539,083,294.50.
-- Duplicate records would overstate procurement value by
-- £1,329,552.53.