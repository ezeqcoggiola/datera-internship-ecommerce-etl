import sys
from awsglue.utils import getResolvedOptions
from awsglue.context import GlueContext
from pyspark.context import SparkContext
from awsglue.job import Job
from awsglue.dynamicframe import DynamicFrame
from pyspark.sql import functions as F

# ------------------------------------
# Parámetros del Job
# ------------------------------------
args = getResolvedOptions(sys.argv, ["JOB_NAME"])
JOB_NAME = args["JOB_NAME"]

CURATED_DB          = "ecommerce-ezequiel-curated"   # nombre de la DB en Glue
RDS_CONNECTION_NAME = "jdbc-connection-ecommerce"    # nombre de la Connection
RDS_DATABASE        = "database_ecommerce"           # nombre de la base en MySQL

sc = SparkContext()
glueContext = GlueContext(sc)
spark = glueContext.spark_session
job = Job(glueContext)
job.init(JOB_NAME, args)

# ------------------------------------
# Helpers
# ------------------------------------
def load_from_catalog(table_name: str, ctx_name: str):
    dy = glueContext.create_dynamic_frame.from_catalog(
        database=CURATED_DB,
        table_name=table_name,
        transformation_ctx=ctx_name
    )
    return dy.toDF()


def write_to_mysql(df, table_name_rds: str, ctx_name: str):
    """
    Escribe en modo APPEND (incremental).
    No trunca la tabla, confía en:
    - Job Bookmarks para leer solo lo nuevo desde curated
    - Integridad por PK en RDS
    """
    dy = DynamicFrame.fromDF(df, glueContext, f"dy_{table_name_rds}")

    connection_options = {
        "dbtable": table_name_rds,
        "database": RDS_DATABASE,
        # sin preactions => no TRUNCATE, solo APPEND
    }

    glueContext.write_dynamic_frame.from_jdbc_conf(
        frame=dy,
        catalog_connection=RDS_CONNECTION_NAME,
        connection_options=connection_options,
        transformation_ctx=ctx_name
    )

# ------------------------------------
# 1) fact_orders_enriched (APPEND)
# ------------------------------------
fact_orders_enriched_df = load_from_catalog(
    "fact_orders_enriched",
    "src_fact_orders_enriched"
)

write_to_mysql(
    fact_orders_enriched_df,
    "fact_orders_enriched",
    "sink_fact_orders_enriched"
)

# ------------------------------------
# 2) fact_order_items_enriched (APPEND + consolidación PK)
# ------------------------------------
fact_order_items_enriched_df = load_from_catalog(
    "fact_order_items_enriched",
    "src_fact_order_items_enriched"
)

# Consolidar duplicados por PK (order_id, product_id)
fact_order_items_enriched_df = (
    fact_order_items_enriched_df
    .groupBy("order_id", "product_id")
    .agg(
        F.sum("quantity").alias("quantity"),
        F.sum("line_total_usd").alias("line_total_usd"),
        F.first("category").alias("category"),
        F.first("price_usd").alias("price_usd"),
        F.first("cost_usd").alias("cost_usd"),
        F.first("profit_per_unit").alias("profit_per_unit"),
        F.sum("total_profit").alias("total_profit")
    )
)

write_to_mysql(
    fact_order_items_enriched_df,
    "fact_order_items_enriched",
    "sink_fact_order_items_enriched"
)

# ------------------------------------
# 3) agg_daily_sales (APPEND)
# ------------------------------------
agg_daily_sales_df = load_from_catalog(
    "agg_daily_sales",
    "src_agg_daily_sales"
)

write_to_mysql(
    agg_daily_sales_df,
    "agg_daily_sales",
    "sink_agg_daily_sales"
)

# ------------------------------------
# 4) agg_top_products (APPEND)
# ------------------------------------
agg_top_products_df = load_from_catalog(
    "agg_top_products",
    "src_agg_top_products"
)

write_to_mysql(
    agg_top_products_df,
    "agg_top_products",
    "sink_agg_top_products"
)

# ------------------------------------
# 5) agg_funnel (APPEND)
# ------------------------------------
agg_funnel_df = load_from_catalog(
    "agg_funnel",
    "src_agg_funnel"
)

write_to_mysql(
    agg_funnel_df,
    "agg_funnel",
    "sink_agg_funnel"
)

# ------------------------------------
# Fin del Job
# ------------------------------------
job.commit()
