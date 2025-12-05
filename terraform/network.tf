// VPC, Subnets, Security Groups and EventBridge rule to trigger State Machine

resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr
  tags = {
    Name = "${var.dataset}-${var.owner}-vpc"
  }
}

data "aws_availability_zones" "available" {}

resource "aws_subnet" "private" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(aws_vpc.main.cidr_block, 8, count.index + 1)
  availability_zone = element(data.aws_availability_zones.available.names, count.index)
  tags = {
    Name = "${var.dataset}-${var.owner}-private-${count.index + 1}"
  }
}

// Public subnet (one) for RDS public access and/or bastion
resource "aws_subnet" "public" {
  count                   = 1
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(aws_vpc.main.cidr_block, 8, 10)
  availability_zone       = element(data.aws_availability_zones.available.names, 0)
  map_public_ip_on_launch = true
  tags = {
    Name = "${var.dataset}-${var.owner}-public-1"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "${var.dataset}-${var.owner}-igw" }
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

resource "aws_route_table_association" "public_assoc" {
  subnet_id      = element(aws_subnet.public.*.id, 0)
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_db_subnet_group" "rds_subnets" {
  name        = "${var.dataset}-${var.owner}-rds-subnet-group"
  subnet_ids  = concat(aws_subnet.public.*.id, aws_subnet.private.*.id)
  description = "Subnet group for RDS in ${var.dataset} VPC"
}

// Security Group used by Glue (ENIs will use this SG)
resource "aws_security_group" "glue_sg" {
  name        = "${var.dataset}-${var.owner}-glue-sg"
  description = "Security group for Glue ENIs"
  vpc_id      = aws_vpc.main.id

  // Allow inbound from same security group (self) for internal communication
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
    description = "Allow traffic within Glue SG"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

// Security Group for RDS: allow MySQL from Glue SG and developer IP only
resource "aws_security_group" "rds_sg" {
  name        = "${var.dataset}-${var.owner}-rds-sg"
  description = "Security group for RDS MySQL, allow only Glue and developer IP"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "Allow MySQL from Glue SG"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.glue_sg.id]
  }

  ingress {
    description = "Allow MySQL from developer IP for testing"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = [var.developer_ip_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

// EventBridge (CloudWatch Events) rule to trigger State Machine on new object in raw/ prefix
resource "aws_cloudwatch_event_rule" "s3_raw_object_created" {
  name        = "${var.dataset}-${var.owner}-s3-raw-object-created"
  description = "Trigger State Machine when a new object is created under raw/ in the data bucket"

  event_pattern = jsonencode({
    "source"      = ["aws.s3"],
    "detail-type" = ["Object Created"],
    "detail" = {
      "bucket" = { "name" = [aws_s3_bucket.data_bucket.bucket] },
      "object" = { "key" = [{ "prefix" = "raw/" }] }
    }
  })
}

// IAM role that EventBridge will assume to start the Step Function execution
resource "aws_iam_role" "eventbridge_role" {
  name = "${var.dataset}-${var.owner}-eventbridge-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect    = "Allow",
        Principal = { Service = "events.amazonaws.com" },
        Action    = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy" "eventbridge_start_sfn" {
  name = "${var.dataset}-${var.owner}-eventbridge-start-sfn"
  role = aws_iam_role.eventbridge_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = ["states:StartExecution"],
        Resource = aws_sfn_state_machine.ecommerce_sm.arn
      }
    ]
  })
}

resource "aws_cloudwatch_event_target" "sfn_target" {
  rule     = aws_cloudwatch_event_rule.s3_raw_object_created.name
  arn      = aws_sfn_state_machine.ecommerce_sm.arn
  role_arn = aws_iam_role.eventbridge_role.arn
  input_transformer {
    input_paths = {
      "detail" = "$.detail"
    }
    input_template = <<TEMPLATE
{"bucket": <detail.bucket.name>, "key": <detail.object.key>}
TEMPLATE
  }
}

// Give EventBridge permission to invoke the target (Step Functions) is achieved via role_arn on target
