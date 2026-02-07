# Lambda Container Deployment Guide

This guide explains how to deploy Lambda functions using Docker containers instead of ZIP files.

## Why Containers?

Lambda container images support up to **10GB** (vs 250MB for ZIP files), making them perfect for:
- Large dependencies (pandas, numpy, scikit-learn)
- AI/ML libraries (TensorFlow, PyTorch, XGBoost)
- Complex data processing tools

## Prerequisites

1. **Docker Desktop** installed and running
2. **AWS CLI** configured with credentials
3. **Terraform** installed

## Quick Start - Build All Lambdas

To build and push all Lambda container images (data pipeline + AI systems):

```powershell
.\build-all-lambda-containers.ps1
```

This will build:
- **Data Pipeline Lambdas** (2): raw-to-curated, curated-to-prod
- **AI Systems Lambdas** (5): compliance-guardian, demand-insights-engine, market-intelligence-hub, retail-copilot, global-market-pulse

## Deployment Steps

### Step 1: Build and Push All Container Images

```powershell
# From project root
.\build-all-lambda-containers.ps1
```

Or build individually:

```powershell
# Data Pipeline Lambdas only
cd lambda-functions
.\build-and-push-containers.ps1

# AI Systems Lambdas only
cd ai-systems
.\build-and-push-all-containers.ps1
```

### Step 2: Deploy Lambda Functions (Terraform)

Deploy the Lambda functions using the container images:

```powershell
cd terraform
terraform apply
```

## Architecture

```
Project Root/
├── lambda-functions/                    # Data Pipeline Lambdas
│   ├── raw-to-curated/
│   │   ├── Dockerfile
│   │   ├── lambda_function.py
│   │   └── requirements.txt
│   ├── curated-to-prod/
│   │   ├── Dockerfile
│   │   ├── lambda_function.py
│   │   └── requirements.txt
│   └── build-and-push-containers.ps1
│
├── ai-systems/                          # AI Systems Lambdas
│   ├── compliance-guardian/
│   │   ├── Dockerfile
│   │   ├── src/
│   │   └── requirements.txt
│   ├── demand-insights-engine/
│   │   ├── Dockerfile
│   │   ├── src/
│   │   └── requirements.txt
│   ├── market-intelligence-hub/
│   │   ├── Dockerfile
│   │   ├── src/
│   │   └── requirements.txt
│   ├── retail-copilot/
│   │   ├── Dockerfile
│   │   ├── src/
│   │   └── requirements.txt
│   ├── global-market-pulse/
│   │   ├── Dockerfile
│   │   ├── src/
│   │   └── requirements.txt
│   └── build-and-push-all-containers.ps1
│
└── build-all-lambda-containers.ps1      # Master build script
```

## Container Image Structure

Each Lambda container:
- **Base Image**: `public.ecr.aws/lambda/python:3.11`
- **Dependencies**: Installed via pip from requirements.txt
- **Function Code**: Copied to `${LAMBDA_TASK_ROOT}`
- **Handler**: Set via CMD directive

### Data Pipeline Lambdas
- Handler: `lambda_function.lambda_handler`
- Code: Single file `lambda_function.py`

### AI Systems Lambdas
- Handler: `handler.lambda_handler`
- Code: Full `src/` directory structure

## Updating Lambda Functions

To update a Lambda function:

1. **Modify code** in the function directory
2. **Rebuild and push** the container:
   ```powershell
   # All lambdas
   .\build-all-lambda-containers.ps1
   
   # Or specific system
   cd ai-systems
   docker build -t compliance-guardian compliance-guardian/
   docker tag compliance-guardian:latest 450133579764.dkr.ecr.us-east-2.amazonaws.com/futureim-ecommerce-ai-platform-compliance-guardian-dev:latest
   docker push 450133579764.dkr.ecr.us-east-2.amazonaws.com/futureim-ecommerce-ai-platform-compliance-guardian-dev:latest
   ```
3. **Update Lambda** (Lambda will automatically use the new image):
   - Lambda checks for new images periodically
   - Or force update via AWS Console or CLI

## Lambda Functions Overview

### Data Pipeline Lambdas

| Function | Purpose | Dependencies | Memory |
|----------|---------|--------------|--------|
| raw-to-curated | AI-powered data quality & transformation | pandas, numpy, scikit-learn | 3GB |
| curated-to-prod | AI analytics & system-specific processing | pandas, numpy | 3GB |

### AI Systems Lambdas

| Function | Purpose | Key Dependencies | Memory |
|----------|---------|------------------|--------|
| compliance-guardian | PCI compliance, fraud detection | transformers, torch, xgboost | 3GB |
| demand-insights-engine | Demand forecasting, customer analytics | xgboost, lightgbm, scikit-learn | 3GB |
| market-intelligence-hub | Market forecasting, trend analysis | tensorflow, prophet, statsmodels | 3GB |
| retail-copilot | Conversational AI for retail | pandas, numpy | 1GB |
| global-market-pulse | Global market analysis | scipy, statsmodels | 2GB |

## Troubleshooting

### Docker Build Fails
- Ensure Docker Desktop is running
- Check that requirements.txt is valid
- Verify network connectivity for pip installs
- For large dependencies (TensorFlow, PyTorch), build may take 10-15 minutes

### ECR Push Fails
- Verify AWS credentials: `aws sts get-caller-identity`
- Check ECR repository exists: `aws ecr describe-repositories`
- Ensure you're logged into ECR
- Check available disk space (images can be 1-2GB each)

### Lambda Function Not Updating
- Lambda automatically pulls latest image on next invocation
- To force immediate update:
  ```powershell
  aws lambda update-function-code --function-name FUNCTION_NAME --image-uri IMAGE_URI
  ```

### Out of Memory Errors
- Increase Lambda memory in Terraform configuration
- Monitor CloudWatch metrics for actual memory usage
- Consider optimizing dependencies (remove unused packages)

## Benefits of Container Approach

1. **No Size Limits**: Up to 10GB vs 250MB for ZIP
2. **Faster Deployments**: Docker layer caching speeds up rebuilds
3. **Consistent Environment**: Same image locally and in Lambda
4. **Better Dependency Management**: Full control over system packages
5. **CI/CD Friendly**: Easy integration with Docker-based pipelines
6. **Simplified Updates**: Push new image, Lambda auto-updates

## Cost Considerations

- **ECR Storage**: ~$0.10/GB/month
- **Lambda Execution**: Same pricing as ZIP-based functions
- **Data Transfer**: Free within same region

For our use case (7 images, ~500MB average):
- ECR Storage: ~$0.35/month
- Negligible compared to Lambda execution costs

## Performance Notes

- **Cold Start**: Container images have slightly longer cold starts (~1-2 seconds)
- **Warm Execution**: No performance difference vs ZIP
- **Image Caching**: Lambda caches images, subsequent invocations are fast
- **Optimization**: Use multi-stage builds to reduce image size
