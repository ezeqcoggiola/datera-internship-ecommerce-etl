variable "username" {
  description = "Tu nombre"
  type        = string
}

variable "dataset" {
  description = "Nombre del dataset"
  type        = string
}

variable "db_password" {
  description = "Password del RDS"
  type        = string
  sensitive   = true
}
