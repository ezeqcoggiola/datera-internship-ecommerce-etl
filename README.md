# Datera Internship - Proyecto Final
End-to-end AWS data engineering para un e-commerce (TechStore)

Este repositorio contiene el desarrollo del proyecto final de la pasantia de Ingenieria de Datos en Datera. La meta es construir una plataforma analitica completa en AWS para un dataset ficticio de un negocio E-Commerce.

---

## Arquitectura en pocas lineas
- Data Lake en S3 con capas `raw/`, `processed/` (Parquet particionado) y `curated/`.
- Glue ETL Jobs con bookmarks: crudo -> processed -> tablas curadas y carga a RDS.
- Athena para consultas SQL rapidas y QuickSight para dashboards.
- RDS MySQL como motor analitico final.
- Orquestacion prevista con Step Functions + EventBridge al detectar archivos en `raw/`.

## Componentes principales
- Glue jobs (`glue_jobs/`)
  - `job_ecommerce_1.py`: toma tablas raw del Catalog, normaliza tipos y escribe Parquet particionado por fecha en `processed/`.
  - `job_ecommerce_2.py`: crea tablas curadas (facts de ordenes, order_items enriquecido, eventos) filtrando `year >= 2025`.
  - `job_ecommerce_3.py`: castea processed y carga a RDS via JDBC; consolida `order_items` por `(order_id, product_id)`.
- Terraform (`terraform/`): bucket de S3, bases del Glue Catalog, crawlers, Glue Jobs desde scripts en S3, RDS MySQL, VPC/SG, Step Function y regla de EventBridge.
- Notebooks (`notebooks/`): `eda.ipynb` y `upload_files_s3.ipynb` para subir CSVs al bucket raw.
- Dataset local (`dataset-ecommerce/`): CSVs de ejemplo para poblar `raw/` (ej. sesiones noviembre 2025).
- SQL (`sql/create_base_tables_rds.sql`): DDL base para RDS.
- State Machine (`state_machine/state_machine_ecommerce.json`): plantilla para definir el flujo Step Functions (completar segun la orquestacion deseada).
- Docs (`docs/Datera_Internship_Proyecto_Final.pdf`): consigna oficial y diagrama de arquitectura.

## Estructura del repositorio
- `athena-queries/`: espacio para queries de analisis.
- `glue_jobs/`: scripts de los Glue Jobs.
- `notebooks/`: notebooks de EDA y utilidades.
- `dataset-ecommerce/`: datos fuente en CSV organizados por carpeta/tabla.
- `terraform/`: infraestructura IaC.
- `state_machine/`: definicion de Step Functions.
- `sql/`: scripts SQL para RDS.
- `docs/`: documentacion y artefactos de presentacion.

## Despliegue rapido (Terraform)
1) Requisitos: AWS CLI configurado, Terraform >= 1.5, credenciales con permisos para S3/Glue/RDS/Step Functions/IAM.
2) Ajusta variables sensibles y nombres unicos en variables.tf
   ```
   s3_bucket_name    = "ecommerce-<tu-sufijo-unico>"
   db_password       = "cambia_esta_clave"
   developer_ip_cidr = "X.X.X.X/32" # tu IP publica para acceder a RDS
   ```
3) Provisiona:
   ```
   cd terraform
   terraform init
   terraform plan -out=tfplan
   terraform apply tfplan
   ```

## Ejecucion del pipeline
1) Sube los CSV crudos a `s3://<bucket>/raw/<tabla>/`. Puedes usar `notebooks/upload_files_s3.ipynb` o AWS CLI.
2) Se ejecuta el procesado de datos, orquestrado por StepFunctions.
3) Espera a que termine el proceso. Se pode consultar en ejecuciones del StateMachine
4) Consulta en Athena sobre las capas processed/curated y publica dashboards en QuickSight.

Listo: tienes un pipeline end-to-end listo para iterar y extender.
