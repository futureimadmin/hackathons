# API Gateway Integration for System Registration

# API Gateway Resource for /admin/systems
resource "aws_api_gateway_resource" "admin" {
  rest_api_id = var.api_gateway_id
  parent_id   = var.api_gateway_root_resource_id
  path_part   = "admin"
}

resource "aws_api_gateway_resource" "systems" {
  rest_api_id = var.api_gateway_id
  parent_id   = aws_api_gateway_resource.admin.id
  path_part   = "systems"
}

# POST /admin/systems - Register new system
resource "aws_api_gateway_method" "register_system" {
  rest_api_id   = var.api_gateway_id
  resource_id   = aws_api_gateway_resource.systems.id
  http_method   = "POST"
  authorization = "CUSTOM"
  authorizer_id = var.api_gateway_authorizer_id
}

resource "aws_api_gateway_integration" "register_system" {
  rest_api_id             = var.api_gateway_id
  resource_id             = aws_api_gateway_resource.systems.id
  http_method             = aws_api_gateway_method.register_system.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.system_registration.invoke_arn
}

# GET /admin/systems - List all systems
resource "aws_api_gateway_method" "list_systems" {
  rest_api_id   = var.api_gateway_id
  resource_id   = aws_api_gateway_resource.systems.id
  http_method   = "GET"
  authorization = "CUSTOM"
  authorizer_id = var.api_gateway_authorizer_id
}

resource "aws_api_gateway_integration" "list_systems" {
  rest_api_id             = var.api_gateway_id
  resource_id             = aws_api_gateway_resource.systems.id
  http_method             = aws_api_gateway_method.list_systems.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.system_registration.invoke_arn
}

# GET /admin/systems/{system_id} - Get system details
resource "aws_api_gateway_resource" "system_id" {
  rest_api_id = var.api_gateway_id
  parent_id   = aws_api_gateway_resource.systems.id
  path_part   = "{system_id}"
}

resource "aws_api_gateway_method" "get_system" {
  rest_api_id   = var.api_gateway_id
  resource_id   = aws_api_gateway_resource.system_id.id
  http_method   = "GET"
  authorization = "CUSTOM"
  authorizer_id = var.api_gateway_authorizer_id
}

resource "aws_api_gateway_integration" "get_system" {
  rest_api_id             = var.api_gateway_id
  resource_id             = aws_api_gateway_resource.system_id.id
  http_method             = aws_api_gateway_method.get_system.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.system_registration.invoke_arn
}

# Lambda permissions for API Gateway
resource "aws_lambda_permission" "api_gateway_register" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.system_registration.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${var.api_gateway_execution_arn}/*/*"
}

# CORS for /admin/systems
resource "aws_api_gateway_method" "systems_options" {
  rest_api_id   = var.api_gateway_id
  resource_id   = aws_api_gateway_resource.systems.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "systems_options" {
  rest_api_id = var.api_gateway_id
  resource_id = aws_api_gateway_resource.systems.id
  http_method = aws_api_gateway_method.systems_options.http_method
  type        = "MOCK"

  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

resource "aws_api_gateway_method_response" "systems_options" {
  rest_api_id = var.api_gateway_id
  resource_id = aws_api_gateway_resource.systems.id
  http_method = aws_api_gateway_method.systems_options.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}

resource "aws_api_gateway_integration_response" "systems_options" {
  rest_api_id = var.api_gateway_id
  resource_id = aws_api_gateway_resource.systems.id
  http_method = aws_api_gateway_method.systems_options.http_method
  status_code = aws_api_gateway_method_response.systems_options.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "method.response.header.Access-Control-Allow-Methods" = "'GET,POST,OPTIONS'"
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }
}
