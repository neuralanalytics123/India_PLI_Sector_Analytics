CREATE SCHEMA IF NOT EXISTS raw;
CREATE SCHEMA IF NOT EXISTS analytics;

CREATE TABLE IF NOT EXISTS raw.pli_sectors (
    fiscal_year TEXT NOT NULL,
    as_of_date DATE NOT NULL,
    ministry TEXT NOT NULL,
    sector TEXT NOT NULL,
    cumulative_investment_cr DOUBLE PRECISION NOT NULL,
    cumulative_exports_cr DOUBLE PRECISION NOT NULL,
    cumulative_employment BIGINT NOT NULL,
    investment_share_pct DOUBLE PRECISION NOT NULL,
    investment_per_job_cr DOUBLE PRECISION NOT NULL,
    exports_growth_pct DOUBLE PRECISION NOT NULL,
    data_basis TEXT NOT NULL,
    CONSTRAINT pk_pli_sectors PRIMARY KEY (fiscal_year, sector)
);
