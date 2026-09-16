from __future__ import annotations

import csv
import json
import re
import unittest
from decimal import Decimal
from pathlib import Path

ROOT = Path(__file__).parents[1]
MODEL = ROOT / "fabric" / "Motorola Sales Certified.SemanticModel" / "definition"


class RepositoryContractTests(unittest.TestCase):
    def test_all_json_is_parseable(self) -> None:
        for path in ROOT.rglob("*.json"):
            with self.subTest(path=path.relative_to(ROOT)):
                json.loads(path.read_text(encoding="utf-8-sig"))

    def test_model_contains_required_relationship_patterns(self) -> None:
        relationships = (MODEL / "relationships.tmdl").read_text(encoding="utf-8")
        self.assertEqual(relationships.count("relationship "), 6)
        self.assertIn("'Customer Segment Bridge'.'Customer Key'", relationships)
        self.assertIn("'Customer Segment Bridge'.'Segment Key'", relationships)
        self.assertIn("crossFilteringBehavior: bothDirections", relationships)
        self.assertIn("'Order Date'.Date", relationships)
        self.assertIn("'Ship Date'.Date", relationships)

    def test_model_has_measures_rls_and_hidden_technical_columns(self) -> None:
        fact = (MODEL / "tables" / "Fact Sales.tmdl").read_text(encoding="utf-8")
        roles = "\n".join(
            path.read_text(encoding="utf-8") for path in (MODEL / "roles").glob("*.tmdl")
        )
        self.assertEqual(fact.count("\n\tmeasure "), 3)
        self.assertIn("measure 'PCR Revenue'", fact)
        self.assertGreaterEqual(fact.count("\n\t\tisHidden"), 7)
        self.assertIn("role 'North America'", roles)
        self.assertIn("role Europe", roles)
        self.assertIn('Customer[Region] = "North America"', roles)
        self.assertIn('Customer[Region] = "Europe"', roles)

    def test_expected_rls_answers_match_committed_sample(self) -> None:
        with (ROOT / "sample-data" / "warehouse" / "orders.csv").open(
            newline="", encoding="utf-8"
        ) as stream:
            orders = {row["order_id"]: row for row in csv.DictReader(stream)}
        with (ROOT / "sample-data" / "warehouse" / "order_lines.csv").open(
            newline="", encoding="utf-8"
        ) as stream:
            lines = list(csv.DictReader(stream))
        with (
            ROOT
            / "sample-data"
            / "object-storage"
            / "customer_segment_assignments.csv"
        ).open(newline="", encoding="utf-8") as stream:
            pcr_customers = {
                row["customer_id"]
                for row in csv.DictReader(stream)
                if row["segment_id"] == "SEG-PCR"
            }
        expected = json.loads((ROOT / "ai" / "test-cases.json").read_text(encoding="utf-8"))
        tests = {test["persona"]: test["expected"] for test in expected["tests"][:2]}
        for region in ("North America", "Europe"):
            region_orders = {
                key: value for key, value in orders.items() if value["sales_region"] == region
            }
            region_lines = [line for line in lines if line["order_id"] in region_orders]
            revenue = sum(
                Decimal(line["unit_price"]) * int(line["quantity"]) for line in region_lines
            )
            pcr_revenue = sum(
                Decimal(line["unit_price"]) * int(line["quantity"])
                for line in region_lines
                if region_orders[line["order_id"]]["customer_id"] in pcr_customers
            )
            self.assertEqual(revenue, Decimal(str(tests[region]["netRevenue"])))
            self.assertEqual(pcr_revenue, Decimal(str(tests[region]["pcrRevenue"])))
            self.assertEqual(len(region_orders), tests[region]["orderCount"])

    def test_no_credential_like_values_are_committed(self) -> None:
        suspicious = re.compile(
            r"(?i)(client_secret|password|accountkey)\s*[=:]\s*[\"']?(?!\s*$|\$\{|<)"
        )
        ignored_directories = {".git", ".venv", "__pycache__", ".pytest_cache", "dist"}
        for path in ROOT.rglob("*"):
            if (
                not path.is_file()
                or ignored_directories.intersection(path.parts)
                or path.suffix == ".pyc"
            ):
                continue
            if path.name == ".env.example":
                continue
            with self.subTest(path=path.relative_to(ROOT)):
                text = path.read_text(encoding="utf-8", errors="ignore")
                self.assertIsNone(suspicious.search(text))


if __name__ == "__main__":
    unittest.main()
