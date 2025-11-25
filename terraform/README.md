-----------------------------------------------

Terraform crea:

- Bucket S3 con estructura raw/, processed/, curated/

- Instancia RDS MySQL db.t3.micro

- Glue Database + IAM Role de Glue

- Glue Connections y Glue Jobs se crean desde consola manualmente

-----------------------------------------------

Ejecutar desde consola (WSL)

cd infra/

# Deploy
./deploy.sh ezecoggiola techstore contrasena123

# Destroy
./destroy.sh ezecoggiola techstore contrasena123

