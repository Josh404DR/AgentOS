"""
data_quality_checks.py
----------------------
Core data quality audit logic for the Data Quality Audit Toolkit.

Implements the following checks across the mock e-commerce tables
(customers, products, inventory, orders, order_items):

    1. Missing value check
    2. Duplicate record check
    3. ID format check (product_id / order_id)
    4. Price anomaly check
    5. Quantity anomaly check
    6. Date logic check (ship_date < order_date)
    7. Referential integrity check (order_items -> products, orders -> customers)
    8. Inventory anomaly check (negative / extreme stock)
    9. Sales amount calculation check (quantity * unit_price == item_total)

Each check returns a list of "issue records" with a consistent schema so
they can be combined into a single issue log and scored consistently:

    {
        "issue_type": str,
        "dimension": str,       # Completeness | Uniqueness | Validity | Consistency
        "affected_table": str,
        "affected_column": str,
        "number_of_records": int,
        "sample_ids": str,      # comma separated sample of affected keys
        "business_risk": str,
        "suggested_fix": str,
    }

The module also computes a Data Quality Score per table and overall,
across four dimensions: Completeness, Uniqueness, Validity, Consistency.
"""

import os
import re

import numpy as np
import pandas as pd

RAW_DIR = os.path.join(os.path.dirname(__file__), "..", "data", "raw")

ID_PATTERNS = {
    "product_id": re.compile(r"^PRD-\d{4}$"),
    "order_id": re.compile(r"^ORD-\d{6}$"),
    "customer_id": re.compile(r"^CUST-\d{5}$"),
}

MAX_SAMPLE_IDS = 5

PRIMARY_KEY = {
    "customers": "customer_id",
    "products": "product_id",
    "orders": "order_id",
    "order_items": "order_item_id",
    "inventory": "inventory_id",
}


def load_tables(raw_dir: str = RAW_DIR) -> dict:
    tables = {}
    for name in ["customers", "products", "inventory", "orders", "order_items"]:
        path = os.path.join(raw_dir, f"{name}.csv")
        tables[name] = pd.read_csv(path)
    return tables


def _sample(series: pd.Series) -> str:
    vals = series.astype(str).dropna().unique().tolist()[:MAX_SAMPLE_IDS]
    return ", ".join(vals) if vals else "(no key column)"


def _issue(issue_type, dimension, table, column, n, sample_ids, risk, fix):
    return {
        "issue_type": issue_type,
        "dimension": dimension,
        "affected_table": table,
        "affected_column": column,
        "number_of_records": int(n),
        "sample_ids": sample_ids,
        "business_risk": risk,
        "suggested_fix": fix,
    }


# ---------------------------------------------------------------------------
# 1. Missing value check
# ---------------------------------------------------------------------------
def check_missing_values(tables: dict) -> list:
    issues = []
    for table_name, df in tables.items():
        key_col = PRIMARY_KEY.get(table_name)
        for col in df.columns:
            n_missing = int(df[col].isna().sum())
            if n_missing == 0:
                continue
            affected = df[df[col].isna()]
            issues.append(_issue(
                issue_type=f"Missing values in '{col}'",
                dimension="Completeness",
                table=table_name,
                column=col,
                n=n_missing,
                sample_ids=_sample(affected[key_col]) if key_col else "n/a",
                risk=_missing_value_risk(table_name, col),
                fix=f"Backfill '{col}' from source system or require it at data-entry time; "
                    f"add a NOT NULL / required-field validation upstream.",
            ))
    return issues


def _missing_value_risk(table_name: str, col: str) -> str:
    risk_map = {
        ("customers", "email"): "Cannot run CRM/email marketing campaigns or verify customer identity.",
        ("customers", "city"): "Regional sales dashboards will undercount or misclassify customers.",
        ("products", "category"): "Category-level revenue dashboards will be incomplete or misleading.",
        ("orders", "customer_id"): "Order cannot be attributed to a customer, breaking CLV/repeat-purchase analysis.",
        ("order_items", "unit_price"): "Revenue and margin calculations for affected line items are unreliable.",
        ("inventory", "stock_quantity"): "Inventory dashboards and reorder alerts cannot evaluate this row.",
    }
    return risk_map.get((table_name, col),
                         f"Downstream reports using '{table_name}.{col}' may silently drop or misstate these records.")


