import sys
import pandas as pd
import s3fs
import boto3
from datetime import datetime

# ----------------------------
# CONFIGURACIÓN DEL JOB
# ----------------------------
BUCKET = "ecommerce-ezequiel-2025"
RAW_PREFIX = "raw"
PROCESSED_PREFIX = "processed"

# Tablas y su columna de fecha para particionado
TABLE_DATE_COL = {
    "orders": "order_time",
    "order_items": None,
    "products": None,
    "reviews": "review_time",
    "sessions": "start_time",
    "customers": "signup_date",
    "events": "timestamp"
}

fs = s3fs.S3FileSystem()


# ----------------------------
# Casteo básico
# ----------------------------
def cast_types(df):
    for col in df.columns:
        col_l = col.lower()
        if col_l.endswith("_id"):
            df[col] = pd.to_numeric(df[col], errors="coerce").astype("Int64")
        if col_l.endswith("_usd"):
            df[col] = pd.to_numeric(df[col], errors="coerce")
    return df


# ----------------------------
# Procesar una tabla
# ----------------------------
def process_table(table_name):

    date_col = TABLE_DATE_COL[table_name]
    raw_path = f"{RAW_PREFIX}/{table_name}/"

    print(f"\n📥 Buscando CSV en: s3://{BUCKET}/{raw_path}")

    # Buscar archivos CSV dentro de la carpeta
    csv_files = fs.glob(f"{BUCKET}/{raw_path}*.csv")

    if not csv_files:
        print(f"⚠️ No hay archivos en {raw_path}, se omite.")
        return

    # Leer y unir CSVs
    dfs = []
    for file in csv_files:
        print(f"   - Leyendo: s3://{file}")
        df = pd.read_csv(f"s3://{file}")
        dfs.append(df)

    df = pd.concat(dfs, ignore_index=True)
    df.columns = [c.lower() for c in df.columns]
    df = cast_types(df)

    # ----------------------------
    # Procesar particiones
    # ----------------------------
    if date_col and date_col.lower() in df.columns:

        date_col = date_col.lower()
        print(f"📅 Particionando por columna: {date_col}")

        df[date_col] = pd.to_datetime(df[date_col], errors="coerce")
        df["year"] = df[date_col].dt.year
        df["month"] = df[date_col].dt.month
        df["day"] = df[date_col].dt.day

        grouped = df.groupby(["year", "month", "day"])

        for (year, month, day), group in grouped:

            output_path = (
                f"{BUCKET}/{PROCESSED_PREFIX}/{table_name}/"
                f"year={year}/month={month}/day={day}/{table_name}.parquet"
            )

            print(f"💾 Guardando partición → s3://{output_path}")

            group.to_parquet(
                f"s3://{output_path}",
                index=False
            )

    else:
        output_path = (
            f"{BUCKET}/{PROCESSED_PREFIX}/{table_name}/{table_name}.parquet"
        )
        print(f"ℹ️ Tabla sin fecha → guardando sin particiones")
        print(f"💾 s3://{output_path}")

        df.to_parquet(f"s3://{output_path}", index=False)


# ----------------------------
# MAIN
# ----------------------------
def main():
    print("\n🚀 Iniciando procesamiento CSV → Parquet")

    for table in TABLE_DATE_COL.keys():
        print("\n========================================")
        print(f"Procesando: {table}")
        print("========================================")
        process_table(table)

    print("\n🎉 ¡Listo! Todos los CSV fueron procesados.")


if __name__ == "__main__":
    main()