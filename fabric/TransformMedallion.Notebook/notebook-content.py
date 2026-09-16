# Fabric notebook source

# METADATA ********************
# META {
# META   "kernel_info": {
# META     "name": "synapse_pyspark"
# META   },
# META   "dependencies": {
# META     "lakehouse": {
# META       "default_lakehouse": "f4d8da11-52c1-4fbf-bcf4-bd9dd23110a4",
# META       "default_lakehouse_name": "MedallionLakehouse",
# META       "default_lakehouse_workspace_id": "00000000-0000-0000-0000-000000000000",
# META       "known_lakehouses": [
# META         {
# META           "id": "f4d8da11-52c1-4fbf-bcf4-bd9dd23110a4"
# META         }
# META       ]
# META     }
# META   }
# META }

# CELL ********************

from datetime import date, timedelta

from pyspark.sql import DataFrame, functions as F, types as T

WAREHOUSE_PATH = "Files/landing/warehouse"
CUSTOMER_SHORTCUT_PATH = "Files/landing/customer-domain/external-customers"

SOURCES = {
    "products": (WAREHOUSE_PATH + "/products.csv", {
        "product_id": "string",
        "product_name": "string",
        "product_category": "string",
        "list_price": "decimal(18,2)",
    }),
    "orders": (WAREHOUSE_PATH + "/orders.csv", {
        "order_id": "string",
        "customer_id": "string",
        "order_date": "date",
        "ship_date": "date",
        "sales_region": "string",
        "order_status": "string",
    }),
    "order_lines": (WAREHOUSE_PATH + "/order_lines.csv", {
        "order_line_id": "string",
        "order_id": "string",
        "product_id": "string",
        "quantity": "int",
        "unit_price": "decimal(18,2)",
        "discount_pct": "decimal(9,4)",
    }),
    "customers": (CUSTOMER_SHORTCUT_PATH + "/customers.csv", {
        "customer_id": "string",
        "customer_name": "string",
        "region": "string",
        "country_code": "string",
    }),
    "customer_segment_assignments": (
        CUSTOMER_SHORTCUT_PATH + "/customer_segment_assignments.csv",
        {
            "customer_id": "string",
            "segment_id": "string",
            "effective_date": "date",
            "expiration_date": "date",
        },
    ),
    "segments": (CUSTOMER_SHORTCUT_PATH + "/segments.csv", {
        "segment_id": "string",
        "segment_name": "string",
        "segment_description": "string",
    }),
}


def read_typed_csv(path: str, columns: dict[str, str]) -> DataFrame:
    raw = spark.read.option("header", True).option("mode", "FAILFAST").csv(path)
    missing = set(columns) - set(raw.columns)
    if missing:
        raise ValueError(f"{path} is missing required columns: {sorted(missing)}")
    return raw.select(*(F.col(name).cast(data_type).alias(name) for name, data_type in columns.items()))


def assert_unique(frame: DataFrame, keys: list[str], name: str) -> None:
    duplicate = frame.groupBy(*keys).count().where(F.col("count") > 1).limit(1).count()
    if duplicate:
        raise ValueError(f"{name} has duplicate key values for {keys}")


def assert_no_orphans(child: DataFrame, child_key: str, parent: DataFrame, parent_key: str, name: str) -> None:
    orphan = child.join(parent, child[child_key] == parent[parent_key], "left_anti").limit(1).count()
    if orphan:
        raise ValueError(f"{name} has orphaned {child_key} values")


def save_delta(frame: DataFrame, table_name: str) -> None:
    (
        frame.write.format("delta")
        .mode("overwrite")
        .option("overwriteSchema", "true")
        .saveAsTable(table_name)
    )


bronze = {}
for source_name, (path, columns) in SOURCES.items():
    frame = read_typed_csv(path, columns).withColumn("_ingested_at_utc", F.current_timestamp())
    save_delta(frame, f"Bronze_{source_name}")
    bronze[source_name] = frame.drop("_ingested_at_utc")

# METADATA ********************
# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

