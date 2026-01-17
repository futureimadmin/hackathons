# CI/CD Deployment Pipeline

## Overview

This directory contains the complete CI/CD pipeline configuration for the eCommerce AI Analytics Platform using AWS native developer tools (CodePipeline, CodeBuild, CodeDeploy).

The pipeline supports:
- **Automated builds** for dev and prod environments
- **Local deployment** capability for testing
- **Multi-stage approval** process
- **Infrastructure as Code** with Terraform integration
- **Comprehensive testing** at each stage

## Architecture

### AWS Services Used

1. **AWS CodePipeline** - Orchestrates the CI/CD workflow
2. **AWS CodeBuild** - Builds and tests the application
3. **AWS CodeDeploy** - Deploys to Lambda and other services
4. **Amazon S3** - Stores build artifacts
5. **Amazon ECR** - Stores Docker images
6. **AWS Systems Manager Parameter Store** - Stores secrets
7. **Amazon SNS** - Sends approval notifications
8. **AWS CloudFormation** - Provisions pipeline infrastructure

### Pipeline Stages

```
┌─────────────┐
│   Source    │  GitHub repository
└──────┬──────┘
       │
       ▼
┌─────────────┐
│  Build Dev  │  Build & deploy to dev
└──────┬──────┘
       │
       ▼
┌─────────────┐
│ Approve Dev │  Manual approval (optional)
└──────┬──────┘
       │
       ▼
┌─────────────┐
│ Build Prod  │  Build & deploy to prod
└──────┬──────┘
       │
       ▼
┌─────────────┐
│Approve Prod │  Manual approval & verification
└─────────────┘
```

## Files

### Pipeline Configuration

- **`pipeline-template.yml`** - CloudFormation template for pipeline infrastructure
- **`buildspec-dev.yml`** - CodeBuild specification for dev environment
- **`buildspec-prod.yml`** - CodeBuild specification for prod environment

### Deployment Scripts

- **`setup-pipeline.ps1`** - Sets up the pipeline in AWS
- **`local-deploy.ps1`** - Deploys locally (simulates pipeline)
- **`teardown-pipeline.ps1`** - Removes pipeline infrastructure

### Documentation

- **`README.md`** - This file
- **`PIPELINE_GUIDE.md`** - Detailed pipeline usage guide

## Quick Start

### Prerequisites

1. **AWS Account** with appropriate permissions
2. **AWS CLI** configured with credentials
3. **GitHub Repository** with the code
4. **GitHub Personal Access Token** with repo permissions
5. **Local Tools** (for local deployment):
   - Docker
   - Terraform
   - Python 3.9+
   - Java 17+
   - Node.js 18+
   - Maven

### Setup Pipeline in AWS

1. **Clone the repository:**
   ```bash
   git clone https://github.com/your-org/ecommerce-ai-platform.git
   cd ecommerce-ai-platform
   ```

2. **Run the setup script:**
   ```powershell
   cd deployment/deployment-pipeline
   .\setup-pipeline.ps1 `
     -GitHubRepo "your-org/ecommerce-ai-platform" `
     -GitHubToken "ghp_your_token_here" `
     -DevApprovalEmail "dev-team@example.com" `
     -ProdApprovalEmail "prod-team@example.com"
   ```

3. **Confirm SNS subscriptions:**
   - Check your email for SNS subscription confirmations
   - Click the confirmation links

4. **Push code to trigger pipeline:**
   ```bash
   git push origin main
   ```

5. **Monitor pipeline:**
   - Go to AWS Console → CodePipeline
   - Watch the pipeline execute

### Local Deployment

Deploy to dev environment locally:

```powershell
.\local-deploy.ps1 -Environment dev
```

Deploy to prod environment locally:

```powershell
.\local-deploy.ps1 -Environment prod
```

Skip tests (dev only):

```powershell
.\local-deploy.ps1 -Environment dev -SkipTests
```

Deploy only (skip build):

```powershell
.\local-deploy.ps1 -Environment dev -DeployOnly
```

## Pipeline Workflow

### Dev Environment

1. **Source Stage**
   - Triggered by GitHub push to main branch
   - Pulls latest code

2. **Build Dev Stage**
   - Runs unit tests
   - Builds Docker images
   - Builds Lambda packages
   - Builds frontend
   - Deploys to dev environment
   - Runs smoke tests

3. **Approve Dev Stage** (Optional)
   - Manual approval via SNS notification
   - Can be skipped for continuous deployment

### Prod Environment

4. **Build Prod Stage**
   - Runs comprehensive test suite
   - Runs security tests
   - Builds all artifacts
   - Creates backups
   - Deploys to prod environment

5. **Approve Prod Stage**
   - Manual approval required
   - Verification checklist
   - Sign-off from stakeholders

## Build Process

### What Gets Built

1. **Data Processing**
   - Docker image for Batch jobs
   - Pushed to ECR

2. **Lambda Functions**
   - Auth Service (Java)
   - Analytics Service (Python)
   - Market Intelligence Hub (Python)
   - Demand Insights Engine (Python)
   - Compliance Guardian (Python)
   - Retail Copilot (Python)
   - Global Market Pulse (Python)

3. **Frontend**
   - React application
   - Deployed to S3
   - CloudFront cache invalidated

4. **Infrastructure**
   - Terraform applies changes
   - Updates Lambda functions
   - Updates API Gateway
   - Updates other AWS resources

### Build Artifacts

All artifacts are stored in S3:

- **Dev:** `s3://ecommerce-ai-platform-artifacts-dev/`
- **Prod:** `s3://ecommerce-ai-platform-artifacts-prod/`

Artifacts include:
- Lambda deployment packages (.zip, .jar)
- Docker image tags
- Terraform state
- Build logs

