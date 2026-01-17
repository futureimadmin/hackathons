# AWS WAF Configuration for API Gateway

# WAF Web ACL
resource "aws_wafv2_web_acl" "api_gateway" {
  count = var.enable_waf ? 1 : 0

  name  = "${var.api_name}-waf"
  scope = "REGIONAL"

  default_action {
    allow {}
  }

  # Rate limiting rule - prevent brute force attacks
  rule {
    name     = "RateLimitRule"
    priority = 1

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit              = var.waf_rate_limit
        aggregate_key_type = "IP"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.api_name}-rate-limit"
      sampled_requests_enabled   = true
    }
  }

  # AWS Managed Rules - OWASP Top 10
  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 2

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.api_name}-common-rules"
      sampled_requests_enabled   = true
    }
  }

  # AWS Managed Rules - Known Bad Inputs
  rule {
    name     = "AWSManagedRulesKnownBadInputsRuleSet"
    priority = 3

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.api_name}-bad-inputs"
      sampled_requests_enabled   = true
    }
  }

  # AWS Managed Rules - SQL Injection
  rule {
    name     = "AWSManagedRulesSQLiRuleSet"
    priority = 4

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesSQLiRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.api_name}-sqli"
      sampled_requests_enabled   = true
    }
  }

  # Geo-blocking rule (optional)
  dynamic "rule" {
    for_each = length(var.waf_blocked_countries) > 0 ? [1] : []

    content {
      name     = "GeoBlockingRule"
      priority = 5

      action {
        block {}
      }

      statement {
        geo_match_statement {
          country_codes = var.waf_blocked_countries
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "${var.api_name}-geo-blocking"
        sampled_requests_enabled   = true
      }
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.api_name}-waf"
    sampled_requests_enabled   = true
  }

  tags = var.tags
}

# Associate WAF with API Gateway stage
resource "aws_wafv2_web_acl_association" "api_gateway" {
  count = var.enable_waf ? 1 : 0

  resource_arn = aws_api_gateway_stage.main.arn
  web_acl_arn  = aws_wafv2_web_acl.api_gateway[0].arn
}

# CloudWatch log group for WAF
resource "aws_cloudwatch_log_group" "waf" {
  count = var.enable_waf ? 1 : 0

  name              = "/aws/waf/${var.api_name}"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_arn

  tags = var.tags
}

# WAF logging configuration
resource "aws_wafv2_web_acl_logging_configuration" "api_gateway" {
  count = var.enable_waf ? 1 : 0

  resource_arn            = aws_wafv2_web_acl.api_gateway[0].arn
  log_destination_configs = [aws_cloudwatch_log_group.waf[0].arn]

  redacted_fields {
    single_header {
      name = "authorization"
    }
  }
}
