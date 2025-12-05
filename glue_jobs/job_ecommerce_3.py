import sys
import logging
from awsglue.utils import getResolvedOptions
from awsglue.context import GlueContext
from awsglue.job import Job
from pyspark.context import SparkContext
from awsglue.dynamicframe import DynamicFrame
from pyspark.sql import functions as F

# -----------------------------
# Parámetros
# -----------------------------
args = getResolvedOptions(sys.argv, ["JOB_NAME", "PROCESSED_DB"])
JOB_NAME = args["JOB_NAME"]
PROCESSED_DB = args["PROCESSED_DB"]

GLUE_CONNECTION_NAME = "jdbc-connection-ecommerce"
RDS_DATABASE = "database_ecommerce"

sc = SparkContext()
glueContext = GlueContext(sc)
spark = glueContext.spark_session
job = Job(glueContext)
job.init(JOB_NAME, args)

log = logging.getLogger("glue-job")

# ------------------------------------
# CASTS por tabla (todas las tablas)
# ------------------------------------
TABLE_CASTS = {
    'customers': {
        'customer_id': 'int', 'name': 'string', 'email': 'string', 'country': 'string',
        'age': 'int', 'signup_date': 'date', 'marketing_opt_in': 'boolean',
        'year': 'string', 'month': 'string', 'day': 'string'
    },
    'products': {
        'product_id': 'int', 'category': 'string', 'name': 'string',
        'price_usd': 'double', 'cost_usd': 'double', 'margin_usd': 'double'
    },
    'orders': {
        'order_id': 'int', 'customer_id': 'int', 'order_time': 'timestamp',
        'payment_method': 'string', 'discount_pct': 'int', 'subtotal_usd': 'double',
        'total_usd': 'double', 'country': 'string', 'device': 'string', 'source': 'string',
        'year': 'string', 'month': 'string', 'day': 'string'
    },
    'order_items': {
        'order_id': 'int', 'product_id': 'int', 'unit_price_usd': 'double',
        'quantity': 'int', 'line_total_usd': 'double'
    },
    'sessions': {
        'session_id': 'int', 'customer_id': 'int', 'start_time': 'timestamp',
        'device': 'string', 'source': 'string', 'country': 'string',
        'year': 'string', 'month': 'string', 'day': 'string'
    },
    'events': {
        'event_id': 'int', 'session_id': 'int', 'timestamp': 'timestamp',
        'event_type': 'string', 'product_id': 'int', 'qty': 'int', 'cart_size': 'int',
        'payment': 'string', 'discount_pct': 'int', 'amount_usd': 'double',
        'year': 'string', 'month': 'string', 'day': 'string'
    },
    'reviews': {
        'review_id': 'int', 'order_id': 'int', 'product_id': 'int', 'rating': 'int',
        'review_text': 'string', 'review_time': 'timestamp',
        'year': 'string', 'month': 'string', 'day': 'string'
    }
}

# Todas las tablas
TABLES = list(TABLE_CASTS.keys())

# ------------------------------------
# Helpers
# ------------------------------------
def load_from_catalog(table_name):
    """
    Lee usando Glue Catalog + Bookmarks
    """
    dy = glueContext.create_dynamic_frame.from_catalog(
        database=PROCESSED_DB,
        table_name=table_name,
        transformation_ctx=f"src_{table_name}"
    )
    return dy.toDF()

def safe_cast(df, casts):
    cols = []
    for c in df.columns:
        if c in casts:
            cols.append(F.col(c).cast(casts[c]).alias(c))
        else:
            cols.append(F.col(c))
    return df.select(*cols)

def write_to_rds(df, table_name):
    dy = DynamicFrame.fromDF(df, glueContext, f"dy_{table_name}")

    glueContext.write_dynamic_frame.from_jdbc_conf(
        frame=dy,
        catalog_connection=GLUE_CONNECTION_NAME,
        connection_options={
            "dbtable": table_name,
            "database": RDS_DATABASE
        },
        transformation_ctx=f"sink_{table_name}"
    )

# ------------------------------------
# Main
# ------------------------------------
for table in TABLES:
    try:
        log.info(f"=== Procesando tabla {table} ===")

        df = load_from_catalog(table)

        # Cast seguro
        df = safe_cast(df, TABLE_CASTS.get(table, {}))

        # Caso especial: consolidación order_items
        if table == "order_items":
            df = (
                df.groupBy("order_id", "product_id")
                  .agg(
                      F.sum("quantity").alias("quantity"),
                      F.sum("line_total_usd").alias("line_total_usd")
                  )
            )

        write_to_rds(df, table)

    except Exception as e:
        log.exception(f"Error procesando tabla {table}: {e}")

job.commit()
