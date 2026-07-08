"""Illustrative Airflow DAG; no external connections are required."""

from __future__ import annotations

from datetime import datetime, timedelta
from pathlib import Path

from airflow import DAG
from airflow.operators.bash import BashOperator


PROJECT_ROOT = Path(__file__).resolve().parents[1]
PYTHON = "python"

default_args = {
    "owner": "data-operations",
    "depends_on_past": False,
    "retries": 1,
    "retry_delay": timedelta(minutes=5),
}

with DAG(
    dag_id="ecommerce_operations_daily_pipeline",
    description="Daily synthetic e-commerce operations ETL and reporting example.",
    default_args=default_args,
    start_date=datetime(2025, 1, 1),
    schedule="0 7 * * *",
    catchup=False,
    max_active_runs=1,
    tags=["portfolio", "ecommerce", "operations"],
) as dag:
    extract = BashOperator(
        task_id="extract",
        bash_command=f'cd "{PROJECT_ROOT}" && {PYTHON} src/extract_data.py',
    )
    transform = BashOperator(
        task_id="transform",
        bash_command=f'cd "{PROJECT_ROOT}" && {PYTHON} src/transform_data.py',
    )
    validate = BashOperator(
        task_id="validate",
        bash_command=f'cd "{PROJECT_ROOT}" && {PYTHON} src/validate_data.py',
    )
    generate_report = BashOperator(
        task_id="generate_report",
        bash_command=f'cd "{PROJECT_ROOT}" && {PYTHON} src/generate_report.py',
    )

    extract >> transform >> validate >> generate_report
