from __future__ import annotations

import csv
import tempfile
import unittest
from collections import Counter
from decimal import Decimal
from pathlib import Path

from scripts.generate_data import generate


class SampleDataTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        generate(self.root, customer_count=24, order_count=80)

    def tearDown(self) -> None:
        self.temp.cleanup()

    def read(self, relative: str) -> list[dict[str, str]]:
        with (self.root / relative).open(newline="", encoding="utf-8") as stream:
            return list(csv.DictReader(stream))

    def test_exactly_six_source_tables_across_two_domains(self) -> None:
        files = sorted(path.relative_to(self.root).as_posix() for path in self.root.rglob("*.csv"))
        self.assertEqual(
            files,
            [
                "object-storage/customer_segment_assignments.csv",
                "object-storage/customers.csv",
                "object-storage/segments.csv",
                "warehouse/order_lines.csv",
                "warehouse/orders.csv",
                "warehouse/products.csv",
            ],
        )

    def test_keys_and_many_to_many_bridge_are_valid(self) -> None:
        customers = self.read("object-storage/customers.csv")
        assignments = self.read("object-storage/customer_segment_assignments.csv")
        segments = self.read("object-storage/segments.csv")
        customer_ids = {row["customer_id"] for row in customers}
        segment_ids = {row["segment_id"] for row in segments}
        self.assertTrue(all(row["customer_id"] in customer_ids for row in assignments))
        self.assertTrue(all(row["segment_id"] in segment_ids for row in assignments))
        assignment_counts = Counter(row["customer_id"] for row in assignments)
        self.assertGreater(max(assignment_counts.values()), 1)

    def test_orders_and_lines_are_referentially_consistent(self) -> None:
        orders = self.read("warehouse/orders.csv")
        lines = self.read("warehouse/order_lines.csv")
        products = self.read("warehouse/products.csv")
        order_ids = {row["order_id"] for row in orders}
        product_ids = {row["product_id"] for row in products}
        self.assertTrue(all(row["order_id"] in order_ids for row in lines))
        self.assertTrue(all(row["product_id"] in product_ids for row in lines))
        revenue = sum(
            Decimal(row["unit_price"]) * Decimal(row["quantity"]) for row in lines
        )
        self.assertGreater(revenue, Decimal("0"))


if __name__ == "__main__":
    unittest.main()
