import sys
from awsglue.utils import getResolvedOptions
from awsglue.context import GlueContext
from awsglue.job import Job
from awsglue.dynamicframe import DynamicFrame
from pyspark.context import SparkContext
import pyspark.sql.functions as F

# ------------------------
# Parámetros del Job
# ------------------------
args = getResolvedOptions(sys.argv, ["JOB_NAME", "RAW_DB", "BUCKET"])

JOB_NAME = args["JOB_NAME"]
RAW_DB = args["RAW_DB"]          # ej: "ecommerce_ezequiel_raw"
BUCKET = args["BUCKET"]         # ej: "ecommerce-ezequiel-2025"

sc = SparkContext()
glueContext = GlueContext(sc)
spark = glueContext.spark_session

job = Job(glueContext)
job.init(JOB_NAME, args)

# ------------------------
# Configuración de tablas
# ------------------------
# Nombre de tabla en el Catálogo  ->  columna de fecha  + nombre de salida
TABLES_CONFIG = {
    "orders_raw":      {"date_col": "order_time",   "output_name": "orders"},
    "order_items_raw": {"date_col": None,           "output_name": "order_items"},
    "products_raw":    {"date_col": None,           "output_name": "products"},
    "reviews_raw":     {"date_col": "review_time",  "output_name": "reviews"},
    "sessions_raw":    {"date_col": "start_time",   "output_name": "sessions"},
    "customers_raw":   {"date_col": "signup_date",  "output_name": "customers"},
    "events_raw":      {"date_col": "timestamp",    "output_name": "events"},
}


def cast_common_types(df):
    """
    Reglas simples:
    - *_id   -> BIGINT (long)
    - *_usd  -> DOUBLE
    """
    for col in df.columns:
        cl = col.lower()
        if cl.endswith("_id"):
            df = df.withColumn(col, F.col(col).cast("long"))
        if cl.endswith("_usd"):
            df = df.withColumn(col, F.col(col).cast("double"))
    return df


# ------------------------
# Loop principal por tabla
# ------------------------
for table_name, cfg in TABLES_CONFIG.items():
    date_col = cfg["date_col"]
    output_name = cfg["output_name"]

    print("\n=====================================")
    print(f"Procesando tabla RAW: {table_name}")
    print("=====================================")

    # 1) Leer desde el Glue Catalog con bookmarks
    dy = glueContext.create_dynamic_frame.from_catalog(
        database=RAW_DB,
        table_name=table_name,
        transformation_ctx=f"{table_name}_source"  # clave de bookmarks
    )

    # Si no hay datos nuevos, seguimos con la próxima tabla
    if dy.count() == 0:
        print(f"⚠️  Sin datos nuevos para {table_name} (bookmarks al día).")
        continue

    # 2) DynamicFrame -> DataFrame para transformar
    df = dy.toDF()

    # Normalizar nombres de columnas
    df = df.toDF(*[c.lower() for c in df.columns])

    # Casteo genérico
    df = cast_common_types(df)

    # 3) Manejo de fecha y particiones
    partition_keys = []

    if date_col is not None and date_col.lower() in df.columns:
        date_col = date_col.lower()
        print(f"📅 Usando '{date_col}' como columna de fecha para particionar")

        df = df.withColumn(date_col, F.to_timestamp(F.col(date_col)))

        df = df.withColumn("year", F.year(F.col(date_col)))
        df = df.withColumn("month", F.month(F.col(date_col)))
        df = df.withColumn("day", F.dayofmonth(F.col(date_col)))

        partition_keys = ["year", "month", "day"]
    else:
        print(f"ℹ️ {table_name} no tiene columna de fecha, se guarda sin partición")

    # 4) Volver a DynamicFrame para escribir
    dy_out = DynamicFrame.fromDF(df, glueContext, f"{output_name}_out")

    # 5) Escribir a S3 processed/ como Parquet (append)
    output_path = f"s3://{BUCKET}/processed/{output_name}/"
    print(f"💾 Escribiendo salida en: {output_path}")
    print(f"   Particiones: {partition_keys if partition_keys else 'ninguna'}")

    connection_options = {"path": output_path}
    if partition_keys:
        connection_options["partitionKeys"] = partition_keys

    glueContext.write_dynamic_frame.from_options(
        frame=dy_out,
        connection_type="s3",
        format="parquet",
        connection_options=connection_options,
        transformation_ctx=f"{output_name}_sink"
    )

job.commit()
