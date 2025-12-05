// Terraform variables for the ecommerce infra
variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "owner" {
  type    = string
  default = "ezequiel"
}

variable "dataset" {
  type    = string
  default = "ecommerce"
}

variable "s3_bucket_name" {
  description = "S3 bucket name for the data lake (must be globally unique)"
  type        = string
  default     = "ecommerce-ezequiel-2025"
}

variable "glue_database_name" {
  description = "Glue Catalog database name"
  type        = string
  default     = "ecommerce_ezequiel_catalog"
}

// RDS variables
variable "rds_instance_class" {
  type    = string
  default = "db.t3.micro"
}

variable "rds_allocated_storage" {
  type    = number
  default = 20
}

variable "rds_engine_version" {
  type    = string
  default = "8.0"
}

variable "rds_db_name" {
  type    = string
  default = "database_ecommerce"
}

variable "rds_username" {
  type    = string
  default = "admin"
}

variable "db_password" {
  description = "RDS master password (sensitive). Provide via tfvars or environment in production."
  type        = string
  sensitive   = true
  default     = "changeme123!"
}

// Glue DB names (these are names used by the Glue jobs in the repo)
variable "raw_db_name" {
  type    = string
  default = "ecommerce_ezequiel_raw"
}

variable "processed_db_name" {
  type    = string
  default = "ecommerce_ezequiel_processed"
}

variable "curated_db_name" {
  type    = string
  default = "ecommerce_ezequiel_curated"
}

// Glue runtime config
variable "glue_version" {
  type    = string
  default = "3.0"
}

variable "glue_number_of_workers" {
  type    = number
  default = 1
}

variable "glue_worker_type" {
  type    = string
  default = "G.1X"
}

variable "rds_backup_retention" {
  description = "Number of days to retain automated backups for RDS. Set 0 to disable (cheaper, less recoverability)."
  type        = number
  default     = 0
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "developer_ip_cidr" {
  description = "Developer public IP in CIDR format to allow temporary access to RDS (e.g. 203.0.113.5/32)"
  type        = string
  default     = "0.0.0.0/0" # REPLACE with your IP/CIDR for security (default open for quick testing)
}
