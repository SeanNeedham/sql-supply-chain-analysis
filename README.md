# Procurement & Supplier Performance Analysis

SQL Server | 18,012 order lines | £1.54bn procurement spend | January 2025–August 2026

An end-to-end SQL investigation of supplier delivery reliability, identifying where on-time, in-full (OTIF) performance weakened and how much procurement spend is associated with the suppliers requiring review.

## Project Background

Procurement and Operations needed to identify which suppliers, parts and receiving sites were associated with missed deliveries. The raw purchase-order data contained missing and unmatched identifiers, impossible date sequences, invalid quantities and duplicate copies, making an unvalidated headline OTIF figure unreliable.

Intended stakeholders: Procurement leadership, supplier relationship managers and Operations.

Decision context: Prioritise supplier reviews, investigate the change in delivery performance and establish a repeatable monthly measure. Procurement spend shows commercial exposure, while order-line OTIF measures delivery performance.

## Business Questions

1. What proportion of eligible completed order lines arrived on time and in full?
2. Which suppliers have the lowest OTIF rates, and how much spend is associated with them?
3. When did performance change, and is the pattern also visible across warehouses?
4. Which part categories have the greatest spend with the suppliers requiring review?
5. How do data-quality rules affect spend and delivery measures, and do the final figures reconcile?

## Data Structure & Initial Checks

Four related tables contain 18,012 purchase-order lines across 6,000 purchase orders.

| Dataset | Contents |
|---|---|
| `purchase_orders` | Line-level transactional purchase data |
| `suppliers` | Supplier details, region and agreed performance targets |
| `parts` | Part and product information |
| `warehouses` | Warehouse reference data |

Initial profiling found the following issues. Categories can overlap, so the counts should not be added together.

| Issue | Records |
|---|---:|
| Missing supplier ID | 25 |
| Supplier `S999`, absent from supplier master | 25 |
| Missing part ID | 25 |
| Received date before order date | 185 |
| Missing received date | 25 |
| Non-positive ordered quantity | 25 |
| Received quantity exceeds ordered quantity | 25 |
| Duplicate copies | 12 |

The reusable `purchase_orders_clean` view retains original values alongside cleaned supplier and part IDs and separate eligibility flags. Problem rows are flagged rather than deleted, then excluded only from measures they could distort. After all three eligibility checks, 17,765 records were fully eligible. Spend analysis uses 17,975 order lines because a valid delivery date is not needed to calculate procurement value. OTIF uses 16,487 eligible completed order lines.

## Executive Summary

- Overall OTIF was 37.37%: 6,162 of 16,487 eligible completed order lines arrived on time and in full.
- S027, S014, S041 and S006 had the four lowest supplier OTIF rates, from 23.77% to 27.22%. Together they accounted for £121.7m, or 7.91%, of total procurement spend and 12.40% of failed OTIF order lines in 2026.
- Monthly OTIF for these four suppliers fell sharply from January 2026. The timing gives Procurement a defined period for investigation; the delivery data does not establish the cause.

## Insights Deep Dive

### Supplier reliability and commercial exposure

S027, S014, S041 and S006 were the four lowest-performing suppliers on OTIF. Their 23.77%–27.22% rates were well below the 37.37% overall rate. Supplier performance was assessed alongside spend rather than by either measure alone.

![Lowest supplier OTIF results](images/lowest_supplier_otif.png)

Together, the four suppliers represented £121.7m in procurement spend, or 7.91% of the total. They accounted for 475 of 3,832 failed OTIF order lines in 2026, or 12.40%. The spend share and failure share have different periods and denominators, so their gap is a prioritisation signal rather than a like-for-like risk ratio.

![Priority supplier spend](images/priority_supplier_spend.png)

