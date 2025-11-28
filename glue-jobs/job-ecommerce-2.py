import sys
from awsglue.utils import getResolvedOptions
from awsglue.context import GlueContext
from pyspark.context import SparkContext
import pyspark.sql.functions as F
from awsglue.job import Job

# -------------------------------------------
# Parámetros del job
# -------------------------------------------
args = getResolvedOptions(sys.argv, ["JOB_NAME", "PROCESSED_DB", "BUCKET"])
JOB_NAME = args["JOB_NAME"]
PROCESSED_DB = args["PROCESSED_DB"]
BUCKET = args["BUCKET"]

sc = SparkContext()
glueContext = GlueContext(sc)
spark = glueContext.spark_session

job = Job(glueContext)
job.init(JOB_NAME, args)


# -------------------------------------------
# Funciones útiles
# -------------------------------------------
def load_df(table_name):
    """Carga una tabla desde el Glue Catalog (processed)."""
    dy = glueContext.create_dynamic_frame.from_catalog(
        database=PROCESSED_DB,
        table_name=table_name
    )
    return dy.toDF()


def write_df(df, name, partitions=None):
    """Escribe un DF en curated/ con o sin particiones."""
    path = f"s3://{BUCKET}/curated/{name}/"

    if partitions:
        df.write.mode("overwrite").partitionBy(partitions).parquet(path)
    else:
        df.write.mode("overwrite").parquet(path)


# -------------------------------------------
# Cargar tablas processed/
# -------------------------------------------
orders = load_df("orders")
order_items = load_df("order_items")
products = load_df("products")
customers = load_df("customers")
events = load_df("events")

# -------------------------------------------
# FACT: ORDER ITEMS ENRICHED
# order_items + products
# -------------------------------------------
fact_order_items_enriched = (
    order_items.alias("oi")
    .join(products.alias("p"), "product_id", "left")
    .select(
        "oi.order_id",
        "oi.product_id",
        "oi.quantity",
        "oi.unit_price_usd",
        "oi.line_total_usd",
        "p.category",
        "p.price_usd",
        "p.cost_usd",
        (F.col("oi.unit_price_usd") - F.col("p.cost_usd")).alias("profit_per_unit"),
        (F.col("oi.line_total_usd") - F.col("p.cost_usd") * F.col("oi.quantity")).alias("total_profit")
    )
)

write_df(fact_order_items_enriched, "fact_order_items_enriched")

# -------------------------------------------
# FACT: ORDERS ENRICHED
# orders + customers
# -------------------------------------------

orders_clean = (
    orders.withColumnRenamed("country", "order_country")
)

customers_clean = (
    customers.withColumnRenamed("country", "customer_country")
)

fact_orders_enriched = (
    orders_clean.alias("o")
    .join(customers_clean.alias("c"), "customer_id", "left")
    .withColumn("order_hour", F.hour("order_time"))
    .withColumn("order_dayofweek", F.dayofweek("order_time"))
    .select(
        "o.order_id",
        "o.customer_id",
        "o.order_time",
        "o.total_usd",
        "o.discount_pct",
        "o.order_country",
        "o.device",
        "o.source",
        "c.age",
        "c.customer_country",
        "c.marketing_opt_in",
        "o.year",
        "o.month"
    )
)

write_df(fact_orders_enriched, "fact_orders_enriched", ["year", "month"])

# -------------------------------------------
# AGG: DAILY SALES
# -------------------------------------------
agg_daily_sales = (
    orders.groupBy(
        F.col("year"),
        F.col("month"),
        F.dayofmonth("order_time").alias("day")
    )
    .agg(
        F.sum("total_usd").alias("daily_revenue"),
        F.count("*").alias("num_orders")
    )
)

write_df(agg_daily_sales, "agg_daily_sales", ["year", "month"])

# -------------------------------------------
# AGG: TOP PRODUCTS
# -------------------------------------------
agg_top_products = (
    fact_order_items_enriched
    .groupBy("product_id", "category")
    .agg(
        F.sum("line_total_usd").alias("total_revenue"),
        F.sum("total_profit").alias("total_profit")
    )
)

write_df(agg_top_products, "agg_top_products")

# -------------------------------------------
# AGG: FUNNEL (events)
# -------------------------------------------
agg_funnel = (
    events.groupBy("event_type")
    .agg(F.count("*").alias("num_events"))
)

write_df(agg_funnel, "agg_funnel")

# -------------------------------------------
# FIN DEL JOB
# -------------------------------------------
job.commit()

