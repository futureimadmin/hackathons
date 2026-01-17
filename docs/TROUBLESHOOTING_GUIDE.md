# Troubleshooting Guide

## Common Issues

### 1. Authentication Failed

**Symptom:** 401 Unauthorized error

**Solutions:**
- Verify credentials are correct
- Check if user exists in DynamoDB
- Verify JWT token hasn't expired (1-hour expiry)
- Check API Gateway authorizer configuration

### 2. DMS Replication Lag

**Symptom:** Data not appearing in S3 within expected time

**Solutions:**
- Check DMS task status: `aws dms describe-replication-tasks`
- Verify MySQL connectivity
- Check DMS instance size (upgrade if needed)
- Review CloudWatch logs for errors

### 3. Lambda Timeout

**Symptom:** Lambda function times out

**Solutions:**
- Increase timeout setting (max 15 minutes)
- Increase memory allocation (more memory = more CPU)
- Optimize code for performance
- Check for infinite loops or blocking operations

### 4. Athena Query Slow

**Symptom:** Queries take too long

**Solutions:**
- Implement partitioning
- Use Parquet format
- Optimize query (use column projection, LIMIT)
- Check data scanned (should be < 1GB per query)

### 5. Frontend Not Loading

**Symptom:** Blank page or errors

**Solutions:**
- Check browser console for errors
- Verify S3 bucket is public (or CloudFront configured)
- Check CORS configuration
- Verify API endpoint is correct

### 6. High API Gateway Latency

**Symptom:** Slow API responses

**Solutions:**
- Enable API Gateway caching
- Increase Lambda memory
- Implement application-level caching (Redis)
- Check Lambda cold starts (use provisioned concurrency)

### 7. Data Pipeline Failures

**Symptom:** Batch jobs failing

**Solutions:**
- Check CloudWatch logs
- Verify S3 bucket permissions
- Check Docker image is correct
- Increase Batch job resources

### 8. Out of Memory Errors

**Symptom:** Lambda or Batch jobs crash

**Solutions:**
- Increase memory allocation
- Process data in smaller batches
- Optimize data structures
- Use streaming instead of loading all data

### 9. Permission Denied

**Symptom:** IAM permission errors

**Solutions:**
- Check IAM role policies
- Verify resource-based policies
- Check security group rules
- Review VPC configuration

### 10. Cost Overruns

**Symptom:** Unexpected AWS costs

**Solutions:**
- Check CloudWatch metrics for usage
- Implement cost allocation tags
- Set up billing alarms
- Optimize Athena queries (reduce data scanned)
- Use reserved capacity for predictable workloads

## Monitoring

### CloudWatch Dashboards

Access dashboards:
1. Data Pipeline Dashboard
2. API Performance Dashboard
3. ML Model Performance Dashboard

### CloudWatch Alarms

Check alarms for:
- DMS replication lag
- Lambda errors
- API Gateway 5xx errors
- Batch job failures

### Logs

View logs in CloudWatch Logs:
- `/aws/lambda/ecommerce-ai-platform-*`
- `/aws/batch/job`
- `/aws/dms/tasks`

## Incident Response

### Severity Levels

- **Critical:** System down, data loss
- **High:** Major functionality broken
- **Medium:** Minor functionality issues
- **Low:** Cosmetic issues

### Response Procedures

1. **Identify:** Determine severity and impact
2. **Contain:** Prevent further damage
3. **Investigate:** Find root cause
4. **Resolve:** Fix the issue
5. **Document:** Record incident and resolution
6. **Review:** Post-mortem analysis

## Support Contacts

- **Technical Support:** support@example.com
- **Security Issues:** security@example.com
- **On-Call:** +1-555-0123

## Useful Commands

```bash
# Check Lambda logs
aws logs tail /aws/lambda/ecommerce-ai-platform-auth --follow

# Check DMS task status
aws dms describe-replication-tasks

# Check Batch job status
aws batch describe-jobs --jobs <job-id>

# Check S3 bucket size
aws s3 ls s3://ecommerce-ai-platform-raw --recursive --summarize

# Check Athena query status
aws athena get-query-execution --query-execution-id <query-id>
```