# ---------------------------------------------------------------------------
# 2. Duplicate record check
# ---------------------------------------------------------------------------
def check_duplicates(tables: dict) -> list:
    issues = []
    key_columns = {
        "customers": "customer_id",
        "products": "product_id",
        "orders": "order_id",
        "order_items": "order_item_id",
        "inventory": "inventory_id",
    }
    for table_name, df in tables.items():
        key = key_columns.get(table_name)
        if not key or key not in df.columns:
            continue
        dup_mask = df.duplicated(subset=[key], keep=False)
        n_dup = int(dup_mask.sum())
        if n_dup == 0:
            continue
        issues.append(_issue(
            issue_type=f"Duplicate records on '{key}'",
            dimension="Uniqueness",
            table=table_name,
            column=key,
            n=n_dup,
            sample_ids=_sample(df.loc[dup_mask, key]),
            risk=f"Double-counts records in {table_name}-based reports (e.g. revenue, order volume, customer counts) "
                 f"and can inflate KPIs presented to stakeholders.",
            fix=f"De-duplicate on '{key}' keeping the most recent/authoritative record; "
                f"add a unique constraint at the database level.",
        ))
    return issues


# ---------------------------------------------------------------------------
# 3. ID format check
# ---------------------------------------------------------------------------
def check_id_format(tables: dict) -> list:
    issues = []
    format_targets = [
        ("products", "product_id"),
        ("orders", "order_id"),
        ("customers", "customer_id"),
    ]
    for table_name, col in format_targets:
        df = tables[table_name]
        pattern = ID_PATTERNS[col]
        valid_mask = df[col].astype(str).str.match(pattern)
        invalid_mask = ~valid_mask | df[col].isna()
        n_invalid = int(invalid_mask.sum())
        if n_invalid == 0:
            continue
        issues.append(_issue(
            issue_type=f"Invalid '{col}' format",
            dimension="Validity",
            table=table_name,
            column=col,
            n=n_invalid,
            sample_ids=_sample(df.loc[invalid_mask, col]),
            risk=f"Malformed '{col}' values will fail joins/lookups against other tables, "
                 f"silently dropping records from cross-table reports (e.g. dashboards, SQL joins).",
            fix=f"Standardize '{col}' to the canonical format via a validation rule at ingestion; "
                f"reject or quarantine records that do not match the expected pattern.",
        ))
    return issues


# ---------------------------------------------------------------------------
# 4. Price anomaly check
# ---------------------------------------------------------------------------
def check_price_anomaly(tables: dict) -> list:
    issues = []
    df = tables["products"]
    prices = df["unit_price"]

    non_positive_mask = prices <= 0
    n_non_positive = int(non_positive_mask.sum())
    if n_non_positive:
        issues.append(_issue(
            issue_type="Zero or negative unit_price",
            dimension="Validity",
            table="products",
            column="unit_price",
            n=n_non_positive,
            sample_ids=_sample(df.loc[non_positive_mask, "product_id"]),
            risk="Products would be sold for free or at a negative margin; directly corrupts revenue and margin reporting.",
            fix="Enforce unit_price > 0 at data entry; route flagged SKUs to merchandising for price correction.",
        ))

    valid_prices = prices[prices > 0]
    q1, q3 = valid_prices.quantile(0.25), valid_prices.quantile(0.75)
    iqr = q3 - q1
    upper_bound = q3 + 3 * iqr
    extreme_mask = prices > upper_bound
    n_extreme = int(extreme_mask.sum())
    if n_extreme:
        issues.append(_issue(
            issue_type="Extreme price outlier (> Q3 + 3*IQR)",
            dimension="Validity",
            table="products",
            column="unit_price",
            n=n_extreme,
            sample_ids=_sample(df.loc[extreme_mask, "product_id"]),
            risk="Likely a data entry or unit error (e.g. cents vs. dollars); can distort average order value and revenue KPIs.",
            fix="Flag for manual pricing review; compare against unit_cost and category peers before publishing to dashboards.",
        ))
    return issues


