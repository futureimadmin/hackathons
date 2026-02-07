# Script Cleanup Analysis

## Scripts to KEEP

### Database Folder (Essential)
- `quick-data-pipeline.ps1` - Main script to export and upload data
- `run-glue-crawlers.ps1` - Triggers Glue Crawlers to create Athena tables
- `setup-database.ps1` - Sets up MySQL database schema

### Terraform Folder (Essential)
- `create-backend-resources.ps1` - Creates S3 backend and DynamoDB table for Terraform state
- `create-mysql-secret.ps1` - Creates MySQL password secret in Secrets Manager
- `create-dms-vpc-role.ps1` - Creates DMS VPC role (AWS requirement)

## Scripts to DELETE

### Database Folder (Obsolete)
- `check-mysql-bind-address.ps1` - Diagnostic script, not needed for production
- `check-pipeline-status.ps1` - Was for Batch pipeline, now using Lambda
- `convert-csv-to-parquet.ps1` - Integrated into quick-data-pipeline.ps1
- `enable-eventbridge-notifications.ps1` - Not needed, S3 notifications configured in Terraform
- `enable-eventbridge-on-raw-bucket.ps1` - Duplicate/obsolete
- `export-and-upload-to-s3.ps1` - Replaced by quick-data-pipeline.ps1
- `manual-pipeline-trigger.ps1` - Was for Batch jobs, now automatic with Lambda

### Terraform Folder (Obsolete)
- `clean-terraform-state.ps1` - One-time cleanup script, no longer needed
- `complete-ssh-tunnel-setup.ps1` - SSH tunnel not used (using direct connection)
- `configure-dms-agent.ps1` - DMS agent not used
- `create-key.py` - Key creation handled differently
- `delete-old-buckets.ps1` - One-time cleanup, buckets already deleted
- `empty-old-buckets.ps1` - One-time cleanup, buckets already deleted
- `fix-batch-compute-environment.ps1` - Batch no longer used
- `fix-key-format.ps1` - One-time fix script
- `recreate-bastion.ps1` - Bastion not used
- `recreate-key.ps1` - Key recreation not needed
- `setup-dms-agent.ps1` - DMS agent not used
- `setup-ssh-tunnel.ps1` - SSH tunnel not used
- `start-ssh-tunnel.ps1` - SSH tunnel not used

## Summary
- Keep: 6 scripts (3 database + 3 terraform)
- Delete: 19 scripts (7 database + 12 terraform)
