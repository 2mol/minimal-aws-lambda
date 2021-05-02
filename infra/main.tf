provider "aws" {
  region = var.region
}

resource "aws_lambda_function" "function" {
  function_name = "function"
  handler       = "dummy.handler"
  runtime       = "python3.8"
  role          = aws_iam_role.iam_role.arn
  filename      = "dummy_lambda.zip"
}

resource "aws_iam_role" "iam_role" {
  name        = "iam_role"
  path        = "/"
  description = "Allows Lambda Function to call AWS services on your behalf."

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Effect": "Allow",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Sid": ""
    }
  ]
}
EOF
}
