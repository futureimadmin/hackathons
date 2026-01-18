# Deployment Checklist

## ✅ Pre-Deployment (Complete)

- [x] Fixed API Gateway deployment errors
- [x] Fixed Lambda integration URIs
- [x] Fixed CloudWatch Logs role
- [x] Created CI/CD pipeline with GitHub integration
- [x] Fixed CodeStar connection name length
- [x] Added KMS permissions to CodePipeline role
- [x] Added DMS module to Terraform
- [x] Fixed DMS security group reference
- [x] Fixed DMS IAM policy (flatten function)
- [x] Made MySQL secret optional
- [x] Upgraded CodePipeline to V2
- [x] Enabled pipeline auto-trigger

## 📋 Your Action Items

### 1. Create DMS VPC Role
```powershell
cd terraform
.\create-dms-vpc-role.ps1
```
- [ ] Script executed successfully
- [ ] Role `dms-vpc-role` created
- [ ] Policy attached

### 2. Create MySQL Secret
```powershell
.\create-mysql-secret.ps1
```
- [ ] Script executed successfully
- [ ] Secret ARN copied
- [ ] ARN added to `terraform.dev.tfvars`

### 3. Deploy Infrastructure
```powershell
terraform apply -var-file="terraform.dev.tfvars"
```
- [ ] Terraform plan reviewed
- [ ] Typed `yes` to confirm
- [ ] Deployment completed successfully

## 🚀 Post-Deployment

### 4. Activate GitHub Connection
- [ ] Go to AWS Console → Developer Tools → Connections
- [ ] Find connection: `futureim-github-dev`
- [ ] Click "Update pending connection"
- [ ] Authorize GitHub access
- [ ] Connection status = AVAILABLE

### 5. Test Pipeline Auto-Trigger
```powershell
git add .
git commit -m "Test pipeline"
git push origin master
```
- [ ] Code pushed to GitHub
- [ ] Pipeline started automatically (within 1-2 min)
- [ ] All stages completed successfully

### 6. Start DMS Replication Tasks
- [ ] Go to AWS Console → DMS → Database migration tasks
- [ ] Start task: `compliance-guardian-replication`
- [ ] Start task: `demand-insights-replication`
- [ ] Start task: `global-market-pulse-replication`
- [ ] Start task: `market-intelligence-replication`
- [ ] Start task: `retail-copilot-replication`

### 7. Verify Data Replication
- [ ] Check S3 buckets for data files
- [ ] Run Glue Crawlers
- [ ] Query data in Athena

## 📊 Expected Results

### DMS Resources Created
- 1 Replication instance
- 1 Source endpoint (MySQL)
- 5 Target endpoints (S3)
- 5 Replication tasks

### CI/CD Pipeline
- Type: V2
- Auto-trigger: Enabled
- Stages: Source → Infrastructure → Build Lambdas → Build Frontend

### S3 Buckets
- Pipeline artifacts bucket
- Frontend hosting bucket
- 5 AI system data buckets

## 🔍 Verification Commands

```powershell
# Check DMS resources
terraform output dms_replication_instance_id
terraform output dms_source_endpoint_arn
terraform output dms_target_endpoint_arns

# Check pipeline type
aws codepipeline get-pipeline --name futureim-ecommerce-ai-platform-pipeline-dev --query 'metadata.pipelineType'

# Check GitHub connection
aws codestar-connections list-connections --query 'Connections[?ConnectionName==`futureim-github-dev`]'

# List DMS tasks
aws dms describe-replication-tasks --query 'ReplicationTasks[].{ID:ReplicationTaskIdentifier,Status:Status}'
```

## 📝 Configuration Files

### terraform.dev.tfvars (Required)
```hcl
aws_region   = "us-east-2"
environment  = "dev"
project_name = "futureim-ecommerce-ai-platform"
vpc_cidr     = "10.0.0.0/16"

github_repo   = "futureimadmin/hackathons"
github_branch = "master"
github_token  = "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"

# ADD THIS LINE after running create-mysql-secret.ps1
mysql_password_secret_arn = "arn:aws:secretsmanager:us-east-2:450133579764:secret:futureim-ecommerce-ai-platform-mysql-password-dev-XXXXXX"
```

## 🆘 Support

If you encounter issues:

1. Check `FIX_DMS_AND_PIPELINE.md` for detailed troubleshooting
2. Check `QUICK_FIX_DMS_PIPELINE.md` for quick reference
3. Review Terraform error messages carefully
4. Check AWS CloudWatch Logs for pipeline/DMS errors

## 📈 Timeline

- Step 1-2: ~2 minutes
- Step 3: ~20 minutes
- Step 4-5: ~5 minutes
- Step 6-7: ~30 minutes (data replication time varies)

**Total**: ~1 hour

---

**Current Status**: Ready for deployment
**Next Step**: Run `create-dms-vpc-role.ps1`