![Priority suppliers' share of OTIF failures](images/priority_supplier_failures.png)

### Timing and operational footprint

Monthly OTIF for the four suppliers dropped sharply from January 2026 after stronger monthly results during 2025. This points to a specific period for reviewing supplier, contract, transport and operational records.

Across the five warehouses, OTIF ranged from 35.91% to 38.25%. The narrow warehouse range and wider supplier variation support starting with supplier-level investigation, while leaving open the possibility of shared operational causes. Spend with the four suppliers spans all six part categories, with the largest exposure in Mechanical, Cold Chain and Electrical.

## Recommendations

The data identifies where to investigate and what to monitor. Expected impacts are directional until operational evidence identifies causes and corrective actions are tested.

| Priority | Recommendation and evidence | Suggested owner | Expected impact | Metric to track |
|---|---|---|---|---|
| 1 | Open a delivery review with S006, S014, S027 and S041. They have the four lowest OTIF rates and account for £121.7m of spend. Centre the review on the January 2026 decline. | Procurement and supplier relationship managers | Identify practical actions for the suppliers with the clearest delivery exposure. | Monthly supplier OTIF; late and incomplete line counts; spend with each supplier |
| 2 | Establish what changed around January 2026. Review supplier communications, contract amendments, transport records and incident logs. | Procurement and Operations | Separate the observed timing from its underlying cause before committing to a remedy. | Monthly OTIF before and after any confirmed intervention |
| 3 | Prioritise Mechanical, Cold Chain and Electrical within the review. These have the greatest spend with the four suppliers. | Category managers | Focus investigation where the commercial exposure is greatest. | Spend and OTIF by supplier and part category |
| 4 | Report OTIF monthly by supplier and warehouse. The monthly view revealed the step change that aggregate reporting could obscure. | Procurement analytics and Operations | Detect deterioration earlier and check whether improvements persist. | Monthly supplier and warehouse OTIF; change in percentage points |

## Assumptions & Caveats

- OTIF is measured at order-line level. It is not the percentage of complete purchase orders delivered on time and in full.
- Only eligible completed lines enter the OTIF denominator. Spend and delivery measures use different eligibility rules and therefore have different row counts.
- The 7.91% spend share covers total eligible spend, while the 12.40% failure share covers 2026 failed OTIF lines. These figures are useful together for prioritisation but are not directly comparable rates.
- The data shows when and where performance declined, not why. Supplier communications, transport records, contract amendments and incident logs are needed for root-cause work.
- Similar warehouse OTIF rates do not rule out site or shared process issues. This observational analysis cannot assign causation.

## Tools & Technical Approach

SQL Server, SQL Server Management Studio and GitHub support a five-stage workflow:

1. [Data profiling](sql/01_data_profiling.sql) scans all four tables for missing values, duplicates, unmatched IDs, invalid date sequences and implausible quantities.
2. [Data cleaning](sql/02_data_cleaning.sql) creates `purchase_orders_clean` with original and cleaned identifiers plus measure-specific eligibility flags.
3. [Data validation](sql/03_data_validation.sql) checks row counts, duplicate handling, reference matching and procurement totals before analysis.
4. [Business analysis](sql/04_business_analysis.sql) calculates supplier spend and OTIF, monthly trends, warehouse performance and category exposure.
5. [Final validation](sql/05_final_validation.sql) reconciles headline figures against source totals.

The SQL uses joins, aggregations, `CASE` expressions, conditional aggregation, common table expressions and `LAG()` for month-on-month OTIF movement.

### Run the analysis

1. Create a SQL Server database.
2. Import the four CSV files from `data/raw` into `purchase_orders`, `suppliers`, `parts` and `warehouses`.
3. Run scripts 01–05 in order; script 02 creates the view required by later scripts.

## Repository Structure

```text
sql-supply-chain-analysis/
├── README.md
├── data/
│   └── raw/
│       ├── purchase_orders.csv
│       ├── suppliers.csv
│       ├── parts.csv
│       └── warehouses.csv
├── images/
│   ├── lowest_supplier_otif.png
│   ├── priority_supplier_spend.png
│   └── priority_supplier_failures.png
└── sql/
    ├── 01_data_profiling.sql
    ├── 02_data_cleaning.sql
    ├── 03_data_validation.sql
    ├── 04_business_analysis.sql
    └── 05_final_validation.sql
```
