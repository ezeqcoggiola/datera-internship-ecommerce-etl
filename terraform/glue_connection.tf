// Glue JDBC connection for RDS MySQL so Glue jobs can write to the database
resource "aws_glue_connection" "jdbc_ecommerce" {
  name = "${var.dataset}-${var.owner}-jdbc-connection"

  connection_properties = {
    JDBC_CONNECTION_URL = format("jdbc:mysql://%s:%s/%s", aws_db_instance.mysql.address, aws_db_instance.mysql.port, var.rds_db_name)
    USERNAME            = var.rds_username
    PASSWORD            = var.db_password
    // Optionally specify the driver class; Glue usually detects driver when using the JDBC URL
    JDBC_DRIVER_CLASS_NAME = "com.mysql.cj.jdbc.Driver"
  }

  // If your RDS is in a VPC and requires ENIs for Glue, set `physical_connection_requirements`.
  // Currently the RDS is publicly accessible and Glue will connect via the public endpoint,
  // so we omit VPC-specific physical requirements. To enable VPC connection later, add:
  // physical_connection_requirements {
  //   subnet_id = "<subnet-id>"
  //   security_group_id_list = ["<sg-id>"]
  // }
}
