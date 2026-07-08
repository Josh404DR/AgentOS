"""
generate_mock_data.py
----------------------
Generates fully synthetic (mock) e-commerce data for the
Data Quality Audit Toolkit portfolio project.

IMPORTANT: All data below is randomly generated for demonstration
purposes only. No real company, customer, or transaction data is used.

Tables generated (written to data/raw/):
    - customers.csv
    - products.csv
    - inventory.csv
    - orders.csv
    - order_items.csv

The generator deliberately injects a controlled set of data quality
issues (missing values, duplicates, bad ID formats, price/quantity
outliers, date logic errors, referential integrity breaks, inventory
anomalies, and calculation mismatches) so that the downstream audit
scripts have realistic problems to detect. All injected issues are
seeded (SEED = 42) so the project is fully reproducible.
"""

import os
import random
import string
from datetime import datetime, timedelta

import numpy as np
import pandas as pd

SEED = 42
random.seed(SEED)
np.random.seed(SEED)

RAW_DIR = os.path.join(os.path.dirname(__file__), "..", "data", "raw")

N_CUSTOMERS = 200
N_PRODUCTS = 60
N_ORDERS = 500
WAREHOUSES = ["WH-A", "WH-B", "WH-C"]
CATEGORIES = ["Electronics", "Home & Kitchen", "Apparel", "Beauty", "Sports", "Toys", "Grocery"]
CITIES = ["Taipei", "Taichung", "Kaohsiung", "Tainan", "Hsinchu", "Taoyuan"]
STATUSES = ["completed", "shipped", "processing", "cancelled", "returned"]

FIRST_NAMES = ["Wei", "Ting", "Chen", "Hui", "Ming", "Yu", "Jia", "Hao", "Xin", "Rui",
               "Alex", "Sam", "Jordan", "Casey", "Taylor", "Morgan", "Riley", "Jamie"]
LAST_NAMES = ["Lin", "Wang", "Chang", "Chen", "Huang", "Wu", "Liu", "Kao", "Yang", "Hsu"]
PRODUCT_WORDS = ["Wireless", "Ergo", "Pro", "Mini", "Max", "Smart", "Classic", "Eco",
                  "Portable", "Deluxe", "Essential", "Ultra"]
PRODUCT_NOUNS = ["Mouse", "Keyboard", "Blender", "Jacket", "Serum", "Backpack", "Speaker",
                  "Lamp", "Bottle", "Mat", "Charger", "Headphones", "Chair", "Mug"]


def _rand_date(start: datetime, end: datetime) -> datetime:
    delta = end - start
    return start + timedelta(days=random.randint(0, delta.days))


def generate_customers(n=N_CUSTOMERS) -> pd.DataFrame:
    rows = []
    for i in range(1, n + 1):
        name = f"{random.choice(FIRST_NAMES)} {random.choice(LAST_NAMES)}"
        email = f"{name.lower().replace(' ', '.')}{i}@example-mail.com"
        rows.append({
            "customer_id": f"CUST-{i:05d}",
            "customer_name": name,
            "email": email,
            "city": random.choice(CITIES),
            "signup_date": _rand_date(datetime(2022, 1, 1), datetime(2026, 6, 1)).date().isoformat(),
        })

    df = pd.DataFrame(rows)

    # Inject: missing emails (~4%)
    missing_idx = df.sample(frac=0.04, random_state=SEED).index
    df.loc[missing_idx, "email"] = np.nan

    # Inject: missing city (~3%)
    missing_city_idx = df.sample(frac=0.03, random_state=SEED + 1).index
    df.loc[missing_city_idx, "city"] = np.nan

    # Inject: duplicate customer rows (~2%, exact duplicate customer_id with same data)
    dup_rows = df.sample(frac=0.02, random_state=SEED + 2)
    df = pd.concat([df, dup_rows], ignore_index=True)

    return df.sample(frac=1, random_state=SEED).reset_index(drop=True)


