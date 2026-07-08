"""Run the complete local e-commerce operations pipeline."""

from __future__ import annotations

import argparse
import time

import extract_data
import generate_mock_data
import generate_report
import transform_data
import validate_data


def main() -> None:
    parser = argparse.ArgumentParser(description="Run the synthetic operations pipeline.")
    parser.add_argument("--skip-generate", action="store_true", help="Reuse existing raw CSV files.")
    args = parser.parse_args()
    started = time.perf_counter()

    stages = []
    if not args.skip_generate:
        stages.append(("generate_mock_data", generate_mock_data.run))
    stages.extend(
        [
            ("extract", extract_data.run),
            ("transform", transform_data.run),
            ("validate", validate_data.run),
            ("generate_report", generate_report.run),
        ]
    )
    for stage_name, stage in stages:
        stage_started = time.perf_counter()
        stage()
        print(f"stage={stage_name} duration_seconds={time.perf_counter() - stage_started:.2f}")
    print(f"pipeline_status=completed duration_seconds={time.perf_counter() - started:.2f}")


if __name__ == "__main__":
    main()
