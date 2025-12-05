// IAM role for Glue (basic) - in production tighten policies to least privilege
resource "aws_iam_role" "glue_role" {
  name = "${var.dataset}-${var.owner}-glue-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "glue.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

// Attach managed policies useful for dev: adjust for production
resource "aws_iam_role_policy_attachment" "glue_managed_policies" {
  for_each = toset([
    "service-role/AWSGlueServiceRole",
    "AmazonS3FullAccess",
    "CloudWatchLogsFullAccess",
    "AmazonRDSFullAccess"
  ])

  role       = aws_iam_role.glue_role.name
  policy_arn = "arn:aws:iam::aws:policy/${each.value}"
}

// IAM role for Step Functions (allow SF to call Glue StartJobRun, etc.)
resource "aws_iam_role" "sfn_role" {
  name = "${var.dataset}-${var.owner}-sfn-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "states.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

// Attach Step Functions managed policy (for dev) and inline policy to allow Glue job starts
resource "aws_iam_role_policy_attachment" "sfn_managed" {
  role       = aws_iam_role.sfn_role.name
  policy_arn = "arn:aws:iam::aws:policy/AWSStepFunctionsFullAccess"
}

resource "aws_iam_role_policy" "sfn_allow_glue" {
  name = "${var.dataset}-${var.owner}-sfn-allow-glue"
  role = aws_iam_role.sfn_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "glue:StartJobRun",
          "glue:GetJobRun",
          "glue:GetJobRuns"
        ]
        Resource = "*"
      }
    ]
  })
}
