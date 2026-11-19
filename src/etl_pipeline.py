import os
from pathlib import Path
import pandas as pd
from dotenv import load_dotenv
from sqlalchemy import create_engine, text

load_dotenv()

BASE_DIR = Path(__file__).resolve().parent.parent
RAW_CSV_PATH = (
    BASE_DIR / "data" / "raw" / "india_pli_all_14_sectors_2022_2026.csv"
)
PROCESSED_DIR = BASE_DIR / "data" / "processed"
PROCESSED_DIR.mkdir(parents=True, exist_ok=True)


def get_db_url() -> str:
    db_url = os.getenv("DATABASE_URL")
    if db_url:
        return db_url
    host = os.getenv("POSTGRES_HOST", "localhost")
    port = os.getenv("POSTGRES_PORT", "5432")
    db = os.getenv("POSTGRES_DB", "omniretail")
    user = os.getenv("POSTGRES_USER", "postgres")
    password = os.getenv("POSTGRES_PASSWORD", "")
    return f"postgresql+psycopg2://{user}:{password}@{host}:{port}/{db}"


def load_and_clean_csv(path: Path) -> pd.DataFrame:
    df = pd.read_csv(path)

    text_cols = ["fiscal_year", "ministry", "sector", "data_basis"]
    for col in text_cols:
        df[col] = df[col].astype(str).str.strip()

    df["as_of_date"] = pd.to_datetime(df["as_of_date"]).dt.date

    numeric_float_cols = [
        "cumulative_investment_cr",
        "cumulative_exports_cr",
        "investment_share_pct",
        "investment_per_job_cr",
        "exports_growth_pct",
    ]
    for col in numeric_float_cols:
        df[col] = pd.to_numeric(df[col], errors="coerce").round(4)

    df["cumulative_employment"] = (
        pd.to_numeric(df["cumulative_employment"], errors="coerce")
        .fillna(0)
        .astype("int64")
    )

    if df.isna().sum().sum() > 0:
        raise ValueError("Found unexpected null values after cleaning CSV.")

    return df


def run_sql_file(engine, sql_path: Path) -> None:
    sql_text = sql_path.read_text(encoding="utf-8")
    with engine.begin() as conn:
        conn.execute(text(sql_text))


def main() -> None:
    df = load_and_clean_csv(RAW_CSV_PATH)
    engine = create_engine(get_db_url())

    run_sql_file(engine, BASE_DIR / "sql" / "01_schema.sql")

    with engine.begin() as conn:
        conn.execute(text("TRUNCATE TABLE raw.pli_sectors;"))

    df.to_sql(
        name="pli_sectors",
        con=engine,
        schema="raw",
        if_exists="append",
        index=False,
    )

    run_sql_file(engine, BASE_DIR / "sql" / "02_analytics_views.sql")

    sector_kpis = pd.read_sql(
        "SELECT * FROM analytics.v_pli_sector_kpis;", engine
    )
    ministry_summary = pd.read_sql(
        "SELECT * FROM analytics.v_pli_ministry_summary;", engine
    )
    yearly_trends = pd.read_sql(
        "SELECT * FROM analytics.v_pli_yearly_trends;", engine
    )

    sector_kpis.to_csv(
        PROCESSED_DIR / "tableau_pli_sector_kpis.csv", index=False
    )
    ministry_summary.to_csv(
        PROCESSED_DIR / "tableau_pli_ministry_summary.csv", index=False
    )
    yearly_trends.to_csv(
        PROCESSED_DIR / "tableau_pli_yearly_trends.csv", index=False
    )

    print(f"Loaded {len(df)} rows into raw.pli_sectors")
    print("Exported processed CSVs to data/processed/:")
    print(" - tableau_pli_sector_kpis.csv")
    print(" - tableau_pli_ministry_summary.csv")
    print(" - tableau_pli_yearly_trends.csv")


if __name__ == "__main__":
    main()