# ---------------------------------------------------------------------------
# 5. Quantity anomaly check
# ---------------------------------------------------------------------------
def check_quantity_anomaly(tables: dict) -> list:
    issues = []
    df = tables["order_items"]
    qty = df["quantity"]

    non_positive_mask = qty <= 0
    n_non_positive = int(non_positive_mask.sum())
    if n_non_positive:
        issues.append(_issue(
            issue_type="Zero or negative quantity",
            dimension="Validity",
            table="order_items",
            column="quantity",
            n=n_non_positive,
            sample_ids=_sample(df.loc[non_positive_mask, "order_item_id"]),
            risk="Units-sold and revenue calculations are invalid for these line items; may indicate failed order cancellations.",
            fix="Reject non-positive quantities at checkout/order-entry; reconcile with order status (e.g. cancelled/returned).",
        ))

    valid_qty = qty[qty > 0]
    q1, q3 = valid_qty.quantile(0.25), valid_qty.quantile(0.75)
    iqr = q3 - q1
    upper_bound = q3 + 3 * iqr
    extreme_mask = qty > upper_bound
    n_extreme = int(extreme_mask.sum())
    if n_extreme:
        issues.append(_issue(
            issue_type="Extreme quantity outlier (> Q3 + 3*IQR)",
            dimension="Validity",
            table="order_items",
            column="quantity",
            n=n_extreme,
            sample_ids=_sample(df.loc[extreme_mask, "order_item_id"]),
            risk="Possible bulk-order data entry error or bot/fraud activity; can distort demand forecasting and inventory planning.",
            fix="Flag for manual review against customer order history; cap or confirm with sales ops before fulfillment.",
        ))
    return issues


# ---------------------------------------------------------------------------
# 6. Date logic check
# ---------------------------------------------------------------------------
def check_date_logic(tables: dict) -> list:
    issues = []
    df = tables["orders"].copy()
    df["order_date_parsed"] = pd.to_datetime(df["order_date"], errors="coerce")
    df["ship_date_parsed"] = pd.to_datetime(df["ship_date"], errors="coerce")

    bad_mask = df["ship_date_parsed"] < df["order_date_parsed"]
    n_bad = int(bad_mask.sum())
    if n_bad:
        issues.append(_issue(
            issue_type="ship_date earlier than order_date",
            dimension="Consistency",
            table="orders",
            column="ship_date / order_date",
            n=n_bad,
            sample_ids=_sample(df.loc[bad_mask, "order_id"]),
            risk="Logically impossible fulfillment timeline; breaks shipping SLA / lead-time analysis and customer-facing tracking.",
            fix="Add a cross-field validation rule (ship_date >= order_date) at order-management-system ingestion.",
        ))
    return issues


# ---------------------------------------------------------------------------
# 7. Referential integrity check
# ---------------------------------------------------------------------------
def check_referential_integrity(tables: dict) -> list:
    issues = []

    order_items = tables["order_items"]
    products = tables["products"]
    valid_product_ids = set(products["product_id"].dropna())
    orphan_mask = ~order_items["product_id"].isin(valid_product_ids)
    n_orphan = int(orphan_mask.sum())
    if n_orphan:
        issues.append(_issue(
            issue_type="order_items.product_id not found in products",
            dimension="Consistency",
            table="order_items",
            column="product_id",
            n=n_orphan,
            sample_ids=_sample(order_items.loc[orphan_mask, "order_item_id"]),
            risk="Line items cannot be joined to product master data (name/category/price); product-level sales reports undercount revenue.",
            fix="Investigate deleted/renamed SKUs in the product master; backfill or reconcile product_id mapping before reporting.",
        ))

    orders = tables["orders"]
    customers = tables["customers"]
    valid_customer_ids = set(customers["customer_id"].dropna())
    orphan_cust_mask = ~orders["customer_id"].isin(valid_customer_ids)
    n_orphan_cust = int(orphan_cust_mask.sum())
    if n_orphan_cust:
        issues.append(_issue(
            issue_type="orders.customer_id not found in customers",
            dimension="Consistency",
            table="orders",
            column="customer_id",
            n=n_orphan_cust,
            sample_ids=_sample(orders.loc[orphan_cust_mask, "order_id"]),
            risk="Orders cannot be attributed to a known customer; breaks customer lifetime value and retention analysis.",
            fix="Validate customer_id against the customer master at order creation; quarantine orders with unresolved customer references.",
        ))

    return issues


