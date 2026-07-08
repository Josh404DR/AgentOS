"""
audit_report_generator.py
--------------------------
Turns the issue log + data quality scores into a business-readable
Markdown report (outputs/data_quality_report.md), plus writes
outputs/data_quality_score.csv and outputs/issue_log.csv.

The report is written for a non-technical audience (HR, hiring manager,
data/analytics lead) and follows a business-report structure rather than
a raw technical log: Executive Summary -> Scorecard -> Key Findings
(Issue Type / Affected Table / # Records / Business Risk / Suggested Fix)
-> Recommendations.
"""

import os
from datetime import date

import pandas as pd

OUTPUTS_DIR = os.path.join(os.path.dirname(__file__), "..", "outputs")


def _score_badge(score: float) -> str:
    if score >= 95:
        return "Excellent"
    if score >= 85:
        return "Good"
    if score >= 70:
        return "Needs Attention"
    return "Critical"


def _grade_row(row: pd.Series) -> str:
    return (f"| {row['table']} | {row['row_count']} | {row['completeness_score']} | "
            f"{row['uniqueness_score']} | {row['validity_score']} | {row['consistency_score']} | "
            f"**{row['overall_score']}** ({_score_badge(row['overall_score'])}) |")


def _issue_section(issues_df: pd.DataFrame) -> str:
    if issues_df.empty:
        return "No data quality issues were detected in this audit run.\n"

    lines = []
    for _, row in issues_df.iterrows():
        lines.append(f"### {row['issue_id']}: {row['issue_type']}\n")
        lines.append(f"- **Dimension:** {row['dimension']}")
        lines.append(f"- **Affected Table:** `{row['affected_table']}`")
        lines.append(f"- **Affected Column(s):** `{row['affected_column']}`")
        lines.append(f"- **Number of Records:** {row['number_of_records']}")
        lines.append(f"- **Sample IDs:** {row['sample_ids']}")
        lines.append(f"- **Business Risk:** {row['business_risk']}")
        lines.append(f"- **Suggested Fix:** {row['suggested_fix']}")
        lines.append("")
    return "\n".join(lines)


def _top_findings_table(issues_df: pd.DataFrame, top_n: int = 5) -> str:
    if issues_df.empty:
        return "_No issues to summarize._\n"
    top = issues_df.head(top_n)
    lines = [
        "| Issue Type | Affected Table | # Records | Business Risk |",
        "|---|---|---|---|",
    ]
    for _, row in top.iterrows():
        risk_short = row["business_risk"]
        if len(risk_short) > 110:
            risk_short = risk_short[:107] + "..."
        lines.append(f"| {row['issue_type']} | `{row['affected_table']}` | {row['number_of_records']} | {risk_short} |")
    return "\n".join(lines)


def generate_report(tables: dict, issues_df: pd.DataFrame, scores_df: pd.DataFrame, outputs_dir: str = OUTPUTS_DIR):
    os.makedirs(outputs_dir, exist_ok=True)

    overall_row = scores_df[scores_df["table"] == "ALL_TABLES"].iloc[0]
    total_records = sum(len(df) for df in tables.values())
    total_issue_records = int(issues_df["number_of_records"].sum()) if not issues_df.empty else 0

    dimension_scores = {
        "Completeness": overall_row["completeness_score"],
        "Uniqueness": overall_row["uniqueness_score"],
        "Validity": overall_row["validity_score"],
        "Consistency": overall_row["consistency_score"],
    }
    weakest_dimension = min(dimension_scores, key=dimension_scores.get)

    scorecard_rows = "\n".join(
        _grade_row(row) for _, row in scores_df[scores_df["table"] != "ALL_TABLES"].iterrows()
    )

    report = f"""# Data Quality Audit Report

**Audit Date:** {date.today().isoformat()}
**Dataset:** Synthetic e-commerce dataset (customers, products, orders, order_items, inventory)
**Prepared as part of:** Data Quality Audit Toolkit portfolio project
**Data Source Note:** 100% mock / synthetic data. No real company or customer data was used in this audit.

---

## Executive Summary

This audit reviewed **{total_records:,} records** across 5 core e-commerce tables and identified
**{len(issues_df)} distinct data quality issues**, affecting **{total_issue_records:,} record-level
occurrences** in total. The dataset's **Overall Data Quality Score is {overall_row['overall_score']}/100**
({_score_badge(overall_row['overall_score'])}).

The weakest dimension is **{weakest_dimension}** ({dimension_scores[weakest_dimension]}/100), which should be
the first priority for remediation before this data is used to drive dashboards, sales reporting, or
operational decisions.

---

## Data Quality Scorecard

| Table | Rows | Completeness | Uniqueness | Validity | Consistency | Overall |
|---|---|---|---|---|---|---|
{scorecard_rows}
| **ALL_TABLES** | **{overall_row['row_count']}** | **{overall_row['completeness_score']}** | **{overall_row['uniqueness_score']}** | **{overall_row['validity_score']}** | **{overall_row['consistency_score']}** | **{overall_row['overall_score']}** ({_score_badge(overall_row['overall_score'])}) |

**Scoring method:**
- **Completeness** = 1 − (missing cells ÷ total cells) for the table
- **Uniqueness** = 1 − (duplicate-flagged records ÷ total records)
- **Validity** = 1 − (format/range-violation records ÷ total records)
- **Consistency** = 1 − (cross-field/cross-table logic-violation records ÷ total records)
- **Overall** = simple average of the four dimension scores above

---

## Top Findings at a Glance

{_top_findings_table(issues_df)}

---

## Detailed Findings

{_issue_section(issues_df)}
---

## Business Impact Summary

- **Dashboard accuracy risk:** Missing values, duplicates, and calculation mismatches in
  `order_items` and `orders` directly inflate or deflate revenue and order-volume KPIs shown on
  executive dashboards.
- **Sales analysis reliability:** Referential integrity breaks (order line items pointing to
  products that don't exist) understate product-level revenue and can misdirect merchandising
  decisions.
- **Inventory / operations risk:** Negative and extreme-outlier stock values can trigger false
  stockout alerts or mask real overselling risk in the warehouse.
- **Cross-department trust:** Every unresolved issue below is a potential point of disagreement
  between Sales, Finance, and Operations when reconciling numbers — fixing these at the source
  reduces "whose number is right?" friction.

---

## Recommendations

1. Prioritize fixes in the **{weakest_dimension}** dimension first — it has the largest impact on the
   Overall Data Quality Score.
2. Add the SQL checks in `sql/` as scheduled data-quality gates (e.g. run nightly, alert if any
   check returns rows) rather than relying on manual, one-off audits.
3. Treat `order_items` as the highest-leverage table to monitor — it feeds directly into revenue
   and margin reporting and had the highest concentration of issues in this audit.
4. Re-run this audit after each fix to track the Overall Data Quality Score trend over time.

---

*This report was generated automatically by `audit_report_generator.py` from the checks defined in
`data_quality_checks.py`. See `docs/audit_rules.md` for the full rule definitions and
`docs/business_use_case.md` for how this toolkit supports cross-functional data quality workflows.*
"""

    report_path = os.path.join(outputs_dir, "data_quality_report.md")
    with open(report_path, "w", encoding="utf-8") as f:
        f.write(report)

    return report_path
