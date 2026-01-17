# DMS Configuration Guide

This guide explains how to configure AWS DMS for the eCommerce AI Analytics Platform.

## Prerequisites

1. **AWS Account** with appropriate permissions
2. **On-Premise MySQL Database** accessible from AWS (172.20.10.4:3306)
3. **VPC and Subnets** configured
4. **KMS Key** for encryption
5. **S3 Buckets** created for each system

## Step 1: Set Up Secrets

Before deploying DMS, you need to store the MySQL password in AWS Secrets Manager.

### Using PowerShell (Windows):

```powershell
cd terraform/scripts
.\setup-secrets.ps1 -Region us-east-1 -MySQLPassword "Srikar@123"
```

### Using Bash (Linux/Mac):

```bash
cd terraform/scripts
chmod +x setup-secrets.sh
./setup-secrets.sh
```

### Manual Setup:

```bash
aws secretsmanager create-secret \
    --name ecommerce/onprem-mysql-password \
    --description "On-premise MySQL root password" \
    --secret-string '{"password":"Srikar@123"}' \
    --region us-east-1
```

## Step 2: Configure Network Access

Ensure your on-premise MySQL database allows connections from AWS:

1. **Firewall Rules**: Allow inbound traffic on port 3306 from AWS VPC CIDR
2. **MySQL User Permissions**: Grant replication permissions to the root user
3. **Binary Logging**: Enable binary logging for CDC

### MySQL Configuration:

```sql
-- Enable binary logging (add to my.cnf)
[mysqld]
server-id = 1
log_bin = mysql-bin
binlog_format = ROW
binlog_row_image = FULL

-- Grant replication permissions
GRANT REPLICATION SLAVE, REPLICATION CLIENT ON *.* TO 'root'@'%';
GRANT SELECT ON *.* TO 'root'@'%';
FLUSH PRIVILEGES;
```

## Step 3: Configure Security Groups

The DMS security group is automatically created by the VPC module. Verify it allows:

- **Outbound**: Port 3306 to 172.20.10.4/32 (on-premise MySQL)
- **Outbound**: Port 443 to 0.0.0.0/0 (AWS services)

## Step 4: Define Table Mappings

Table mappings define which tables to replicate. Create a JSON file for each system:

### Example: Market Intelligence Hub

```json
{
  "rules": [
    {
      "rule-type": "selection",
      "rule-id": "1",
      "rule-name": "include-ecommerce-tables",
      "object-locator": {
        "schema-name": "ecommerce",
        "table-name": "%"
      },
      "rule-action": "include"
    },
    {
      "rule-type": "selection",
      "rule-id": "2",
      "rule-name": "include-market-intelligence-tables",
      "object-locator": {
        "schema-name": "market_intelligence_schema",
        "table-name": "%"
      },
      "rule-action": "include"
    },
    {
      "rule-type": "transformation",
      "rule-id": "3",
      "rule-name": "add-schema-prefix",
      "rule-target": "table",
      "object-locator": {
        "schema-name": "%",
        "table-name": "%"
      },
      "rule-action": "add-prefix",
      "value": "schema_",
      "old-value": null
    }
  ]
}
```

## Step 5: Deploy DMS Module

Add the DMS module to your main Terraform configuration:

```hcl
module "dms" {
  source = "./modules/dms"

  environment                  = var.environment
  project_name                 = var.project_name
  vpc_id                       = module.vpc.vpc_id
  subnet_ids                   = module.vpc.private_subnet_ids
  security_group_ids           = [module.vpc.dms_security_group_id]
  kms_key_arn                  = module.kms.key_arn
  source_password_secret_arn   = data.aws_secretsmanager_secret.mysql_password.arn

  source_endpoint_config = {
    server_name   = "172.20.10.4"
    port          = 3306
    username      = "root"
    database_name = "ecommerce"
    ssl_mode      = "require"
  }

  target_s3_buckets = {
    "market-intelligence-hub" = module.s3_data_lake["market-intelligence-hub"].raw_bucket_name
    "demand-insights-engine"  = module.s3_data_lake["demand-insights-engine"].raw_bucket_name
    "compliance-guardian"     = module.s3_data_lake["compliance-guardian"].raw_bucket_name
    "retail-copilot"          = module.s3_data_lake["retail-copilot"].raw_bucket_name
    "global-market-pulse"     = module.s3_data_lake["global-market-pulse"].raw_bucket_name
  }

  replication_tasks = [
    {
      task_id        = "market-intelligence-hub-replication"
      source_database = "ecommerce"
      target_bucket  = "market-intelligence-hub"
      migration_type = "full-load-and-cdc"
      table_mappings = file("${path.module}/table-mappings/market-intelligence-hub.json")
    },
    {
      task_id        = "demand-insights-engine-replication"
      source_database = "ecommerce"
      target_bucket  = "demand-insights-engine"
      migration_type = "full-load-and-cdc"
      table_mappings = file("${path.module}/table-mappings/demand-insights-engine.json")
    },
    {
      task_id        = "compliance-guardian-replication"
      source_database = "ecommerce"
      target_bucket  = "compliance-guardian"
      migration_type = "full-load-and-cdc"
      table_mappings = file("${path.module}/table-mappings/compliance-guardian.json")
    },
    {
      task_id        = "retail-copilot-replication"
      source_database = "ecommerce"
      target_bucket  = "retail-copilot"
      migration_type = "full-load-and-cdc"
      table_mappings = file("${path.module}/table-mappings/retail-copilot.json")
    },
    {
      task_id        = "global-market-pulse-replication"
      source_database = "ecommerce"
      target_bucket  = "global-market-pulse"
      migration_type = "full-load-and-cdc"
      table_mappings = file("${path.module}/table-mappings/global-market-pulse.json")
    }
  ]

  tags = var.tags
}

# Data source for MySQL password secret
data "aws_secretsmanager_secret" "mysql_password" {
  name = "ecommerce/onprem-mysql-password"
}
```