# ---------------------------------------------------------------------------
# 8. Inventory anomaly check
# ---------------------------------------------------------------------------
def check_inventory_anomaly(tables: dict) -> list:
    issues = []
    df = tables["inventory"]
    stock = df["stock_quantity"]

    neg_mask = stock < 0
    n_neg = int(neg_mask.sum())
    if n_neg:
        issues.append(_issue(
            issue_type="Negative stock_quantity",
            dimension="Validity",
            table="inventory",
            column="stock_quantity",
            n=n_neg,
            sample_ids=_sample(df.loc[neg_mask, "inventory_id"]),
            risk="Physically impossible; usually caused by unreconciled returns/shipments and leads to false stockout or overselling risk.",
            fix="Reconcile with warehouse management system transaction log; enforce stock_quantity >= 0 constraint.",
        ))

    valid_stock = stock[stock.notna() & (stock >= 0)]
    q1, q3 = valid_stock.quantile(0.25), valid_stock.quantile(0.75)
    iqr = q3 - q1
    upper_bound = q3 + 3 * iqr
    extreme_mask = stock > upper_bound
    n_extreme = int(extreme_mask.sum())
    if n_extreme:
        issues.append(_issue(
            issue_type="Extreme high stock_quantity outlier (> Q3 + 3*IQR)",
            dimension="Validity",
            table="inventory",
            column="stock_quantity",
            n=n_extreme,
            sample_ids=_sample(df.loc[extreme_mask, "inventory_id"]),
            risk="Possible duplicate receiving entry or unit-of-measure error; ties up working-capital reporting and reorder-point logic.",
            fix="Cross-check against purchase orders and warehouse receiving records before trusting for reorder automation.",
        ))
    return issues


# ---------------------------------------------------------------------------
# 9. Sales amount calculation check
# ---------------------------------------------------------------------------
def check_amount_calculation(tables: dict) -> list:
    issues = []
    df = tables["order_items"].copy()
    expected = (df["quantity"] * df["unit_price"]).round(2)
    diff = (df["item_total"] - expected).abs()
    bad_mask = diff > 0.01
    bad_mask = bad_mask.fillna(False)
    n_bad = int(bad_mask.sum())
    if n_bad:
        issues.append(_issue(
            issue_type="item_total != quantity * unit_price",
            dimension="Consistency",
            table="order_items",
            column="item_total",
            n=n_bad,
            sample_ids=_sample(df.loc[bad_mask, "order_item_id"]),
            risk="Revenue reported at the line-item level does not reconcile with unit economics; directly misstates sales dashboards and financial reporting.",
            fix="Recompute item_total from quantity * unit_price at the source system; add a calculated-field validation before it reaches reporting.",
        ))
    return issues


# ---------------------------------------------------------------------------
# Orchestration
# ---------------------------------------------------------------------------
def run_all_checks(tables: dict) -> pd.DataFrame:
    all_issues = []
    all_issues += check_missing_values(tables)
    all_issues += check_duplicates(tables)
    all_issues += check_id_format(tables)
    all_issues += check_price_anomaly(tables)
    all_issues += check_quantity_anomaly(tables)
    all_issues += check_date_logic(tables)
    all_issues += check_referential_integrity(tables)
    all_issues += check_inventory_anomaly(tables)
    all_issues += check_amount_calculation(tables)

    issues_df = pd.DataFrame(all_issues)
    if not issues_df.empty:
        issues_df.insert(0, "issue_id", [f"ISS-{i+1:03d}" for i in range(len(issues_df))])
        issues_df = issues_df.sort_values(
            by="number_of_records", ascending=False
        ).reset_index(drop=True)
        issues_df["issue_id"] = [f"ISS-{i+1:03d}" for i in range(len(issues_df))]
    return issues_df


