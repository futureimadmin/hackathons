# Outputs for API Gateway Module

output "api_id" {
  description = "ID of the API Gateway REST API"
  value       = aws_api_gateway_rest_api.main.id
}

output "api_arn" {
  description = "ARN of the API Gateway REST API"
  value       = aws_api_gateway_rest_api.main.arn
}

output "api_endpoint" {
  description = "Base URL of the API Gateway"
  value       = aws_api_gateway_stage.main.invoke_url
}

output "api_stage_name" {
  description = "Name of the API Gateway stage"
  value       = aws_api_gateway_stage.main.stage_name
}

output "authorizer_id" {
  description = "ID of the JWT authorizer"
  value       = aws_api_gateway_authorizer.jwt.id
}

output "authorizer_arn" {
  description = "ARN of the authorizer Lambda function"
  value       = aws_lambda_function.authorizer.arn
}

output "usage_plan_id" {
  description = "ID of the API Gateway usage plan"
  value       = aws_api_gateway_usage_plan.main.id
}

output "waf_web_acl_id" {
  description = "ID of the WAF Web ACL"
  value       = var.enable_waf ? aws_wafv2_web_acl.api_gateway[0].id : null
}

output "waf_web_acl_arn" {
  description = "ARN of the WAF Web ACL"
  value       = var.enable_waf ? aws_wafv2_web_acl.api_gateway[0].arn : null
}

output "api_endpoints" {
  description = "Map of API endpoints"
  value = {
    register        = "${aws_api_gateway_stage.main.invoke_url}/auth/register"
    login           = "${aws_api_gateway_stage.main.invoke_url}/auth/login"
    forgot_password = "${aws_api_gateway_stage.main.invoke_url}/auth/forgot-password"
    reset_password  = "${aws_api_gateway_stage.main.invoke_url}/auth/reset-password"
    verify          = "${aws_api_gateway_stage.main.invoke_url}/auth/verify"
  }
}
