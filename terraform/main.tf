terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  required_version = ">= 1.3.0"
}

provider "aws" {
  region = "us-east-1"
}

# -----------------------------
#   S3 Bucket
# -----------------------------

resource "aws_s3_bucket" "data_bucket" {
  bucket        = "${var.dataset}-${var.username}-2025"
  force_destroy = true

  tags = {
    Owner   = var.username
    Project = var.dataset
  }
}

# Carpetas del bucket
resource "aws_s3_object" "folders" {
  for_each = toset([
    "raw/",
    "processed/",
    "curated/"
  ])

  bucket = aws_s3_bucket.data_bucket.id
  key    = each.value
}

# -----------------------------
#   RDS MySQL
# -----------------------------

resource "aws_db_instance" "mysql" {
  identifier          = "${var.dataset}-${var.username}-db"
  engine              = "mysql"
  engine_version      = "8.0"
  instance_class      = "db.t3.micro"
  allocated_storage   = 20

  username            = "admin"
  password            = var.db_password

  publicly_accessible = true      # Simple para el TP (después se puede endurecer)
  skip_final_snapshot = true      # Para poder destruir sin snapshot
  deletion_protection = false

  tags = {
    Owner   = var.username
    Project = var.dataset
  }
}

# -----------------------------
#   Glue Data Catalog Database
# -----------------------------

resource "aws_glue_catalog_database" "this" {
  name = "${var.dataset}_${var.username}"

  # opcional pero queda prolijo:
  description = "Glue Data Catalog database for ${var.dataset} - ${var.username}"
}

# -----------------------------
#   IAM Role para Glue Jobs
# -----------------------------

data "aws_iam_policy_document" "glue_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["glue.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "glue_role" {
  name               = "${var.dataset}-${var.username}-glue-role"
  assume_role_policy = data.aws_iam_policy_document.glue_assume_role.json
}

# Adjunta la política administrada de servicio Glue
resource "aws_iam_role_policy_attachment" "glue_service_role" {
  role       = aws_iam_role.glue_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
}

# Política inline simple para acceso a S3 y logs
data "aws_iam_policy_document" "glue_extra_permissions" {
  statement {
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:ListBucket"
    ]
    resources = [
      aws_s3_bucket.data_bucket.arn,
      "${aws_s3_bucket.data_bucket.arn}/*"
    ]
  }

  statement {
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "glue_extra" {
  name   = "${var.dataset}-${var.username}-glue-extra"
  role   = aws_iam_role.glue_role.id
  policy = data.aws_iam_policy_document.glue_extra_permissions.json
}