assert_unique(bronze["products"], ["product_id"], "products")
assert_unique(bronze["orders"], ["order_id"], "orders")
assert_unique(bronze["order_lines"], ["order_line_id"], "order_lines")
assert_unique(bronze["customers"], ["customer_id"], "customers")
assert_unique(bronze["segments"], ["segment_id"], "segments")
assert_unique(
    bronze["customer_segment_assignments"],
    ["customer_id", "segment_id", "effective_date"],
    "customer_segment_assignments",
)
assert_no_orphans(bronze["orders"], "customer_id", bronze["customers"], "customer_id", "orders")
assert_no_orphans(bronze["order_lines"], "order_id", bronze["orders"], "order_id", "order_lines")
assert_no_orphans(bronze["order_lines"], "product_id", bronze["products"], "product_id", "order_lines")
assert_no_orphans(
    bronze["customer_segment_assignments"],
    "customer_id",
    bronze["customers"],
    "customer_id",
    "customer_segment_assignments",
)
assert_no_orphans(
    bronze["customer_segment_assignments"],
    "segment_id",
    bronze["segments"],
    "segment_id",
    "customer_segment_assignments",
)

silver_customers = bronze["customers"].select(
    F.col("customer_id").alias("CustomerKey"),
    F.trim("customer_name").alias("CustomerName"),
    F.col("region").alias("Region"),
    F.upper("country_code").alias("CountryCode"),
)
silver_products = bronze["products"].select(
    F.col("product_id").alias("ProductKey"),
    F.trim("product_name").alias("ProductName"),
    F.col("product_category").alias("ProductCategory"),
    F.col("list_price").alias("ListPrice"),
)
silver_segments = bronze["segments"].select(
    F.col("segment_id").alias("SegmentKey"),
    F.trim("segment_name").alias("SegmentName"),
    F.trim("segment_description").alias("SegmentDescription"),
)
silver_bridge = bronze["customer_segment_assignments"].select(
    F.col("customer_id").alias("CustomerKey"),
    F.col("segment_id").alias("SegmentKey"),
    F.col("effective_date").alias("EffectiveDate"),
    F.col("expiration_date").alias("ExpirationDate"),
)
silver_orders = bronze["orders"].select(
    F.col("order_id").alias("OrderKey"),
    F.col("customer_id").alias("CustomerKey"),
    F.col("order_date").alias("OrderDate"),
    F.col("ship_date").alias("ShipDate"),
    F.col("sales_region").alias("SalesRegion"),
    F.col("order_status").alias("OrderStatus"),
)
silver_lines = bronze["order_lines"].select(
    F.col("order_line_id").alias("OrderLineKey"),
    F.col("order_id").alias("OrderKey"),
    F.col("product_id").alias("ProductKey"),
    F.col("quantity").alias("Quantity"),
    F.col("unit_price").alias("UnitPrice"),
    F.col("discount_pct").alias("DiscountPercent"),
)

for name, frame in {
    "SilverCustomers": silver_customers,
    "SilverProducts": silver_products,
    "SilverSegments": silver_segments,
    "SilverCustomerSegment": silver_bridge,
    "SilverOrders": silver_orders,
    "SilverOrderLines": silver_lines,
}.items():
    save_delta(frame, name)

# METADATA ********************
# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

fact_sales = (
    silver_lines.join(silver_orders, "OrderKey", "inner")
    .select(
        "OrderLineKey",
        "OrderKey",
        "CustomerKey",
        "ProductKey",
        "OrderDate",
        "ShipDate",
        "SalesRegion",
        "OrderStatus",
        "Quantity",
        "UnitPrice",
        "DiscountPercent",
        (F.col("Quantity") * F.col("UnitPrice")).cast("decimal(18,2)").alias("NetRevenue"),
    )
)

minimum_date = fact_sales.select(F.min("OrderDate")).first()[0]
maximum_date = fact_sales.select(F.max("ShipDate")).first()[0]
if minimum_date is None or maximum_date is None:
    raise ValueError("FactSales cannot be empty")
date_count = (maximum_date - minimum_date).days + 1
date_dimension = (
    spark.range(date_count)
    .select(F.date_add(F.lit(minimum_date), F.col("id").cast("int")).alias("Date"))
    .select(
        F.date_format("Date", "yyyyMMdd").cast("int").alias("DateKey"),
        "Date",
        F.year("Date").alias("Year"),
        F.quarter("Date").alias("QuarterNumber"),
        F.month("Date").alias("MonthNumber"),
        F.date_format("Date", "MMMM").alias("MonthName"),
    )
)

gold_tables = {
    "GoldFactSales": fact_sales,
    "GoldDimCustomer": silver_customers,
    "GoldDimProduct": silver_products,
    "GoldDimSegment": silver_segments,
    "GoldBridgeCustomerSegment": silver_bridge,
    "GoldDimDate": date_dimension,
}
for name, frame in gold_tables.items():
    save_delta(frame, name)

result = {
    "status": "succeeded",
    "goldTables": {name: frame.count() for name, frame in gold_tables.items()},
}
notebookutils.notebook.exit(str(result))

# METADATA ********************
# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }
