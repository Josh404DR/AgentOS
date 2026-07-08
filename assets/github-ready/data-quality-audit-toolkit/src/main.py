"""
main.py
-------
Entry point for the Data Quality Audit Toolkit pipeline.

Steps:
    1. Generate mock (synthetic) e-commerce data -> data/raw/*.csv
    2. Run all data quality checks -> issue log + per-table scores
    3. Save a lightly-flagged snapshot -> data/processed/
    4. Write outputs:
        - outputs/issue_log.csv
        - outputs/data_quality_score.csv
        - outputs/data_quality_report.md

Usage:
    python src/main.py
    python src/main.py --skip-generate   # reuse existing data/raw files
"""

import argparse
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))

import generate_mock_data
import data_quality_checks as dqc
import audit_report_generator as report_gen

BASE_DIR = os.path.join(os.path.dirname(__file__), "..")
RAW_DIR = os.path.join(BASE_DIR, "data", "raw")
PROCESSED_DIR = os.path.join(BASE_DIR, "data", "processed")
OUTPUTS_DIR = os.path.join(BASE_DIR, "outputs")


def main():
    parser = argparse.ArgumentParser(description="Run the Data Quality Audit Toolkit pipeline.")
    parser.add_argument("--skip-generate", action="store_true",
                         help="Reuse existing data/raw/*.csv instead of regenerating mock data.")
    args = parser.parse_args()

    print("=" * 70)
    print("DATA QUALITY AUDIT TOOLKIT")
    print("=" * 70)

    if not args.skip_generate:
        print("\n[1/4] Generating synthetic mock data...")
        generate_mock_data.main()
    else:
        print("\n[1/4] Skipping generation, using existing data/raw/*.csv")

    print("\n[2/4] Loading tables and running data quality checks...")
    tables = dqc.load_tables(RAW_DIR)
    issues_df = dqc.run_all_checks(tables)
    scores_df = dqc.compute_scores(tables, issues_df)
    print(f"  -> {len(issues_df)} distinct issue types found")
    overall = scores_df[scores_df["table"] == "ALL_TABLES"].iloc[0]
    print(f"  -> Overall Data Quality Score: {overall['overall_score']}/100")

    print("\n[3/4] Saving flagged snapshot to data/processed/...")
    dqc.save_processed_snapshot(tables, issues_df, PROCESSED_DIR)

    print("\n[4/4] Writing outputs (issue log, score card, business report)...")
    os.makedirs(OUTPUTS_DIR, exist_ok=True)
    issues_df.to_csv(os.path.join(OUTPUTS_DIR, "issue_log.csv"), index=False)
    scores_df.to_csv(os.path.join(OUTPUTS_DIR, "data_quality_score.csv"), index=False)
    report_path = report_gen.generate_report(tables, issues_df, scores_df, OUTPUTS_DIR)

    print("\nDone. Outputs written to:")
    print(f"  - {os.path.join(OUTPUTS_DIR, 'issue_log.csv')}")
    print(f"  - {os.path.join(OUTPUTS_DIR, 'data_quality_score.csv')}")
    print(f"  - {report_path}")
    print("=" * 70)


if __name__ == "__main__":
    main()
