# PLI Capital & Value-Chain Radar India (2022–2026)

An end-to-end enterprise data engineering and business intelligence project tracking India's **Production-Linked Incentive (PLI)** schemes across **all 14 official sectors** over **5 fiscal years (`FY 2021-22` through `FY 2025-26`)**.

Built using **Python**, **`uv`**, **SQLAlchemy (`psycopg2-binary`)**, **PostgreSQL (`omniretail`)**, and **Tableau Public**.

---

## Table of Contents

1. [Project Motives & Business Context](#project-motives--business-context)

2. [Data Sources & Provenance](#data-sources--provenance)

3. [Environment Setup & Execution Guide](#environment-setup--execution-guide)

4. [Data Cleaning & ETL Pipeline Steps](#data-cleaning--etl-pipeline-steps)

5. [PostgreSQL Warehouse & Analytics Views](#postgresql-warehouse--analytics-views)

6. [Project Directory Structure](#project-directory-structure)

7. [Disaster Recovery & Database Rebuild](#disaster-recovery--database-rebuild)

8. [Tableau Public Dashboard Workflow](#tableau-public-dashboard-workflow)

9. [Engineering Trade-Offs & Troubleshooting Notes](#engineering-trade-offs--troubleshooting-notes)

---

## Project Motives & Business Context

India's Production-Linked Incentive (PLI) framework spans multiple ministries and manufacturing verticals to boost domestic value addition, export competitiveness, and job creation.

Individual policy releases and ministry summaries are published separately. Analysts, supply-chain teams, and decision-makers benefit from a **single, unified, multi-year dataset** where every sector can be compared consistently.

This project was built to support four core goals:

* **Complete Multi-Year Coverage:** Bring all **14 PLI sectors** across **5 complete fiscal years (`FY 2021-22` to `FY 2025-26`)** into one balanced **70-row** table (`14 sectors × 5 fiscal years`) with zero empty cells.

* **Capital vs. Labor Trade-Off Analysis:** Compare capital-heavy manufacturing sectors against high-employment sectors using normalized metrics such as investment per job (`investment_per_job_cr`), jobs created per crore invested (`jobs_per_cr_invested`), and share percentages.

* **Export & Growth Benchmarking:** Track cumulative exports (`cumulative_exports_cr`), export share, year-over-year export growth (`exports_growth_pct` and `yoy_exports_growth_pct`), and annual sector rankings (`investment_rank` and `employment_rank`).

* **Repeatable, Zero-Compiler-Error Engineering:** Provide a clean, repeatable ELT/ETL pipeline managed with `uv` and `psycopg2-binary` that creates schemas, loads raw data safely, builds SQL views, and exports BI-ready CSV files.

---

## Data Sources & Provenance

The master dataset (`data/raw/india_pli_all_14_sectors_2022_2026.csv`) is compiled from official public disclosures and policy reporting channels:

* **Press Information Bureau (PIB):** Official government releases and milestone updates on PLI scheme disbursements, investments, production, and exports.

* **Lok Sabha / Parliament Replies:** Official ministerial responses sharing sector-wise progress, employment numbers, and scheme implementation details.

* **NITI Aayog Impact Assessments:** Policy evaluations and value-chain performance insights across priority manufacturing sectors.

Each row includes `fiscal_year`, `as_of_date`, and `data_basis` so every metric stays tied to its reporting period and basis.

---

## Environment Setup & Execution Guide

### Prerequisites

* **Python `>= 3.11`** and **`uv`**

* **PostgreSQL** with database **`omniretail`**

### Step 1: Configure `.env`

Copy `.env.example` to `.env` and fill in your PostgreSQL settings:

```bash
cp .env.example .env
```

Supported environment variables in `src/etl_pipeline.py`:

```env
POSTGRES_HOST=localhost
POSTGRES_PORT=5432
POSTGRES_DB=omniretail
POSTGRES_USER=postgres
POSTGRES_PASSWORD=your_password
# Optional full connection string:
# DATABASE_URL=postgresql+psycopg2://postgres:your_password@localhost:5432/omniretail
```

### Step 2: Install Dependencies with `uv`

Install dependencies using `psycopg2-binary` so you do not need a C compiler (`cc`):

```bash
uv sync
```

### Step 3: Run the Pipeline

```bash
uv run python src/etl_pipeline.py
```

Expected output:

```text
Loaded 70 rows into raw.pli_sectors
Exported processed CSVs to data/processed/:
- tableau_pli_sector_kpis.csv
- tableau_pli_ministry_summary.csv
- tableau_pli_yearly_trends.csv
```

---

## Data Cleaning & ETL Pipeline Steps

`src/etl_pipeline.py` runs a clear, step-by-step pipeline every time it executes:

1. **Dynamic Path Resolution:** Resolves `BASE_DIR` from the script location (`Path(__file__).resolve().parent.parent`) so commands work cleanly regardless of the folder name.

2. **Text Cleaning:** Trims extra spaces on `fiscal_year`, `ministry`, `sector`, and `data_basis`, and casts them cleanly as strings.

3. **Date Parsing:** Converts `as_of_date` into standard ISO dates (`.dt.date`) for PostgreSQL `DATE` columns.

4. **Numeric Type Coercion & Rounding:** Converts float metrics (`cumulative_investment_cr`, `cumulative_exports_cr`, `investment_share_pct`, `investment_per_job_cr`, `exports_growth_pct`) to numbers and rounds them to 4 decimal places.

5. **Employment Integer Enforcement:** Converts `cumulative_employment` to numeric, fills missing values with `0` where needed, and casts to `int64` (`BIGINT` in PostgreSQL).

6. **Null Check Gate:** Raises a `ValueError` if unexpected nulls remain after cleaning, stopping bad data before load.

7. **Safe Database Load:** Runs `sql/01_schema.sql`, truncates `raw.pli_sectors` inside a transaction (`TRUNCATE TABLE raw.pli_sectors;`), and loads all 70 rows cleanly via SQLAlchemy.

8. **SQL Views & CSV Export:** Runs `sql/02_analytics_views.sql` and writes three processed CSVs into `data/processed/`:

   * `data/processed/tableau_pli_sector_kpis.csv`

   * `data/processed/tableau_pli_ministry_summary.csv`

   * `data/processed/tableau_pli_yearly_trends.csv`

---

## PostgreSQL Warehouse & Analytics Views

All SQL views live inside the `analytics` schema and are defined in `sql/02_analytics_views.sql`:

### 1. `analytics.v_pli_sector_kpis` (Sector × Fiscal Year Grain — 70 Rows)

* Calculates `calculated_investment_share_pct` and `export_share_pct` per `fiscal_year` using `NULLIF(..., 0)` to avoid divide-by-zero errors.

* Calculates `jobs_per_cr_invested` (`cumulative_employment::numeric / cumulative_investment_cr::numeric`) rounded to 2 decimal places.

* Ranks sectors each year by investment (`investment_rank`) and employment (`employment_rank`) using `DENSE_RANK()`.

### 2. `analytics.v_pli_ministry_summary` (Ministry × Fiscal Year Grain)

* Rolls up `sector_count`, `total_investment_cr`, `total_exports_cr`, and `total_employment` by ministry and fiscal year.

* Computes `ministry_investment_share_pct` for each year and `investment_cr_per_job` at the ministry level.

### 3. `analytics.v_pli_yearly_trends` (Fiscal Year Grain — 5 Rows)

* Summarizes `active_sectors`, `total_investment_cr`, `total_exports_cr`, and `total_employment` across all 14 sectors per fiscal year.

* Computes `investment_cr_per_job` and `yoy_exports_growth_pct` across fiscal years using `LAG(...) OVER (ORDER BY as_of_date)`.

---

## Project Directory Structure

```text
enterprise_analytics/
├── .env.example
├── .gitignore
├── README.md
├── pyproject.toml
├── data/
│   ├── raw/
│   │   └── india_pli_all_14_sectors_2022_2026.csv
│   └── processed/                  # Created by src/etl_pipeline.py
│       ├── tableau_pli_sector_kpis.csv
│       ├── tableau_pli_ministry_summary.csv
│       └── tableau_pli_yearly_trends.csv
├── sql/
│   ├── 01_schema.sql
│   └── 02_analytics_views.sql
└── src/
    └── etl_pipeline.py
```

---

## Disaster Recovery & Database Rebuild

If PostgreSQL stops or you need a fresh `omniretail` database, rebuild it cleanly with these commands:

```bash
sudo service postgresql start
sudo -u postgres psql -c "DROP DATABASE IF EXISTS omniretail;"
sudo -u postgres psql -c "CREATE DATABASE omniretail;"
uv sync
uv run python src/etl_pipeline.py
```

Because the schema, SQL views, and ETL script are idempotent, re-running the pipeline restores all tables, views, and processed CSV files from scratch.

---

## Tableau Public Dashboard Workflow

Here are the simple, step-by-step instructions from connecting your data to publishing your dashboard:

### 1. Connect Your Data File

* **Where:** Open **Tableau Public** and look under **Connect → To a File**.

* **How:** Click **Text file** and pick `data/processed/tableau_pli_sector_kpis.csv`.

* **What next:** Wait for the data list on the left side to show your fields (`Fiscal Year`, `Sector`, `Ministry`, `Cumulative Investment Cr`, `Cumulative Exports Cr`, and `Cumulative Employment`).

### 2. Build Your Sheets (Keep All 14 Sectors)

* **Where:** Your worksheet area and the **Sheet +** button at the bottom.

* **How:**

  * Drag `Fiscal Year` to **Columns** and drag `Cumulative Investment Cr` and `Cumulative Exports Cr` to **Rows** to see all 5 years (`FY 2021-22` to `FY 2025-26`).

  * On new sheets, drag `Sector` to **Rows** (keep all 14 sectors visible) and drag `Cumulative Investment Cr`, `Cumulative Exports Cr`, or `Cumulative Employment` to **Columns**.

  * Drag `Ministry` to **Rows** and `Cumulative Investment Cr` to **Columns** for a ministry view.

  * Add `Fiscal Year` to **Filters** when you want to focus on a specific year, and turn on labels under **Marks → Label** so numbers are easy to read.

* **What next:** Name each sheet tab clearly at the bottom (right-click tab → **Rename**).

### 3. Put Your Sheets Together on a Dashboard

* **Where:** Click the **New Dashboard** button at the bottom (the grid with a `+` sign).

* **How:**

  * Drag your sheets onto the big white dashboard space so they fit cleanly without crowding.

  * Click your 5-year trend chart inside the dashboard, then click the small **Funnel / Filter** icon at the top-right corner of that box so clicking a year filters the other charts.

* **What next:** Rename the dashboard tab at the bottom to a clear title like `PLI Dashboard`.

### 4. Publish to Tableau Public

* **Where:** The blue **Publish As...** button at the top-right corner of Tableau Public.

* **How:**

  * Click **Publish As...**.

  * Sign in to your Tableau Public account if asked.

  * Type `PLI Capital & Value-Chain Radar India (2022-2026)` and click **Publish**.

* **What next:** Open your profile on `public.tableau.com` (or the browser tab that opens) to view and copy your live dashboard link.

---

## Engineering Trade-Offs & Troubleshooting Notes

### Using `psycopg2-binary` Instead of `psycopg2`

* **Why we did this:** Building `psycopg2` from source needs a C compiler (`cc`), which often fails on machines without build tools (`error: [Errno 2] No such file or directory: 'cc'`).

* **Takeaway:** `psycopg2-binary` installs quickly with `uv` and works smoothly with SQLAlchemy.

### Fixing `ROUND(double precision, integer)` in PostgreSQL

* **Why it happens:** PostgreSQL's two-argument `ROUND(value, digits)` expects a `numeric` value. Dividing a `DOUBLE PRECISION` column by a `BIGINT` column inside a `CASE` statement can stay `double precision` and throw `UndefinedFunction: function round(double precision, integer) does not exist`.

* **How we fixed it:** Cast expressions to `::numeric` before rounding, and use `NULL::numeric` in `WHEN ... THEN NULL::numeric` branches so both sides of `CASE` match.

### Keeping Granularities Separate

* **Why we did this:** `tableau_pli_sector_kpis.csv` (70 rows), `tableau_pli_ministry_summary.csv`, and `tableau_pli_yearly_trends.csv` (5 rows) represent different levels of aggregation.

* **Takeaway:** Keeping them separate avoids accidental row multiplication when summing totals in BI tools.

### Troubleshooting Tableau Public Links

* **If no link pops up after publishing:** Sign in at `public.tableau.com`, open your profile page, click the published workbook, and copy the URL from your browser address bar.

* **If the link shows an error or stays blank:** Open it in a fresh or incognito browser window, confirm your internet or VPN/ad-blocker isn't blocking the page, and republish via **Publish As...** if needed.