# AI Lambda Container Module
# Generic module for deploying AI Lambda functions as container images

# Lambda Function (Container Image)
resource "aws_lambda_function" "ai_lambda" {
  function_name = var.function_name
  role          = var.lambda_role_arn
  package_type  = "Image"
  image_uri     = var.image_uri
  timeout       = var.timeout
  memory_size   = var.memory_size

  environment {
    variables = merge(
      {
        ATHENA_DATABASE        = var.athena_database
        ATHENA_OUTPUT_LOCATION = var.athena_output_location
        LOG_LEVEL              = var.log_level
      },
      var.additional_env_vars
    )
  }

  tags = var.tags

  # Ignore changes to image_uri as it will be updated by CI/CD
  lifecycle {
    ignore_changes = [image_uri]
  }
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/${aws_lambda_function.ai_lambda.function_name}"
  retention_in_days = var.log_retention_days

  tags = var.tags
}

# Lambda Permission for API Gateway (if enabled)
resource "aws_lambda_permission" "api_gateway" {
  count = var.enable_api_gateway_permission ? 1 : 0

  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ai_lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = var.api_gateway_execution_arn
}