# ---------------------------------------------------------------------------
# Scoring
# ---------------------------------------------------------------------------
def compute_scores(tables: dict, issues_df: pd.DataFrame) -> pd.DataFrame:
    """
    Computes a 0-100 Data Quality Score per table across four dimensions:
    Completeness, Uniqueness, Validity, Consistency, plus an Overall score
    (simple average of the four dimensions), and a final ALL-TABLES summary row.
    """
    dimensions = ["Completeness", "Uniqueness", "Validity", "Consistency"]
    rows = []

    for table_name, df in tables.items():
        n_rows = len(df)
        n_cells = df.shape[0] * df.shape[1]
        table_issues = issues_df[issues_df["affected_table"] == table_name] if not issues_df.empty else pd.DataFrame()

        # Completeness: 1 - (missing cells / total cells)
        n_missing_cells = int(df.isna().sum().sum())
        completeness = 1 - (n_missing_cells / n_cells) if n_cells else 1.0

        # Uniqueness: 1 - (duplicate-flagged records / total records)
        dup_issue_records = table_issues[table_issues["dimension"] == "Uniqueness"]["number_of_records"].sum()
        uniqueness = 1 - (dup_issue_records / n_rows) if n_rows else 1.0

        # Validity: 1 - (validity-flagged records / total records)
        # (a record can be flagged by more than one validity rule; clip at total rows)
        validity_issue_records = table_issues[table_issues["dimension"] == "Validity"]["number_of_records"].sum()
        validity = 1 - (min(validity_issue_records, n_rows) / n_rows) if n_rows else 1.0

        # Consistency: 1 - (consistency-flagged records / total records)
        consistency_issue_records = table_issues[table_issues["dimension"] == "Consistency"]["number_of_records"].sum()
        consistency = 1 - (min(consistency_issue_records, n_rows) / n_rows) if n_rows else 1.0

        scores = {
            "Completeness": max(0.0, completeness),
            "Uniqueness": max(0.0, uniqueness),
            "Validity": max(0.0, validity),
            "Consistency": max(0.0, consistency),
        }
        overall = float(np.mean(list(scores.values())))

        rows.append({
            "table": table_name,
            "row_count": n_rows,
            "completeness_score": round(scores["Completeness"] * 100, 1),
            "uniqueness_score": round(scores["Uniqueness"] * 100, 1),
            "validity_score": round(scores["Validity"] * 100, 1),
            "consistency_score": round(scores["Consistency"] * 100, 1),
            "overall_score": round(overall * 100, 1),
        })

    scores_df = pd.DataFrame(rows)

    overall_row = {
        "table": "ALL_TABLES",
        "row_count": int(scores_df["row_count"].sum()),
        "completeness_score": round(scores_df["completeness_score"].mean(), 1),
        "uniqueness_score": round(scores_df["uniqueness_score"].mean(), 1),
        "validity_score": round(scores_df["validity_score"].mean(), 1),
        "consistency_score": round(scores_df["consistency_score"].mean(), 1),
        "overall_score": round(scores_df["overall_score"].mean(), 1),
    }
    scores_df = pd.concat([scores_df, pd.DataFrame([overall_row])], ignore_index=True)

    return scores_df


def save_processed_snapshot(tables: dict, issues_df: pd.DataFrame, processed_dir: str):
    """
    Writes a lightweight 'flagged' copy of each table to data/processed/,
    tagging rows that were caught by at least one quality check.
    This demonstrates the analyst step of turning a raw + audited dataset
    into a review-ready processed dataset (not a full cleaning/imputation step).
    """
    os.makedirs(processed_dir, exist_ok=True)
    key_columns = {
        "customers": "customer_id",
        "products": "product_id",
        "orders": "order_id",
        "order_items": "order_item_id",
        "inventory": "inventory_id",
    }
    for table_name, df in tables.items():
        out = df.copy()
        key = key_columns.get(table_name)
        flagged_ids = set()
        if key and not issues_df.empty:
            table_issues = issues_df[issues_df["affected_table"] == table_name]
            for sample_str in table_issues["sample_ids"]:
                flagged_ids.update([s.strip() for s in str(sample_str).split(",")])
        if key and key in out.columns:
            out["quality_flag"] = out[key].astype(str).isin(flagged_ids)
        out.to_csv(os.path.join(processed_dir, f"{table_name}_flagged_sample.csv"), index=False)
