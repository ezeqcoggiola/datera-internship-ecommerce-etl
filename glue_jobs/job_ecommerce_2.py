import sys
from awsglue.utils import getResolvedOptions
from awsglue.context import GlueContext
from pyspark.context import SparkContext
import pyspark.sql.functions as F
from awsglue.job import Job
from awsglue.dynamicframe import DynamicFrame

# -------------------------------------------
# Parámetros del Job
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
# Funciones auxiliares
# -------------------------------------------
def load_dyf(table_name, ctx):
    """
    Carga DynamicFrame desde Glue Catalog con soporte para bookmarks.
    """
    return glueContext.create_dynamic_frame.from_catalog(
        database=PROCESSED_DB,
        table_name=table_name,
        transformation_ctx=ctx
    )


def write_df(df, name, partitions=None):
    """
    Escribe un DataFrame en curated/ en modo append (incremental).
    """
    path = f"s3://{BUCKET}/curated/{name}/"
    
    if partitions:
        df.write.mode("append").partitionBy(partitions).parquet(path)
    else:
        df.write.mode("append").parquet(path)


# -------------------------------------------
# Cargar processed (con bookmarks)
# -------------------------------------------
orders_dyf      = load_dyf("orders", "src_orders")
order_items_dyf = load_dyf("order_items", "src_order_items")
products_dyf    = load_dyf("products", "src_products")
customers_dyf   = load_dyf("customers", "src_customers")
events_dyf      = load_dyf("events", "src_events")

# Convertir a DF
orders_all      = orders_dyf.toDF()
order_items_all = order_items_dyf.toDF()
products        = products_dyf.toDF()
customers       = customers_dyf.toDF()
events_all      = events_dyf.toDF()

# -------------------------------------------
# FILTRO: solo year >= 2025 (maneja años futuros 2026, 2027…)
# -------------------------------------------
orders_filtered = orders_all.filter(F.col("year") >= F.lit(2025))
events_filtered = events_all.filter(F.col("year") >= F.lit(2025))


# -------------------------------------------
# FACT: ORDER ITEMS ENRICHED (solo órdenes >= 2025)
# -------------------------------------------
fact_order_items_enriched = (
    order_items_all.alias("oi")
    .join(orders_filtered.select("order_id", "year"), "order_id", "inner")
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
        (F.col("oi.line_total_usd") - F.col("p.cost_usd") * F.col("oi.quantity")).alias("total_profit"),
        "year"   # útil para particiones & análisis
    )
)

write_df(fact_order_items_enriched, "fact_order_items_enriched")


# -------------------------------------------
# FACT: ORDERS ENRICHED
# -------------------------------------------
orders_clean    = orders_filtered.withColumnRenamed("country", "order_country")
customers_clean = customers.withColumnRenamed("country", "customer_country")

fact_orders_enriched = (
    orders_clean.alias("o")
    .join(customers_clean.alias("c"), "customer_id", "left")
    .withColumn("order_hour", F.hour("order_time"))
    .withColumn("order_dayofweek", F.dayofweek("order_time"))
    .withColumn("order_date", F.to_date("order_time"))   # DATE ideal para QuickSight
    .select(
        "o.order_id",
        "o.customer_id",
        "order_time",
        "order_date",
        "total_usd",
        "discount_pct",
        "order_country",
        "device",
        "source",
        "c.age",
        "c.customer_country",
        "c.marketing_opt_in",
        "o.year",
        "o.month"
    )
)

write_df(fact_orders_enriched, "fact_orders_enriched", ["year", "month"])


# -------------------------------------------
# FACT: EVENTS ENRICHED (para funnel)
# -------------------------------------------
events_enriched = (
    events_filtered
    .withColumn("event_date", F.to_date("timestamp"))
    .select(
        "event_id",
        "session_id",
        "timestamp",
        "event_date",
        "event_type",
        "product_id",
        "qty",
        "cart_size",
        "payment",
        "discount_pct",
        "amount_usd",
        "year",
        "month"
    )
)

write_df(events_enriched, "events_enriched", ["year", "month"])


# -------------------------------------------
# FIN DEL JOB
# -------------------------------------------
job.commit()
