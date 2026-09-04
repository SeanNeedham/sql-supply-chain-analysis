-- ============================================================
-- PURCHASE ORDER DATA CLEANING
-- ============================================================
-- Create a reusable cleaned view while retaining the original
-- purchase-order data.

CREATE VIEW purchase_orders_clean
AS
WITH   cleaned_orders
AS     (SELECT po_line_id,
               po_id,
               order_date,
               supplier_id,
               part_id,
               warehouse_id,
               quantity_ordered,
               promised_date,
               received_date,
               quantity_received,
               unit_cost_gbp,
               order_status,
               -- SUPPLIER ID CLEANING
               -- Missing supplier IDs and unmatched S999 records are
               -- treated as Unknown without changing the raw values.
               CASE WHEN supplier_id = 'S999'
                         OR supplier_id IS NULL THEN 'Unknown' ELSE supplier_id END AS supplier_id_clean,
               -- PART ID CLEANING
               -- Missing part IDs are treated as Unknown because the
               -- correct part cannot be identified from another field.
               CASE WHEN part_id IS NULL THEN 'Unknown' ELSE part_id END AS part_id_clean,
               -- INVALID RECEIVED DATE
               -- The original date is retained because the correct date is unknown.
               CASE WHEN received_date < order_date THEN 1 ELSE 0 END AS invalid_received_date_flag,
               -- MISSING RECEIVED DATE
               -- Missing dates are retained as NULL and flagged.
               CASE WHEN received_date IS NULL THEN 1 ELSE 0 END AS missing_received_date_flag,
               -- DELIVERY ANALYSIS ELIGIBILITY
               -- 1 = eligible and 0 = exclude from delivery analysis.
               CASE WHEN received_date < order_date
                         OR received_date IS NULL THEN 0 ELSE 1 END AS delivery_analysis_flag,
               -- INVALID QUANTITY ORDERED
               -- Zero or negative ordered quantities are retained and flagged.
               CASE WHEN quantity_ordered <= 0 THEN 1 ELSE 0 END AS invalid_quantity_ordered_flag,
               -- INVALID QUANTITY RECEIVED
               -- Quantities above the ordered amount are retained and flagged.
               CASE WHEN quantity_received > quantity_ordered THEN 1 ELSE 0 END AS invalid_quantity_received_flag,
               -- QUANTITY ANALYSIS ELIGIBILITY
               -- 1 = eligible and 0 = exclude from quantity analysis.
               CASE WHEN quantity_ordered <= 0
                         OR quantity_received > quantity_ordered THEN 0 ELSE 1 END AS quantity_analysis_flag,
               -- DUPLICATE RECORDS
               -- Number repeated po_line_id values so duplicate copies can be excluded from analysis.
               ROW_NUMBER() OVER (PARTITION BY po_line_id ORDER BY po_id) AS rn
        FROM   dbo.purchase_orders),
       final_cleaned
AS     (SELECT *,
               -- 1 = keep for analysis and 0 = duplicate copy to exclude.
               CASE WHEN rn > 1 THEN 0 ELSE 1 END AS duplicate_analysis_flag
        FROM   cleaned_orders)
SELECT po_line_id,
       po_id,
       order_date,
       supplier_id,
       part_id,
       warehouse_id,
       quantity_ordered,
       promised_date,
       received_date,
       quantity_received,
       unit_cost_gbp,
       order_status,
       supplier_id_clean,
       part_id_clean,
       invalid_received_date_flag,
       missing_received_date_flag,
       delivery_analysis_flag,
       invalid_quantity_ordered_flag,
       invalid_quantity_received_flag,
       quantity_analysis_flag,
       duplicate_analysis_flag
FROM   final_cleaned;


GO

-- BASIC VALIDATION
-- =============================================
SELECT COUNT(*) AS total_rows,
       SUM(CASE WHEN supplier_id_clean = 'Unknown' THEN 1 ELSE 0 END) AS unknown_supplier_rows,
       SUM(CASE WHEN part_id_clean = 'Unknown' THEN 1 ELSE 0 END) AS unknown_part_rows,
       SUM(CASE WHEN invalid_received_date_flag = 1 THEN 1 ELSE 0 END) AS invalid_received_date_rows,
       SUM(CASE WHEN missing_received_date_flag = 1 THEN 1 ELSE 0 END) AS missing_received_date_rows,
       SUM(CASE WHEN delivery_analysis_flag = 0 THEN 1 ELSE 0 END) AS delivery_excluded_rows,
       SUM(CASE WHEN invalid_quantity_ordered_flag = 1 THEN 1 ELSE 0 END) AS invalid_quantity_ordered_rows,
       SUM(CASE WHEN invalid_quantity_received_flag = 1 THEN 1 ELSE 0 END) AS invalid_quantity_received_rows,
       SUM(CASE WHEN quantity_analysis_flag = 0 THEN 1 ELSE 0 END) AS quantity_excluded_rows,
       SUM(CASE WHEN duplicate_analysis_flag = 0 THEN 1 ELSE 0 END) AS duplicate_excluded_rows,
       SUM(CASE WHEN delivery_analysis_flag = 1
                     AND quantity_analysis_flag = 1
                     AND duplicate_analysis_flag = 1 THEN 1 ELSE 0 END) AS fully_eligible_rows
FROM   purchase_orders_clean;


-- VALIDATION:
-- 18,012 total records.
-- 50 supplier IDs and 25 part IDs classified as Unknown.
-- 210 delivery exclusions, 25 quantity exclusions and
-- 12 duplicate copies.
-- 17,765 records pass all three analysis checks.
