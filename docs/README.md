# FutureIM eCommerce AI Platform - Documentation

## Quick Start

1. **[Deployment Workflow](DEPLOYMENT_WORKFLOW.md)** - Start here! Explains what to run and when
2. **[FutureIM Prefix Applied](FUTUREIM_PREFIX_APPLIED.md)** - Resource naming conventions
3. **[AWS Region Configuration](AWS_REGION_CHANGED_TO_US_EAST_2.md)** - Region setup (us-east-2)

## Setup Guides

### Infrastructure
- [Terraform Backend Region Fix](TERRAFORM_BACKEND_REGION_FIX.md)
- [Architecture Diagram](ARCHITECTURE_DIAGRAM.md)
- [Monitoring Setup Guide](MONITORING_SETUP_GUIDE.md)

### Database
- [MySQL Connection Setup](deployment/mysql-connection-setup.md)
- [MySQL Connection Troubleshooting](deployment/MYSQL_CONNECTION_TROUBLESHOOTING.md)
- [MySQL IP Configuration](MYSQL_IP_CONFIGURATION_COMPLETE.md)
- [MySQL IP Configuration Steps](deployment/MYSQL_IP_CONFIGURATION_STEPS.md)
- [Configure MySQL IP Access](deployment/CONFIGURE_MYSQL_IP_ACCESS.md)
- [MySQL JWT Setup](MYSQL_JWT_SETUP_COMPLETE.md)
- [MySQL JWT Configuration Summary](deployment/MYSQL_JWT_CONFIGURATION_SUMMARY.md)
- [MySQL Connection Issues Resolved](MYSQL_CONNECTION_ISSUE_RESOLVED.md)
- [MySQL User Fix](MYSQL_USER_FIX.md)
- [MySQL Localhost Fix](MYSQL_LOCALHOST_FIX.md)
- [MySQL Hanging Fix](MYSQL_HANGING_FIX.md)
- [Configure MySQL Skip](CONFIGURE_MYSQL_SKIP.md)

### Deployment
- [Deployment Workflow](DEPLOYMENT_WORKFLOW.md) - **START HERE**
- [Step by Step Guide](deployment/STEP_BY_STEP_GUIDE.md)
- [Deployment Ready](DEPLOYMENT_READY.md)
- [Deployment Ready Localhost](DEPLOYMENT_READY_LOCALHOST.md)
- [Deployment Script Fixed](DEPLOYMENT_SCRIPT_FIXED.md)
- [Deployment Script Final Fixes](DEPLOYMENT_SCRIPT_FINAL_FIXES.md)
- [Deployment Path Fixes](DEPLOYMENT_PATH_FIXES.md)
- [Infrastructure Deployment Guide](deployment/INFRASTRUCTURE_DEPLOYMENT_GUIDE.md)
- [Production Deployment Checklist](deployment/PRODUCTION_DEPLOYMENT_CHECKLIST.md)
- [CI/CD Implementation Summary](deployment/CICD_IMPLEMENTATION_SUMMARY.md)

#### Deployment Pipeline
- [Pipeline Summary](deployment/deployment-pipeline/PIPELINE_SUMMARY.md)
- [Pipeline Quick Start](deployment/deployment-pipeline/QUICK_START.md)
- [Pipeline README](deployment/deployment-pipeline/README.md)

## Troubleshooting

### Common Issues
- [All Path Fixes Summary](ALL_PATH_FIXES_SUMMARY.md)
- [Path Issues Fix](PATH_ISSUES_FIX.md)
- [Syntax Error Fix](SYNTAX_ERROR_FIX.md)
- [Insert Ignore Fix](INSERT_IGNORE_FIX.md)
- [Clear PowerShell Cache](CLEAR_POWERSHELL_CACHE.md)

### Task Summaries
- [Task 15 Verification Guide](TASK_15_VERIFICATION_GUIDE.md)
- [Task 17 Summary](TASK_17_SUMMARY.md)
- [Task 18 Summary](TASK_18_SUMMARY.md)
- [Task 19 Summary](TASK_19_SUMMARY.md)
- [Task 20 Summary](TASK_20_SUMMARY.md)
- [Task 21 Summary](TASK_21_SUMMARY.md)
- [Task 22 Summary](TASK_22_SUMMARY.md)
- [Task 22 Verification Guide](TASK_22_VERIFICATION_GUIDE.md)
- [Task 23 Summary](TASK_23_SUMMARY.md)
- [Task 24 Summary](TASK_24_SUMMARY.md)
- [Task 25 Summary](TASK_25_SUMMARY.md)
- [Task 26 Summary](TASK_26_SUMMARY.md)
- [Task 27 Summary](TASK_27_SUMMARY.md)
- [Task 28-30 Summary](TASK_28_29_30_SUMMARY.md)

## Project Status
- [Project Complete](PROJECT_COMPLETE.md)
- [Project Status](PROJECT_STATUS.md)
- [Folder Reorganization Summary](FOLDER_REORGANIZATION_SUMMARY.md)

## Configuration Reference

### Resource Naming
All resources use the prefix: `futureim-ecommerce-ai-platform`

### AWS Configuration
- **Region:** us-east-2 (Ohio)
- **Account:** 450133579764
- **Environment:** dev

### MySQL Configuration
- **Host:** 172.20.10.4
- **Port:** 3306
- **User:** dms_remote
- **Database:** ecommerce

### SSM Parameter Paths
- `/futureim-ecommerce-ai-platform/dev/mysql/*`
- `/futureim-ecommerce-ai-platform/dev/jwt/secret`
- `/futureim-ecommerce-ai-platform/dev/dms/mysql/*`

## Getting Help

If you encounter issues:
1. Check the [Deployment Workflow](DEPLOYMENT_WORKFLOW.md) guide
2. Review relevant troubleshooting docs above
3. Check CloudWatch logs for service errors
4. Verify AWS credentials and permissions
