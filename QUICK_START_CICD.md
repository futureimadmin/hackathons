# Quick Start - CI/CD Pipeline

## 🚀 Deploy in 3 Commands

### DEV Environment
```powershell
cd terraform
terraform init
terraform apply -var-file="terraform.dev.tfvars"
```

### PROD Environment
```powershell
terraform apply -var-file="terraform.prod.tfvars"
```

## ⚠️ Important: Approve GitHub Connection

After first deployment:
1. AWS Console → Developer Tools → Connections
2. Click "Update pending connection"
3. Authorize GitHub

## 📋 What Gets Deployed

### Infrastructure (Terraform)
- VPC with public/private subnets
- API Gateway (60+ endpoints)
- DynamoDB users table
- S3 buckets (data lakes + frontend)
- KMS encryption keys
- IAM roles

### CI/CD Pipeline
- CodePipeline (4 stages)
- CodeBuild projects (4)
- GitHub integration
- Automatic triggers on commit

### Lambda Functions (via Pipeline)
- Auth Service (Java)
- Analytics Service (Python)
- Market Intelligence Hub (Python)
- Demand Insights Engine (Python)
- Compliance Guardian (Python)
- Retail Copilot (Python)
- Global Market Pulse (Python)

### Frontend (via Pipeline)
- React app built and deployed to S3
- Static website hosting enabled
- Automatic API URL configuration

## 🔄 Pipeline Flow

```
Commit to master
    ↓
Source (GitHub)
    ↓
Infrastructure (Terraform)
    ↓
Build Lambdas (Java + Python in parallel)
    ↓
Build Frontend (React + Deploy to S3)
    ↓
✅ Complete
```

## 📊 Outputs

```powershell
terraform output api_gateway_url
terraform output frontend_website_url
terraform output pipeline_url
```

## 🔍 Monitor Pipeline

```powershell
# Get pipeline URL
terraform output pipeline_url

# Or go to AWS Console
# CodePipeline → futureim-ecommerce-ai-platform-pipeline-dev
```

## 📚 Documentation

- **Complete Guide**: `terraform/CICD_DEPLOYMENT_GUIDE.md`
- **Checklist**: `terraform/DEPLOYMENT_CHECKLIST.md`
- **Setup Summary**: `CICD_SETUP_COMPLETE.md`

## 🎯 Key Features

✅ Automatic deployment on commit
✅ Parallel Lambda builds
✅ Dynamic API URL injection
✅ Environment separation (DEV/PROD)
✅ Secure secret management
✅ Full Terraform automation

## 💰 Cost

~$5-10/month per environment (excluding usage-based charges)

## 🆘 Troubleshooting

**GitHub connection pending?**
→ Approve in AWS Console

**Build failing?**
→ Check CloudWatch Logs in CodeBuild

**Lambda not created?**
→ Verify Infrastructure stage completed

**Frontend not loading?**
→ Check S3 bucket policy and website configuration

---

**Ready?** Run: `terraform apply -var-file="terraform.dev.tfvars"`
