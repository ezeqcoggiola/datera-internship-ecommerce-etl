output "s3_bucket_name" {
  description = "Data lake S3 bucket name"
  value       = aws_s3_bucket.data_bucket.bucket
}

output "rds_endpoint" {
  description = "RDS endpoint (address:port)"
  value       = aws_db_instance.mysql.address
}

output "rds_username" {
  value = aws_db_instance.mysql.username
}

output "glue_database_name" {
  value = {
    raw       = aws_glue_catalog_database.raw_db.name
    processed = aws_glue_catalog_database.processed_db.name
    curated   = aws_glue_catalog_database.curated_db.name
  }
}

output "glue_job_names" {
  value = [for j in aws_glue_job.jobs : j.name]
}

output "state_machine_arn" {
  value = aws_sfn_state_machine.ecommerce_sm.arn
}

output "glue_service_role_arn" {
  description = "Glue IAM role ARN created (development). Replace with stricter role in production."
  value       = aws_iam_role.glue_role.arn
}

output "sfn_role_arn" {
  value = aws_iam_role.sfn_role.arn
}
