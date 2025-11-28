import sys
from awsglue.utils import getResolvedOptions
from awsglue.context import GlueContext
from pyspark.context import SparkContext
from awsglue.job import Job
from awsglue.dynamicframe import DynamicFrame

# ------------------------------------
# Parámetros del Job
# ------------------------------------
# Solo pedimos JOB_NAME, que Glue SIEMPRE pasa bien
args = getResolvedOptions(sys.argv, ["JOB_NAME"])

JOB_NAME = args["JOB_NAME"]

# 👉 Hardcodeamos estos 3 por ahora
CURATED_DB          = "ecommerce-ezequiel-curated"        # nombre de la DB en Glue
RDS_CONNECTION_NAME = "jdbc-connection-ecommerce"        # nombre de la Connection
RDS_DATABASE        = "database-ecommerce"               # nombre de la base en MySQL

sc = SparkContext()
glueContext = GlueContext(sc)
spark = glueContext.spark_session
job = Job(glueContext)
job.init(JOB_NAME, args)

# ------------------------------------
# Helpers
# ------------------------------------
def load_from_catalog(table_name: str, ctx_name: str):
    """
    Lee una tabla de curated desde el Glue Catalog y la devuelve como Spark DataFrame.
    El transformation_ctx es clave para que funcionen los Job Bookmarks.
    """
    dy = glueContext.create_dynamic_frame.from_catalog(
        database=CURATED_DB,
        table_name=table_name,
        transformation_ctx=ctx_name
    )
    return dy.toDF()


def write_to_mysql(df, table_name_rds: str, ctx_name: str):
    """
    Escribe un DataFrame en MySQL usando una Glue JDBC Connection.
    Modo incremental: siempre APPEND, sin truncar.
    """
    dy = DynamicFrame.fromDF(df, glueContext, f"dy_{table_name_rds}")

    connection_options = {
        "dbtable": table_name_rds,
        "database": RDS_DATABASE
    }

    glueContext.write_dynamic_frame.from_jdbc_conf(
        frame=dy,
        catalog_connection=RDS_CONNECTION_NAME,
        connection_options=connection_options,
        transformation_ctx=ctx_name
    )


# ------------------------------------
# 1) fact_orders_enriched
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
# 2) fact_order_items_enriched
# ------------------------------------
fact_order_items_enriched_df = load_from_catalog(
    "fact_order_items_enriched",
    "src_fact_order_items_enriched"
)

write_to_mysql(
    fact_order_items_enriched_df,
    "fact_order_items_enriched",
    "sink_fact_order_items_enriched"
)

# ------------------------------------
# 3) agg_daily_sales
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
# 4) agg_top_products
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
# 5) agg_funnel
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