def generate_products(n=N_PRODUCTS) -> pd.DataFrame:
    rows = []
    for i in range(1, n + 1):
        cost = round(np.random.uniform(3, 200), 2)
        margin = np.random.uniform(1.2, 2.8)
        rows.append({
            "product_id": f"PRD-{i:04d}",
            "product_name": f"{random.choice(PRODUCT_WORDS)} {random.choice(PRODUCT_NOUNS)}",
            "category": random.choice(CATEGORIES),
            "unit_cost": cost,
            "unit_price": round(cost * margin, 2),
        })
    df = pd.DataFrame(rows)

    # Inject: missing category (~5%)
    missing_idx = df.sample(frac=0.05, random_state=SEED).index
    df.loc[missing_idx, "category"] = np.nan

    # Inject: malformed product_id format (~3%) e.g. lowercase / missing prefix
    bad_idx = df.sample(frac=0.03, random_state=SEED + 3).index
    df.loc[bad_idx, "product_id"] = df.loc[bad_idx, "product_id"].str.replace("PRD-", "prod_")

    # Inject: price anomalies (~4%) - zero/negative price or extreme outlier price
    price_anom_idx = df.sample(frac=0.04, random_state=SEED + 4).index
    for idx in price_anom_idx:
        choice = random.choice(["zero", "negative", "extreme"])
        if choice == "zero":
            df.loc[idx, "unit_price"] = 0
        elif choice == "negative":
            df.loc[idx, "unit_price"] = -round(random.uniform(5, 50), 2)
        else:
            df.loc[idx, "unit_price"] = round(df.loc[idx, "unit_price"] * random.uniform(20, 40), 2)

    return df


def generate_inventory(products: pd.DataFrame) -> pd.DataFrame:
    rows = []
    inv_id = 1
    for _, prod in products.iterrows():
        for wh in random.sample(WAREHOUSES, k=random.randint(1, len(WAREHOUSES))):
            rows.append({
                "inventory_id": f"INV-{inv_id:05d}",
                "product_id": prod["product_id"],
                "warehouse": wh,
                "stock_quantity": int(np.random.gamma(shape=2.0, scale=60)),
            })
            inv_id += 1
    df = pd.DataFrame(rows)

    # Inject: negative stock (~3%)
    neg_idx = df.sample(frac=0.03, random_state=SEED + 5).index
    df.loc[neg_idx, "stock_quantity"] = -abs(df.loc[neg_idx, "stock_quantity"]) - 1

    # Inject: extreme high stock outliers (~2%)
    high_idx = df.sample(frac=0.02, random_state=SEED + 6).index
    df.loc[high_idx, "stock_quantity"] = df.loc[high_idx, "stock_quantity"] * random.randint(50, 100)

    # Inject: missing stock_quantity (~2%)
    missing_idx = df.sample(frac=0.02, random_state=SEED + 7).index
    df.loc[missing_idx, "stock_quantity"] = np.nan

    return df


def generate_orders(customers: pd.DataFrame, n=N_ORDERS) -> pd.DataFrame:
    valid_customer_ids = customers["customer_id"].unique().tolist()
    rows = []
    for i in range(1, n + 1):
        order_date = _rand_date(datetime(2025, 1, 1), datetime(2026, 6, 30))
        ship_date = order_date + timedelta(days=random.randint(0, 10))
        rows.append({
            "order_id": f"ORD-{i:06d}",
            "customer_id": random.choice(valid_customer_ids),
            "order_date": order_date.date().isoformat(),
            "ship_date": ship_date.date().isoformat(),
            "status": random.choice(STATUSES),
        })
    df = pd.DataFrame(rows)

    # Inject: missing customer_id (~3%)
    missing_idx = df.sample(frac=0.03, random_state=SEED + 8).index
    df.loc[missing_idx, "customer_id"] = np.nan

    # Inject: customer_id referencing a non-existent customer (~3%)
    ghost_idx = df.sample(frac=0.03, random_state=SEED + 9).index
    df.loc[ghost_idx, "customer_id"] = [f"CUST-{90000 + j}" for j in range(len(ghost_idx))]

    # Inject: malformed order_id (~2%)
    bad_idx = df.sample(frac=0.02, random_state=SEED + 10).index
    df.loc[bad_idx, "order_id"] = df.loc[bad_idx, "order_id"].str.replace("ORD-", "order")

    # Inject: ship_date earlier than order_date (date logic error) (~4%)
    bad_date_idx = df.sample(frac=0.04, random_state=SEED + 11).index
    for idx in bad_date_idx:
        od = datetime.fromisoformat(df.loc[idx, "order_date"])
        df.loc[idx, "ship_date"] = (od - timedelta(days=random.randint(1, 7))).date().isoformat()

    # Inject: duplicate order rows (~2%)
    dup_rows = df.sample(frac=0.02, random_state=SEED + 12)
    df = pd.concat([df, dup_rows], ignore_index=True)

    return df.sample(frac=1, random_state=SEED).reset_index(drop=True)


