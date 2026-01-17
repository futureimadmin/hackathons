# Production Deployment Checklist

## Pre-Deployment

### Infrastructure
- [ ] Terraform state backend configured
- [ ] AWS credentials configured
- [ ] All secrets stored in Secrets Manager
- [ ] KMS keys created
- [ ] VPC and subnets configured
- [ ] Security groups configured
- [ ] IAM roles and policies created

### Code
- [ ] All code reviewed and approved
- [ ] All tests passing (unit, integration, property-based)
- [ ] Security scan completed (OWASP ZAP)
- [ ] Performance tests completed
- [ ] Documentation updated

### Database
- [ ] MySQL database set up
- [ ] Sample data generated
- [ ] Database backups configured
- [ ] DMS replication tasks created

## Deployment Steps

### 1. Deploy Infrastructure
```bash
cd terraform
terraform init
terraform plan -out=tfplan
terraform apply tfplan
```

**Verify:**
- [ ] All resources created successfully
- [ ] No errors in Terraform output
- [ ] CloudWatch dashboards visible

### 2. Deploy Docker Images
```bash
cd data-processing
./build-and-push.ps1
```

**Verify:**
- [ ] Images pushed to ECR
- [ ] Image tags correct

### 3. Deploy Lambda Functions
```bash
# Auth Service
cd auth-service
mvn clean package
aws lambda update-function-code --function-name ecommerce-ai-platform-auth --zip-file fileb://target/auth-service.jar

# Analytics Service
cd analytics-service
./build.ps1

# AI Systems
cd ai-systems/market-intelligence-hub
./build.ps1
# Repeat for all AI systems
```

**Verify:**
- [ ] All Lambda functions updated
- [ ] Function versions incremented
- [ ] Test invocations successful

### 4. Deploy Frontend
```bash
cd frontend
npm install
npm run build
aws s3 sync dist/ s3://ecommerce-ai-platform-frontend/
aws cloudfront create-invalidation --distribution-id <id> --paths "/*"
```

**Verify:**
- [ ] Files uploaded to S3
- [ ] CloudFront invalidation complete
- [ ] Frontend accessible

### 5. Start DMS Replication
```bash
aws dms start-replication-task \
  --replication-task-arn <arn> \
  --start-replication-task-type start-replication
```

**Verify:**
- [ ] Replication task running
- [ ] Data appearing in S3 raw bucket
- [ ] No errors in CloudWatch logs

### 6. Run Glue Crawlers
```bash
aws glue start-crawler --name ecommerce-ai-platform-crawler
```

**Verify:**
- [ ] Crawler completed successfully
- [ ] Tables created in Glue catalog
- [ ] Athena can query tables

## Post-Deployment

### Verification
- [ ] Run integration tests
- [ ] Test authentication flow
- [ ] Test all AI systems
- [ ] Verify data pipeline
- [ ] Check CloudWatch metrics
- [ ] Review CloudWatch logs

### Monitoring
- [ ] CloudWatch dashboards configured
- [ ] CloudWatch alarms set up
- [ ] SNS notifications configured
- [ ] CloudTrail enabled
- [ ] Log retention policies set

### Security
- [ ] Security scan passed
- [ ] All data encrypted
- [ ] WAF rules active
- [ ] Security groups locked down
- [ ] IAM policies reviewed

### Documentation
- [ ] Deployment documented
- [ ] API endpoints documented
- [ ] User guide updated
- [ ] Troubleshooting guide updated
- [ ] Runbook created

### Communication
- [ ] Stakeholders notified
- [ ] Users trained
- [ ] Support team briefed
- [ ] On-call schedule set

## Rollback Plan

If deployment fails:

1. **Stop traffic:** Update Route53 to point to previous version
2. **Rollback code:** Revert Lambda functions to previous versions
3. **Rollback infrastructure:** `terraform apply` with previous state
4. **Notify stakeholders:** Send rollback notification
5. **Investigate:** Review logs and identify root cause

## Success Criteria

- [ ] All services responding
- [ ] No errors in logs
- [ ] Performance within SLAs
- [ ] Security tests passing
- [ ] Users can access system
- [ ] Data pipeline functioning
- [ ] Monitoring active

## Sign-Off

- [ ] Technical Lead: _________________ Date: _______
- [ ] Security Lead: _________________ Date: _______
- [ ] Product Owner: _________________ Date: _______

## Notes

Document any issues or deviations:

---
