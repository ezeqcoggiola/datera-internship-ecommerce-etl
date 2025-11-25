output "s3_bucket_name" {
  value = aws_s3_bucket.data_bucket.bucket
}

output "rds_endpoint" {
  value = aws_db_instance.mysql.endpoint
}

output "rds_username" {
  value = aws_db_instance.mysql.username
}

output "glue_database_name" {
  value = aws_glue_catalog_database.this.name
}

output "glue_role_arn" {
  value = aws_iam_role.glue_role.arn
}