def generate_order_items(orders: pd.DataFrame, products: pd.DataFrame) -> pd.DataFrame:
    valid_product_ids = products["product_id"].tolist()
    price_lookup = dict(zip(products["product_id"], products["unit_price"]))

    rows = []
    item_id = 1
    for _, order in orders.iterrows():
        n_items = random.randint(1, 4)
        for _ in range(n_items):
            product_id = random.choice(valid_product_ids)
            unit_price = price_lookup.get(product_id, round(random.uniform(5, 100), 2))
            quantity = random.randint(1, 8)
            rows.append({
                "order_item_id": f"OI-{item_id:07d}",
                "order_id": order["order_id"],
                "product_id": product_id,
                "quantity": quantity,
                "unit_price": unit_price,
                "item_total": round(quantity * unit_price, 2),
            })
            item_id += 1
    df = pd.DataFrame(rows)

    # Inject: product_id not present in products table (referential integrity break) (~3%)
    ghost_idx = df.sample(frac=0.03, random_state=SEED + 13).index
    df.loc[ghost_idx, "product_id"] = [f"PRD-{9000 + j}" for j in range(len(ghost_idx))]

    # Inject: quantity anomalies - zero/negative/extreme (~4%)
    qty_idx = df.sample(frac=0.04, random_state=SEED + 14).index
    for idx in qty_idx:
        choice = random.choice(["zero", "negative", "extreme"])
        if choice == "zero":
            df.loc[idx, "quantity"] = 0
        elif choice == "negative":
            df.loc[idx, "quantity"] = -random.randint(1, 5)
        else:
            df.loc[idx, "quantity"] = random.randint(500, 2000)

    # Inject: item_total mismatched with quantity * unit_price (~5%)
    calc_idx = df.sample(frac=0.05, random_state=SEED + 15).index
    df.loc[calc_idx, "item_total"] = (
        df.loc[calc_idx, "quantity"] * df.loc[calc_idx, "unit_price"] + np.random.uniform(5, 50, len(calc_idx))
    ).round(2)

    # Inject: missing unit_price (~2%)
    missing_idx = df.sample(frac=0.02, random_state=SEED + 16).index
    df.loc[missing_idx, "unit_price"] = np.nan

    # Inject: duplicate order_item rows (~2%)
    dup_rows = df.sample(frac=0.02, random_state=SEED + 17)
    df = pd.concat([df, dup_rows], ignore_index=True)

    return df.sample(frac=1, random_state=SEED).reset_index(drop=True)


def main():
    os.makedirs(RAW_DIR, exist_ok=True)

    customers = generate_customers()
    products = generate_products()
    inventory = generate_inventory(products)
    orders = generate_orders(customers)
    order_items = generate_order_items(orders, products)

    customers.to_csv(os.path.join(RAW_DIR, "customers.csv"), index=False)
    products.to_csv(os.path.join(RAW_DIR, "products.csv"), index=False)
    inventory.to_csv(os.path.join(RAW_DIR, "inventory.csv"), index=False)
    orders.to_csv(os.path.join(RAW_DIR, "orders.csv"), index=False)
    order_items.to_csv(os.path.join(RAW_DIR, "order_items.csv"), index=False)

    print("Mock data generated (all synthetic, no real company data):")
    print(f"  customers.csv    : {len(customers)} rows")
    print(f"  products.csv     : {len(products)} rows")
    print(f"  inventory.csv    : {len(inventory)} rows")
    print(f"  orders.csv       : {len(orders)} rows")
    print(f"  order_items.csv  : {len(order_items)} rows")


if __name__ == "__main__":
    main()