## Step 6: Apply Terraform

```bash
cd terraform
terraform init
terraform plan
terraform apply
```

## Step 7: Start Replication Tasks

After DMS resources are created, start the replication tasks:

```bash
# Start all replication tasks
aws dms start-replication-task \
    --replication-task-arn <task-arn> \
    --start-replication-task-type start-replication \
    --region us-east-1
```

Or use the AWS Console:
1. Navigate to AWS DMS
2. Select "Database migration tasks"
3. Select a task and click "Actions" → "Start"

## Monitoring

### CloudWatch Metrics

Monitor these key metrics:

- **CDCLatencySource**: Latency between source and DMS (should be < 10 seconds)
- **CDCLatencyTarget**: Latency between DMS and S3 (should be < 10 seconds)
- **FullLoadThroughputBandwidthTarget**: Data transfer rate
- **FullLoadThroughputRowsTarget**: Row transfer rate

### CloudWatch Logs

View logs in CloudWatch Logs:
- Log Group: `/aws/dms/ecommerce-ai-platform-{environment}`

### DMS Console

Monitor task progress in the AWS DMS Console:
1. View table statistics
2. Check error logs
3. Monitor replication lag

## Troubleshooting

### Connection Issues

**Problem**: DMS cannot connect to on-premise MySQL

**Solutions**:
1. Verify firewall rules allow traffic from AWS VPC
2. Check security group allows outbound traffic on port 3306
3. Verify MySQL user has correct permissions
4. Test connectivity from a VPC instance

### Replication Lag

**Problem**: High CDC latency

**Solutions**:
1. Increase DMS instance size
2. Optimize MySQL binary log settings
3. Reduce number of tables being replicated
4. Check network bandwidth

### Validation Errors

**Problem**: Data validation failures

**Solutions**:
1. Check for data type mismatches
2. Verify character encoding settings
3. Review transformation rules
4. Check for NULL handling issues

### Performance Issues

**Problem**: Slow full load

**Solutions**:
1. Increase `MaxFullLoadSubTasks` setting
2. Use parallel load for large tables
3. Optimize MySQL query performance
4. Increase DMS instance size

## Best Practices

1. **Start Small**: Test with a few tables before full replication
2. **Monitor Closely**: Watch CloudWatch metrics during initial load
3. **Backup First**: Backup source database before starting replication
4. **Test Failover**: Test Multi-AZ failover in non-production
5. **Regular Validation**: Enable validation to catch data discrepancies
6. **Log Retention**: Keep logs for at least 30 days
7. **Cost Optimization**: Use appropriate instance size for workload
8. **Security**: Rotate credentials every 90 days

## Migration Types

### full-load
- One-time full copy of data
- No ongoing replication
- Use for initial data migration

### cdc
- Only capture changes (requires existing data in target)
- Minimal latency
- Use after full load complete

### full-load-and-cdc
- Full copy followed by ongoing CDC
- Recommended for most use cases
- Seamless transition from full load to CDC

## Cost Considerations

DMS costs include:
- **Replication Instance**: Hourly charge based on instance type
- **Data Transfer**: Outbound data transfer charges
- **Storage**: Replication instance storage
- **CloudWatch**: Logs and metrics storage

Estimated monthly cost for `dms.c5.xlarge`:
- Instance: ~$400/month
- Data transfer: Variable based on volume
- Storage: ~$20/month for 200 GB

## Security Checklist

- [ ] MySQL password stored in Secrets Manager
- [ ] KMS encryption enabled for S3 targets
- [ ] SSL/TLS enabled for source connection
- [ ] Security groups restrict access
- [ ] IAM roles follow least-privilege
- [ ] CloudWatch logging enabled
- [ ] VPC endpoints configured for AWS services
- [ ] Multi-AZ enabled for production

## Next Steps

After DMS is configured and running:

1. **Verify Data**: Check S3 buckets for replicated data
2. **Set Up Glue Crawlers**: Catalog the data in Athena
3. **Configure EventBridge**: Trigger data processing pipelines
4. **Monitor Performance**: Set up CloudWatch alarms
5. **Document**: Record any custom configurations
