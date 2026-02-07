# Development Environment Variables

aws_region   = "us-east-2"
environment  = "dev"
project_name = "futureim-ecommerce-ai-platform"
vpc_cidr     = "10.0.0.0/16"

# GitHub Configuration
github_repo   = "futureimadmin/hackathons"
github_branch = "master"
github_token  = "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"

# CI/CD Pipeline Control
create_cicd_pipeline = true  # Set to true for local deployment, false for pipeline execution

# MySQL Configuration
mysql_server_ip           = "172.20.10.2"
mysql_port                = 3306
mysql_database            = "ecommerce"
mysql_username            = "dms_remote"
mysql_password_secret_arn = "arn:aws:secretsmanager:us-east-2:450133579764:secret:futureim-ecommerce-ai-platform-mysql-password-dev-EynmXx"

# DMS Replication Tasks
dms_replication_tasks = [
  {
    task_id         = "market-intelligence-hub-replication"
    source_database = "ecommerce"
    target_bucket   = "market-intelligence-hub"
    migration_type  = "full-load-and-cdc"
    table_mappings  = "{\"rules\":[{\"rule-type\":\"selection\",\"rule-id\":\"1\",\"rule-name\":\"1\",\"object-locator\":{\"schema-name\":\"ecommerce\",\"table-name\":\"%\"},\"rule-action\":\"include\"}]}"
  },
  {
    task_id         = "demand-insights-engine-replication"
    source_database = "ecommerce"
    target_bucket   = "demand-insights-engine"
    migration_type  = "full-load-and-cdc"
    table_mappings  = "{\"rules\":[{\"rule-type\":\"selection\",\"rule-id\":\"1\",\"rule-name\":\"1\",\"object-locator\":{\"schema-name\":\"ecommerce\",\"table-name\":\"%\"},\"rule-action\":\"include\"}]}"
  },
  {
    task_id         = "compliance-guardian-replication"
    source_database = "ecommerce"
    target_bucket   = "compliance-guardian"
    migration_type  = "full-load-and-cdc"
    table_mappings  = "{\"rules\":[{\"rule-type\":\"selection\",\"rule-id\":\"1\",\"rule-name\":\"1\",\"object-locator\":{\"schema-name\":\"ecommerce\",\"table-name\":\"%\"},\"rule-action\":\"include\"}]}"
  },
  {
    task_id         = "retail-copilot-replication"
    source_database = "ecommerce"
    target_bucket   = "retail-copilot"
    migration_type  = "full-load-and-cdc"
    table_mappings  = "{\"rules\":[{\"rule-type\":\"selection\",\"rule-id\":\"1\",\"rule-name\":\"1\",\"object-locator\":{\"schema-name\":\"ecommerce\",\"table-name\":\"%\"},\"rule-action\":\"include\"}]}"
  },
  {
    task_id         = "global-market-pulse-replication"
    source_database = "ecommerce"
    target_bucket   = "global-market-pulse"
    migration_type  = "full-load-and-cdc"
    table_mappings  = "{\"rules\":[{\"rule-type\":\"selection\",\"rule-id\":\"1\",\"rule-name\":\"1\",\"object-locator\":{\"schema-name\":\"ecommerce\",\"table-name\":\"%\"},\"rule-action\":\"include\"}]}"
  }
]
