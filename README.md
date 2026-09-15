# Procurement & Supplier Performance Analysis

**SQL Server | 18,012 order lines | £1.54bn procurement spend | Jan 2025 – Aug 2026**

An end-to-end SQL investigation into supplier delivery reliability, isolating where OTIF performance breaks down and how much spend is exposed to it.

---

## Executive Summary

### The Problem

Procurement and Operations suspected supplier delivery risk but could not name it. No one knew **which** suppliers, **which** products or **which** sites were driving the failures. Raw purchase order data carried missing IDs, unmatched references, impossible dates and duplicate rows — so no figure could be trusted as a starting point.

### The Solution

A five-stage SQL Server workflow: profile, clean, validate, analyse, reconcile.

- Cleaned IDs and eligibility flags were built into a **reusable `purchase_orders_clean` view**, leaving original values intact.
- Records with issues were **flagged, not deleted** — each row was excluded only from the specific calculations it could distort.
- Every headline figure was reconciled in a final validation pass before reporting.

### The Impact

- Narrowed a vague supply-risk concern down to **four named suppliers**.
- Quantified the exposure: **£121.7m** of spend and **12.40%** of 2026 OTIF failures.
- Pinpointed the break to a specific month — **January 2026** — giving the business a defined window to investigate.

---

## Key Operational Insights

**Overall OTIF is 37.37%.** Only **6,162 of 16,487** eligible completed order lines were delivered on time and in full.

### Four suppliers sit well below the rest
**S027, S014, S041 and S006** hold the four lowest OTIF rates, ranging from **23.77% to 27.22%**.

![Lowest supplier OTIF results](images/lowest_supplier_otif.png)

### Their failure share outweighs their spend share
Together they represent **£121.7m — 7.91%** of total procurement spend, but **12.40%** of failed OTIF order lines in 2026. That gap is the reason they were prioritised: a supplier is only a problem worth escalating when it underperforms *relative to its size*.

![Priority supplier spend](images/priority_supplier_spend.png)

![Priority suppliers' share of OTIF failures](images/priority_supplier_failures.png)

### The decline has a start date
Performance across the four drops sharply from **January 2026** — a step change, not a gradual drift. Month-on-month analysis was used precisely to separate the two.

### It is a supplier problem, not a site problem
Warehouse OTIF ranges only from **35.91% to 38.25%**. Because the spread across sites is narrow while the spread across suppliers is wide, the failure is concentrated upstream.

### Exposure spans the full category range
Spend with the four suppliers covers **all six part categories**, weighted heaviest toward **Mechanical, Cold Chain and Electrical**.

---

## Recommendations & Business Actions

**1. Open a formal delivery review with S006, S014, S027 and S041.**
Centre it on the sharp decline from January 2026 rather than on aggregate performance.

**2. Establish what changed in January 2026.**
Check for supplier, contract or operational changes aligned to that month — the data shows the break but not the cause.

**3. Prioritise Mechanical, Cold Chain and Electrical in that review.**
These carry the highest spend with the four suppliers, so corrective action lands hardest here.

**4. Track OTIF by supplier and by month on an ongoing basis.**
Monthly granularity is what surfaced the January step change; annual reporting would have hidden it.

**5. Gather operational evidence before committing to corrective action.**
Do not act on the delivery data alone.

### What this analysis cannot tell you
- It shows **when and where** OTIF declined, not **why**.
- Root-cause work requires supplier communications, transport records, contract amendments and incident logs — none of which are in scope here.
- OTIF is measured at **order-line level**. These figures are not the percentage of complete purchase orders delivered on time and in full.

---

## The Dataset & Metrics

Four related tables. **18,012 rows** across **6,000 purchase orders**.

| Dataset | Contents |
|---|---|
| `purchase_orders` | Line-level transactional purchase data |
| `suppliers` | Supplier detail, region, agreed performance targets |
| `parts` | Part and product information |
| `warehouses` | Warehouse reference data |

**Metrics measured**

- Procurement spend — by supplier, by part category
- **OTIF rate** (on-time, in-full) — overall, by supplier, by warehouse, by month
- Failed OTIF order lines and share of total failures
- Month-on-month OTIF movement using `LAG()`
- Supplier share of total spend vs share of failures

**Data quality issues identified at profiling**

| Issue | Records |
|---|---|
| Missing supplier ID | 25 |
| Supplier `S999` — absent from supplier master | 25 |
| Missing part ID | 25 |
| Received date before order date | 185 |
| Missing received date | 25 |
| Non-positive ordered quantity | 25 |
| Received quantity exceeds ordered quantity | 25 |
| Duplicate copies | 12 |

After all three eligibility checks, **17,765 records** were fully eligible. Spend analysis ran on **17,975 order lines**, because a valid delivery date is not required to calculate procurement value.

---

## Methodology & Technical Stack

**Stack:** SQL Server · SQL Server Management Studio · GitHub

### 1. Data Profiling — `01_data_profiling.sql`
Scanned all four tables for missing values, duplicates, unmatched IDs, invalid date sequences and implausible quantities.

### 2. Data Cleaning — `02_data_cleaning.sql`
Built the `purchase_orders_clean` view holding cleaned supplier and part IDs alongside the originals, plus analysis eligibility flags controlling spend, quantity and delivery calculations independently.

### 3. Data Validation — `03_data_validation.sql`
Confirmed row counts, duplicate handling, reference-table match rates and procurement totals before any analysis ran.

### 4. Business Analysis — `04_business_analysis.sql`
Analysed supplier spend, OTIF performance, monthly trend, warehouse performance and part-category exposure.

### 5. Final Validation — `05_final_validation.sql`
Reconciled every headline figure against source totals prior to reporting.

### SQL techniques applied
- Joins and aggregate functions
- `CASE` expressions and conditional aggregation
- Common table expressions (CTEs)
- Window functions, including **`LAG()`** for month-on-month trend
- Result reconciliation across stages

### To run it
1. Create a SQL Server database.
2. Import the four CSVs from `data/raw` into `purchase_orders`, `suppliers`, `parts`, `warehouses`.
3. Execute scripts `01` → `05` in order. The cleaning script creates the view the later scripts depend on.
