terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

data "aws_caller_identity" "current" {}

// S3 bucket for the data lake (raw/, processed/, curated/, scripts/)
resource "aws_s3_bucket" "data_bucket" {
  bucket        = var.s3_bucket_name
  force_destroy = true

  tags = {
    Owner   = var.owner
    Project = var.dataset
  }
}

// Create empty folder objects so structure exists in console
resource "aws_s3_object" "folders" {
  for_each = toset(["raw/", "processed/", "curated/", "scripts/"])
  bucket   = aws_s3_bucket.data_bucket.id
  key      = each.value
  content  = ""
}

// Upload local Glue job scripts found in ../glue_jobs to s3://<bucket>/scripts/<file>
locals {
  glue_scripts = fileset("${path.module}/../glue_jobs", "*.py")
}

resource "aws_s3_object" "glue_scripts" {
  for_each = toset(local.glue_scripts)

  bucket = aws_s3_bucket.data_bucket.id
  key    = "scripts/${each.value}"
  source = "${path.module}/../glue_jobs/${each.value}"
  etag   = filemd5("${path.module}/../glue_jobs/${each.value}")
}

// Glue Data Catalog databases: one per data layer (raw, processed, curated)
// Many Glue jobs and crawlers expect separate DBs per layer; this keeps schemas separated and makes permissions easier.
resource "aws_glue_catalog_database" "raw_db" {
  name        = var.raw_db_name
  description = "Glue Catalog database for raw data - ${var.dataset}"
}

resource "aws_glue_catalog_database" "processed_db" {
  name        = var.processed_db_name
  description = "Glue Catalog database for processed data - ${var.dataset}"
}

resource "aws_glue_catalog_database" "curated_db" {
  name        = var.curated_db_name
  description = "Glue Catalog database for curated data - ${var.dataset}"
}

// RDS MySQL instance (development-minded defaults)
resource "aws_db_instance" "mysql" {
  allocated_storage       = var.rds_allocated_storage
  engine                  = "mysql"
  engine_version          = var.rds_engine_version
  instance_class          = var.rds_instance_class
  identifier              = "${var.dataset}-${var.owner}-db"
  db_name                 = var.rds_db_name
  username                = var.rds_username
  password                = var.db_password
  publicly_accessible     = true
  vpc_security_group_ids  = [aws_security_group.rds_sg.id]
  backup_retention_period = var.rds_backup_retention
  skip_final_snapshot     = true
  deletion_protection     = false

  tags = {
    Owner   = var.owner
    Project = var.dataset
  }
}

// Glue Jobs: one per script that we uploaded to S3
resource "aws_glue_job" "jobs" {
  for_each = { for f in local.glue_scripts : replace(f, ".py", "") => f }

  name     = each.key
  role_arn = aws_iam_role.glue_role.arn

  command {
    name            = "glueetl"
    python_version  = "3"
    script_location = "s3://${aws_s3_bucket.data_bucket.bucket}/scripts/${each.value}"
  }

  default_arguments = {
    "--TempDir"      = "s3://${aws_s3_bucket.data_bucket.bucket}/.glue/temp/"
    "--RAW_DB"       = var.raw_db_name
    "--PROCESSED_DB" = var.processed_db_name
    "--CURATED_DB"   = var.curated_db_name
    "--BUCKET"       = aws_s3_bucket.data_bucket.bucket
  }

  max_retries       = 0
  glue_version      = var.glue_version
  number_of_workers = var.glue_number_of_workers
  worker_type       = var.glue_worker_type

  tags = {
    project = var.dataset
  }
}

// Glue Crawlers for raw/ processed/ curated/ paths
resource "aws_glue_crawler" "crawler_raw" {
  name          = "${var.dataset}-${var.owner}-crawler-raw"
  database_name = aws_glue_catalog_database.raw_db.name
  role          = aws_iam_role.glue_role.arn

  s3_target {
    path = "s3://${aws_s3_bucket.data_bucket.bucket}/raw/"
  }
}

resource "aws_glue_crawler" "crawler_processed" {
  name          = "${var.dataset}-${var.owner}-crawler-processed"
  database_name = aws_glue_catalog_database.processed_db.name
  role          = aws_iam_role.glue_role.arn

  s3_target {
    path = "s3://${aws_s3_bucket.data_bucket.bucket}/processed/"
  }
}

resource "aws_glue_crawler" "crawler_curated" {
  name          = "${var.dataset}-${var.owner}-crawler-curated"
  database_name = aws_glue_catalog_database.curated_db.name
  role          = aws_iam_role.glue_role.arn

  s3_target {
    path = "s3://${aws_s3_bucket.data_bucket.bucket}/curated/"
  }
}

// Step Functions state machine using the JSON in the repo state_machine/
resource "aws_sfn_state_machine" "ecommerce_sm" {
  name     = "${var.dataset}-${var.owner}-state-machine"
  role_arn = aws_iam_role.sfn_role.arn

  definition = file("${path.module}/../state_machine/state_machine_ecommerce.json")
}
