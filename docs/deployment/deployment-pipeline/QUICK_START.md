# CI/CD Pipeline - Quick Start Guide

## 🚀 5-Minute Setup

### Prerequisites Checklist

- [ ] AWS Account with admin access
- [ ] AWS CLI installed and configured
- [ ] GitHub repository
- [ ] GitHub personal access token
- [ ] Email addresses for approvals

### Step 1: Setup Pipeline (2 minutes)

```powershell
cd deployment/deployment-pipeline

.\setup-pipeline.ps1 `
  -GitHubRepo "your-org/ecommerce-ai-platform" `
  -GitHubToken "ghp_xxxxxxxxxxxxx" `
  -DevApprovalEmail "dev@example.com" `
  -ProdApprovalEmail "prod@example.com"
```

**What it does:**
- Creates ECR repository
- Creates S3 buckets
- Stores secrets in Parameter Store
- Deploys CloudFormation stack
- Sets up CodePipeline

### Step 2: Confirm Email Subscriptions (1 minute)

1. Check your email (dev and prod addresses)
2. Click "Confirm subscription" links
3. Done!

### Step 3: Trigger Pipeline (1 minute)

```bash
git push origin main
```

**Pipeline will:**
1. Pull code from GitHub
2. Build and test
3. Deploy to dev
4. Wait for approval
5. Deploy to prod

### Step 4: Monitor (1 minute)

Go to: https://console.aws.amazon.com/codesuite/codepipeline/pipelines

Watch your pipeline execute!

---

## 🏠 Local Deployment

### Deploy to Dev

```powershell
.\local-deploy.ps1 -Environment dev
```

### Deploy to Prod

```powershell
.\local-deploy.ps1 -Environment prod
```

### Skip Tests (Dev Only)

```powershell
.\local-deploy.ps1 -Environment dev -SkipTests
```

---

## 📊 Pipeline Stages

```
Source → Build Dev → Approve Dev → Build Prod → Approve Prod
  ↓         ↓           ↓             ↓            ↓
GitHub   Deploy to   Manual      Deploy to    Manual
         Dev         Review      Prod         Review
```

---

## 🔧 Common Commands

### View Pipeline Status
```bash
aws codepipeline get-pipeline-state --name ecommerce-ai-platform-pipeline
```

### View Build Logs
```bash
aws logs tail /aws/codebuild/ecommerce-ai-platform-dev-build --follow
```

### List Artifacts
```bash
aws s3 ls s3://ecommerce-ai-platform-artifacts-dev/lambda/
```

### View Parameters
```bash
aws ssm get-parameters-by-path --path /ecommerce-ai-platform/dev/
```

---

## 🛑 Teardown

### Remove Everything
```powershell
.\teardown-pipeline.ps1
```

### Keep Artifacts
```powershell
.\teardown-pipeline.ps1 -KeepArtifacts -KeepECR -KeepParameters
```

---

## 🆘 Troubleshooting

### Pipeline Fails

1. **Check logs:**
   ```bash
   aws logs tail /aws/codebuild/ecommerce-ai-platform-dev-build
   ```

2. **Check pipeline:**
   - Go to AWS Console → CodePipeline
   - Click on failed stage
   - View details

3. **Common fixes:**
   - Verify AWS credentials
   - Check parameter store values
   - Ensure ECR repository exists
   - Verify IAM permissions

### Build Fails Locally

1. **Check prerequisites:**
   ```powershell
   docker --version
   terraform --version
   python --version
   java -version
   node --version
   ```

2. **Check AWS credentials:**
   ```bash
   aws sts get-caller-identity
   ```

3. **Run tests manually:**
   ```powershell
   cd tests/integration
   python -m pytest -v
   ```

---

## 📚 More Information

- **Full Documentation:** See `README.md`
- **Pipeline Details:** See `PIPELINE_SUMMARY.md`
- **AWS Console:** https://console.aws.amazon.com/codesuite/codepipeline/

---

## ✅ Success Checklist

After setup, verify:

- [ ] Pipeline appears in AWS Console
- [ ] Email subscriptions confirmed
- [ ] First build completes successfully
- [ ] Dev environment deployed
- [ ] Prod approval received
- [ ] Prod environment deployed
- [ ] Application accessible

---

## 🎯 Next Steps

1. **Customize buildspecs** for your needs
2. **Add more tests** to pipeline
3. **Configure monitoring** dashboards
4. **Set up alerts** for failures
5. **Document** your deployment process

---

**Need Help?**
- Check `README.md` for detailed guide
- Review CloudWatch Logs
- Contact DevOps team

**Happy Deploying! 🚀**
