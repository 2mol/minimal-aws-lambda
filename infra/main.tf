# ---------------------------------------
# BASIC SETUP
# ---------------------------------------

provider "aws" {
  region = var.region
}


# ---------------------------------------
# JUST LAMBDA, NOTHING ELSE MATTERS
# ---------------------------------------

resource "aws_lambda_function" "abc" {
  function_name = "abc_function"
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


# ---------------------------------------
# HOW TO EVEN GET LMAODA ON INTERNET
# ---------------------------------------

resource "aws_api_gateway_rest_api" "abc_api" {
  name        = "abc_api"
  description = "This is an API. It serves requests over the public internet."
}

resource "aws_api_gateway_resource" "proxy" {
  rest_api_id = aws_api_gateway_rest_api.abc_api.id
  parent_id   = aws_api_gateway_rest_api.abc_api.root_resource_id
  path_part   = "api"
}

resource "aws_api_gateway_method" "proxy" {
  rest_api_id   = aws_api_gateway_rest_api.abc_api.id
  resource_id   = aws_api_gateway_resource.proxy.id
  http_method   = "ANY"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "abc" {
  rest_api_id = aws_api_gateway_rest_api.abc_api.id
  resource_id = aws_api_gateway_resource.proxy.id
  http_method = aws_api_gateway_method.proxy.http_method

  integration_http_method = "ANY"

  type = "AWS_PROXY"
  uri  = aws_lambda_function.abc.invoke_arn
}

resource "aws_api_gateway_deployment" "abc" {
  depends_on  = [aws_api_gateway_integration.abc]
  rest_api_id = aws_api_gateway_rest_api.abc_api.id

  triggers = {
    redeployment = sha1(jsonencode(aws_api_gateway_rest_api.abc_api.body))
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "abc" {
  deployment_id = aws_api_gateway_deployment.abc.id
  rest_api_id   = aws_api_gateway_rest_api.abc_api.id
  stage_name    = "dev_but_not_really"
}


# -----------------------------------------------------------------------------
# ALSO WE NEED PERMISSIONS TO RUN THE LAMBO
# -----------------------------------------------------------------------------

resource "aws_iam_role_policy_attachment" "abc" {
  role       = aws_iam_role.iam_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_lambda_permission" "abc" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.abc.function_name
  principal     = "apigateway.amazonaws.com"

  # The "/*/*" portion grants access from any method on any resource
  # within the API Gateway REST API.
  source_arn = "${aws_api_gateway_rest_api.abc_api.execution_arn}/*/*"
}


# -----------------------------------------------------------------------------
# outputs being put out
# -----------------------------------------------------------------------------

output "api_url" {
  value = "${aws_api_gateway_deployment.abc.invoke_url}${aws_api_gateway_resource.proxy.path_part}"
}
