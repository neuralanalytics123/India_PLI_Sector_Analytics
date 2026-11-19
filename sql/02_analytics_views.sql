CREATE OR REPLACE VIEW analytics.v_pli_sector_kpis AS
SELECT
    fiscal_year,
    as_of_date,
    ministry,
    sector,
    cumulative_investment_cr,
    cumulative_exports_cr,
    cumulative_employment,
    investment_share_pct,
    ROUND(
        (
            cumulative_investment_cr
            / NULLIF(SUM(cumulative_investment_cr) OVER (PARTITION BY fiscal_year), 0)
            * 100
        )::numeric,
        2
    ) AS calculated_investment_share_pct,
    ROUND(
        (
            cumulative_exports_cr
            / NULLIF(SUM(cumulative_exports_cr) OVER (PARTITION BY fiscal_year), 0)
            * 100
        )::numeric,
        2
    ) AS export_share_pct,
    investment_per_job_cr,
    CASE
        WHEN cumulative_investment_cr = 0 THEN NULL::numeric
        ELSE ROUND(
            (cumulative_employment::numeric / cumulative_investment_cr::numeric),
            2
        )
    END AS jobs_per_cr_invested,
    exports_growth_pct,
    DENSE_RANK() OVER (
        PARTITION BY fiscal_year
        ORDER BY cumulative_investment_cr DESC
    ) AS investment_rank,
    DENSE_RANK() OVER (
        PARTITION BY fiscal_year
        ORDER BY cumulative_employment DESC
    ) AS employment_rank,
    data_basis
FROM raw.pli_sectors;

CREATE OR REPLACE VIEW analytics.v_pli_ministry_summary AS
SELECT
    fiscal_year,
    as_of_date,
    ministry,
    COUNT(*) AS sector_count,
    ROUND(SUM(cumulative_investment_cr)::numeric, 2) AS total_investment_cr,
    ROUND(
        (
            SUM(cumulative_investment_cr)
            / NULLIF(SUM(SUM(cumulative_investment_cr)) OVER (PARTITION BY fiscal_year), 0)
            * 100
        )::numeric,
        2
    ) AS ministry_investment_share_pct,
    ROUND(SUM(cumulative_exports_cr)::numeric, 2) AS total_exports_cr,
    SUM(cumulative_employment) AS total_employment,
    CASE
        WHEN SUM(cumulative_employment) = 0 THEN NULL::numeric
        ELSE ROUND(
            (
                SUM(cumulative_investment_cr)::numeric
                / SUM(cumulative_employment)::numeric
            ),
            4
        )
    END AS investment_cr_per_job
FROM raw.pli_sectors
GROUP BY fiscal_year, as_of_date, ministry
ORDER BY fiscal_year, total_investment_cr DESC;

CREATE OR REPLACE VIEW analytics.v_pli_yearly_trends AS
SELECT
    fiscal_year,
    as_of_date,
    COUNT(*) AS active_sectors,
    ROUND(SUM(cumulative_investment_cr)::numeric, 2) AS total_investment_cr,
    ROUND(SUM(cumulative_exports_cr)::numeric, 2) AS total_exports_cr,
    SUM(cumulative_employment) AS total_employment,
    CASE
        WHEN SUM(cumulative_employment) = 0 THEN NULL::numeric
        ELSE ROUND(
            (
                SUM(cumulative_investment_cr)::numeric
                / SUM(cumulative_employment)::numeric
            ),
            4
        )
    END AS investment_cr_per_job,
    ROUND(
        (
            (
                SUM(cumulative_exports_cr)
                - LAG(SUM(cumulative_exports_cr)) OVER (ORDER BY as_of_date)
            )
            / NULLIF(LAG(SUM(cumulative_exports_cr)) OVER (ORDER BY as_of_date), 0)
            * 100
        )::numeric,
        2
    ) AS yoy_exports_growth_pct
FROM raw.pli_sectors
GROUP BY fiscal_year, as_of_date
ORDER BY as_of_date;