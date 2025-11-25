# Datera Internship – Proyecto Final
End-to-End AWS Data Engineering Project
E-Commerce TechStore ETL Pipeline

Este repositorio contiene el desarrollo completo del proyecto final de la pasantía de Ingeniería de Datos de **Datera**.  
El objetivo fue construir una plataforma de análisis end-to-end utilizando servicios de AWS y buenas prácticas de ingeniería de datos.

---

## Objetivo del Proyecto

Construir una arquitectura completa de análisis de datos para el dataset **TechStore (E-Commerce)** que incluya:

- Data Lake en Amazon S3 (raw / processed / curated)
- ETL Jobs con AWS Glue (Python Shell y Glue ETL)
- Procesamiento incremental y particionado por fecha
- Análisis SQL con Amazon Athena
- Dashboards interactivos con QuickSight
- Carga de tablas finales curadas a Amazon RDS (motor analítico final)

La arquitectura está basada en la consigna oficial del documento:

**[Datera Internship – Proyecto Final](./docs/Datera_Internship_Proyecto_Final.pdf)**

---

## Arquitectura del Proyecto

![Data Lake Architecture](./docs/architecture-diagram.png)

### Componentes:

- **S3 Data Lake**
  - `raw/`: datos crudos (CSV por carpeta)
  - `processed/`: datos limpios en Parquet + particionados
  - `curated/`: tablas analíticas (hechos y dimensiones)

- **AWS Glue Jobs**
  - `job2-csv-cleaning.py`: transforma CSV → Parquet + particiones
  - `job3-curated-tables.py`: construye tablas finales de análisis

- **Amazon Athena**
  - consultas SQL para análisis y creación de KPIs

- **Amazon RDS**
  - motor relacional final para dashboards y analítica liviana

- **QuickSight**
  - dashboards ejecutivos, cohortes, tendencias, conversión, etc.

---

## Estructura del Repositorio

docs/ # PDS, arquitectura, presentación, documentación técnica

notebooks/ # EDA y scripts

glue-jobs/ # Código de los Glue Jobs (ETL)

athena-queries/ # Consultas SQL para análisis

sql/ # Scripts para RDS

---
