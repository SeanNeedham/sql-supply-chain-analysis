# Procurement & Supplier Performance Analysis

## Project Overview

This project analyses procurement and supplier data for a fictional supply chain business using SQL Server.

The aim is to review the quality of the available data and investigate supplier performance, delivery reliability and commercial exposure. The analysis is intended to identify areas that may require further investigation by procurement and operations teams.

The project follows an end-to-end SQL workflow, including data profiling, cleaning, validation and business analysis.

## Business Problem

The procurement and operations teams are concerned about supplier delivery reliability and potential supply chain risk. However, the specific suppliers, products or operational areas contributing to these issues are not yet known.

The analysis will use the available purchase order data to identify performance patterns, assess supplier exposure and highlight areas that should be prioritised for further investigation.

## Dataset

The project uses four related datasets:

- `purchase_orders` – purchase order line-level transactional data
- `suppliers` – supplier information, including region and agreed performance targets
- `parts` – part and product information
- `warehouses` – warehouse reference information

The purchase order dataset contains 18,012 rows across 6,000 purchase orders and covers the period from January 2025 to August 2026.

## Tools

- SQL Server
- SQL Server Management Studio (SSMS)
- GitHub

## Project Structure

```text
sql-supply-chain-analysis/
│
├── README.md
├── data/
│   └── raw/
│       ├── purchase_orders.csv
│       ├── suppliers.csv
│       ├── parts.csv
│       └── warehouses.csv
│
└── sql/
    └── 01_data_profiling.sql