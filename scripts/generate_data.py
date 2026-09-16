#!/usr/bin/env python3
"""Generate deterministic, synthetic POC source data with no real customer data."""

from __future__ import annotations

import argparse
import csv
import random
from datetime import date, timedelta
from decimal import Decimal, ROUND_HALF_UP
from pathlib import Path

SEED = 130714
REGIONS = {
    "North America": ["US", "CA"],
    "Europe": ["DE", "FR", "GB", "NL"],
}
SEGMENTS = [
    ("SEG-ENT", "Enterprise", "Large strategic communications customers"),
    ("SEG-PS", "Public Safety", "Synthetic public-safety demonstration segment"),
    ("SEG-COM", "Commercial", "Mid-market commercial customers"),
    ("SEG-PCR", "Priority Communications", "Synthetic PCR demonstration segment"),
]
PRODUCTS = [
    ("P-100", "Apex Secure Radio", "Device", Decimal("825.00")),
    ("P-110", "Apex Vehicle Radio", "Device", Decimal("1425.00")),
    ("P-200", "Command Center Console", "Software", Decimal("5400.00")),
    ("P-210", "Dispatch Analytics License", "Software", Decimal("960.00")),
    ("P-300", "Resilient Site Gateway", "Infrastructure", Decimal("3200.00")),
    ("P-310", "Encrypted Accessory Kit", "Accessory", Decimal("185.00")),
]


def write_csv(path: Path, fieldnames: list[str], rows: list[dict[str, object]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as stream:
        writer = csv.DictWriter(stream, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)


def money(value: Decimal) -> str:
    return str(value.quantize(Decimal("0.01"), rounding=ROUND_HALF_UP))


def generate(output: Path, customer_count: int, order_count: int) -> None:
    rng = random.Random(SEED)
    warehouse = output / "warehouse"
    object_storage = output / "object-storage"

    product_rows = [
        {
            "product_id": product_id,
            "product_name": name,
            "product_category": category,
            "list_price": money(price),
        }
        for product_id, name, category, price in PRODUCTS
    ]
    segment_rows = [
        {"segment_id": segment_id, "segment_name": name, "segment_description": description}
        for segment_id, name, description in SEGMENTS
    ]

    customer_rows: list[dict[str, object]] = []
    assignment_rows: list[dict[str, object]] = []
    countries = [(region, country) for region, values in REGIONS.items() for country in values]
    for number in range(1, customer_count + 1):
        region, country = countries[(number - 1) % len(countries)]
        customer_id = f"C-{number:04d}"
        customer_rows.append(
            {
                "customer_id": customer_id,
                "customer_name": f"Demo Organization {number:04d}",
                "region": region,
                "country_code": country,
            }
        )
        primary = SEGMENTS[(number - 1) % 3][0]
        assignments = [primary]
        if number % 4 == 0:
            assignments.append("SEG-PCR")
        if number % 11 == 0:
            assignments.append("SEG-PS")
        for segment_id in sorted(set(assignments)):
            assignment_rows.append(
                {
                    "customer_id": customer_id,
                    "segment_id": segment_id,
                    "effective_date": "2025-01-01",
                    "expiration_date": "",
                }
            )

    order_rows: list[dict[str, object]] = []
    line_rows: list[dict[str, object]] = []
    start = date(2025, 1, 1)
    line_number = 1
    for number in range(1, order_count + 1):
        customer = customer_rows[rng.randrange(len(customer_rows))]
        order_date = start + timedelta(days=rng.randrange(365))
        ship_date = order_date + timedelta(days=rng.randrange(1, 15))
        order_id = f"O-{number:06d}"
        order_rows.append(
            {
                "order_id": order_id,
                "customer_id": customer["customer_id"],
                "order_date": order_date.isoformat(),
                "ship_date": ship_date.isoformat(),
                "sales_region": customer["region"],
                "order_status": rng.choice(["Shipped", "Shipped", "Delivered"]),
            }
        )
        for _ in range(rng.randrange(1, 5)):
            product_id, _, _, list_price = PRODUCTS[rng.randrange(len(PRODUCTS))]
            quantity = rng.randrange(1, 9)
            discount = Decimal(rng.choice(["0", "0.03", "0.05", "0.10"]))
            unit_price = list_price * (Decimal("1") - discount)
            line_rows.append(
                {
                    "order_line_id": f"OL-{line_number:07d}",
                    "order_id": order_id,
                    "product_id": product_id,
                    "quantity": quantity,
                    "unit_price": money(unit_price),
                    "discount_pct": money(discount),
                }
            )
            line_number += 1

    write_csv(warehouse / "products.csv", list(product_rows[0]), product_rows)
    write_csv(warehouse / "orders.csv", list(order_rows[0]), order_rows)
    write_csv(warehouse / "order_lines.csv", list(line_rows[0]), line_rows)
    write_csv(object_storage / "customers.csv", list(customer_rows[0]), customer_rows)
    write_csv(
        object_storage / "customer_segment_assignments.csv",
        list(assignment_rows[0]),
        assignment_rows,
    )
    write_csv(object_storage / "segments.csv", list(segment_rows[0]), segment_rows)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, default=Path("sample-data"))
    parser.add_argument("--customers", type=int, default=120)
    parser.add_argument("--orders", type=int, default=900)
    args = parser.parse_args()
    if args.customers < 8 or args.orders < 1:
        parser.error("--customers must be at least 8 and --orders must be positive")
    generate(args.output, args.customers, args.orders)


if __name__ == "__main__":
    main()
