# CI/CD Pipeline Auto-Trigger Setup

## Overview
Your CI/CD pipeline is configured for **full administrative access** (demo project) and **automatic triggering** on GitHub commits, with **smart self-exclusion** to prevent circular dependencies.

## Configuration Summary

### 1. **Full Administrative Permissions**
- **CodeBuild Role**: `AdministratorAccess` policy attached
- **CodePipeline Role**: `AdministratorAccess` policy attached
- **Result**: Complete access to all AWS services and resources

### 2. **Automatic Pipeline Triggering**
- **Repository**: `futureimadmin/hackathons`
- **Branch**: `master`
- **Auto-trigger**: `DetectChanges = "true"`
- **Result**: Pipeline starts automatically on every commit to master branch

### 3. **Smart Self-Exclusion** ⭐
- **Problem**: Pipeline shouldn't recreate itself when running
- **Solution**: `create_cicd_pipeline` variable controls pipeline creation
- **Local deployment**: `create_cicd_pipeline = true` (creates pipeline)
- **Pipeline execution**: `create_cicd_pipeline = false` (skips pipeline creation)
- **Result**: No circular dependencies or conflicts

## Setup Steps

### 1. Initial Local Deployment (Creates Pipeline)
```bash
cd terraform
terraform init -backend-config="backend.tfvars"
terraform plan -var-file="terraform.dev.tfvars"  # create_cicd_pipeline = true
terraform apply -var-file="terraform.dev.tfvars"
```

### 2. Complete GitHub Connection (One-time setup)
After deployment, you need to authorize the GitHub connection:

1. Go to **AWS Console** → **CodePipeline** → **Settings** → **Connections**
2. Find connection named `futureim-github-dev` (or `futureim-github-prod`)
3. Click **"Update pending connection"**
4. Authorize with your GitHub account
5. Grant access to the `futureimadmin/hackathons` repository

### 3. Test Auto-Trigger
Once the connection is authorized:
1. Make any change to your code
2. Commit and push to the `master` branch:
   ```bash
   git add .
   git commit -m "Test pipeline trigger"
   git push origin master
   ```
3. Pipeline will automatically start within 1-2 minutes

## How Self-Exclusion Works

### Local Deployment (Initial Setup)
```bash
# terraform.dev.tfvars contains:
create_cicd_pipeline = true

# This creates the CI/CD pipeline infrastructure
terraform apply -var-file="terraform.dev.tfvars"
```

### Pipeline Execution (Automatic)
```bash
# buildspecs/infrastructure-buildspec.yml automatically sets:
terraform plan -var="create_cicd_pipeline=false"

# This skips CI/CD pipeline creation, preventing circular dependency
```

### Variable Control
```hcl
# In main.tf
module "cicd_pipeline" {
  count  = var.create_cicd_pipeline ? 1 : 0  # Conditional creation
  source = "./modules/cicd-pipeline"
  # ... other configuration
}
```

## Pipeline Stages
1. **Source**: Pulls code from GitHub
2. **Infrastructure**: Deploys AWS resources via Terraform (excluding pipeline itself)
3. **BuildLambdas**: Builds Java and Python Lambda functions
4. **BuildFrontend**: Builds and deploys React frontend

## Monitoring
- **Pipeline Status**: AWS Console → CodePipeline → `futureim-ecommerce-ai-platform-pipeline-dev`
- **Build Logs**: AWS Console → CodeBuild → Build History
- **CloudWatch Logs**: Detailed logs for each build stage

## Security Note
⚠️ **Demo Configuration**: This setup uses `AdministratorAccess` for simplicity. In production, use least-privilege permissions.

## Troubleshooting
- **Pipeline not triggering**: Check GitHub connection status
- **Permission errors**: Verify AdministratorAccess policies are attached
- **Build failures**: Check CodeBuild logs in AWS Console
- **Circular dependency**: Verify `create_cicd_pipeline=false` in buildspec