## Environment Configuration

### Parameters Stored in SSM Parameter Store

**Dev Environment:**
- `/ecommerce-ai-platform/dev/mysql/host`
- `/ecommerce-ai-platform/dev/mysql/user`
- `/ecommerce-ai-platform/dev/mysql/password`
- `/ecommerce-ai-platform/dev/jwt/secret`

**Prod Environment:**
- `/ecommerce-ai-platform/prod/mysql/host`
- `/ecommerce-ai-platform/prod/mysql/user`
- `/ecommerce-ai-platform/prod/mysql/password`
- `/ecommerce-ai-platform/prod/jwt/secret`

### Environment Variables

Set these in your local environment for local deployment:

```powershell
$env:AWS_DEFAULT_REGION = "us-east-1"
$env:AWS_ACCOUNT_ID = "123456789012"
```

## Testing

### Tests Run in Pipeline

**Dev Environment:**
- Unit tests (pytest)
- Integration tests (basic)

**Prod Environment:**
- Comprehensive integration tests
- Security tests (OWASP ZAP, SQL injection, XSS)
- Performance tests (optional)
- Smoke tests after deployment

### Running Tests Locally

```powershell
# Integration tests
cd tests/integration
python -m pytest -v

# Security tests
cd tests/security
.\run-security-tests.ps1 -TestType all

# Performance tests
cd tests/performance
.\run-load-tests.ps1 -TestType all
```

## Monitoring

### Pipeline Monitoring

- **AWS Console:** CodePipeline dashboard
- **CloudWatch Logs:** Build logs for each stage
- **SNS Notifications:** Email alerts for approvals and failures

### Application Monitoring

After deployment, monitor:
- **CloudWatch Dashboards:** Application metrics
- **CloudWatch Alarms:** Automated alerts
- **X-Ray:** Distributed tracing
- **CloudTrail:** Audit logs

## Rollback

### Automatic Rollback

CodeDeploy automatically rolls back Lambda functions if:
- CloudWatch alarms trigger
- Deployment fails health checks

### Manual Rollback

1. **Identify previous version:**
   ```bash
   aws s3 ls s3://ecommerce-ai-platform-artifacts-prod/lambda/
   ```

2. **Redeploy previous version:**
   ```bash
   aws lambda update-function-code \
     --function-name ecommerce-ai-platform-prod-auth \
     --s3-bucket ecommerce-ai-platform-artifacts-prod \
     --s3-key lambda/auth-service-PREVIOUS_VERSION.jar
   ```

3. **Rollback infrastructure:**
   ```bash
   cd terraform
   terraform apply -var="build_version=PREVIOUS_VERSION"
   ```

## Troubleshooting

### Pipeline Fails at Build Stage

1. Check CodeBuild logs in CloudWatch
2. Verify all dependencies are installed
3. Check for test failures
4. Verify AWS credentials and permissions

### Deployment Fails

1. Check Terraform logs
2. Verify parameter store values
3. Check IAM permissions
4. Verify S3 bucket access

### Tests Fail

1. Review test output in CodeBuild logs
2. Run tests locally to reproduce
3. Check environment configuration
4. Verify test data and fixtures

### Common Issues

**Issue:** ECR push fails
**Solution:** Ensure ECR repository exists and you have push permissions

**Issue:** Terraform apply fails
**Solution:** Check Terraform state lock, verify AWS permissions

**Issue:** Lambda deployment fails
**Solution:** Verify Lambda package size (<250MB), check IAM role

**Issue:** Frontend not updating
**Solution:** Verify CloudFront invalidation, check S3 sync

## Security

### Secrets Management

- All secrets stored in AWS Systems Manager Parameter Store
- Encrypted with KMS
- Never committed to Git
- Accessed via IAM roles during build

### Access Control

- Pipeline uses IAM roles with least privilege
- Manual approvals required for production
- CloudTrail logs all actions
- MFA recommended for production approvals

### Security Scanning

- Docker images scanned by ECR
- Dependencies scanned during build
- OWASP ZAP vulnerability scanning
- SQL injection and XSS testing

## Cost Optimization

### Pipeline Costs

- **CodePipeline:** $1/month per active pipeline
- **CodeBuild:** $0.005/build minute (general1.large)
- **S3:** Storage and data transfer costs
- **ECR:** $0.10/GB/month storage

### Optimization Tips

1. Use build caching to reduce build time
2. Clean up old artifacts with lifecycle policies
3. Use spot instances for CodeBuild (if available)
4. Optimize Docker image sizes

## Maintenance

### Regular Tasks

- **Weekly:** Review pipeline execution logs
- **Monthly:** Update dependencies and base images
- **Quarterly:** Review and optimize build times
- **Annually:** Review IAM permissions and security

### Updates

To update the pipeline:

1. Modify `pipeline-template.yml`
2. Run setup script again:
   ```powershell
   .\setup-pipeline.ps1 [parameters]
   ```

## Support

### Documentation

- [AWS CodePipeline Documentation](https://docs.aws.amazon.com/codepipeline/)
- [AWS CodeBuild Documentation](https://docs.aws.amazon.com/codebuild/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)

### Getting Help

1. Check CloudWatch Logs for detailed error messages
2. Review AWS CodeBuild/CodePipeline documentation
3. Contact DevOps team
4. Open GitHub issue for pipeline problems

## Contributing

When modifying the pipeline:

1. Test changes locally first
2. Update documentation
3. Test in dev environment
4. Get approval before deploying to prod
5. Update this README with any changes

---

**Last Updated:** January 16, 2026  
**Version:** 1.0.0  
**Maintained By:** DevOps Team
