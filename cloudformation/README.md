# eCommerce AI Platform - CloudFormation Stack Management

## Overview

This CloudFormation approach provides **complete stack management** for the eCommerce AI Platform, allowing you to create and delete the entire environment as a single unit. This solves the resource cleanup issues you experienced with Terraform.

## 🎯 **Benefits of CloudFormation Stack Approach**

### ✅ **Complete Resource Management**
- **Single Stack**: All resources managed as one unit
- **Clean Deletion**: Delete stack = delete ALL resources
- **No Orphaned Resources**: CloudFormation tracks everything
- **Dependency Management**: Automatic resource ordering

### ✅ **Easy Environment Recreation**
- **One Command Deploy**: Create entire environment
- **One Command Delete**: Remove entire environment
- **Consistent State**: No state file issues
- **Rollback Support**: Automatic rollback on failures

### ✅ **Better Resource Tracking**
- **Visual Console**: See all resources in AWS Console
- **Status Monitoring**: Real-time deployment status
- **Event History**: Complete audit trail
- **Cost Tracking**: Stack-level cost allocation

### ✅ **Eliminates Terraform Prerequisites**
- **No Manual Scripts**: All prerequisites included in stack
- **S3 Backend**: Terraform state bucket created automatically
- **DynamoDB Locks**: State locking table created automatically
- **DMS VPC Role**: Required IAM role created automatically
- **MySQL Secret**: Password stored securely in Secrets Manager
- **One-Step Deployment**: No need for separate prerequisite scripts

## 📁 **File Structure**

```
cloudformation/
├── ecommerce-ai-platform-stack.yaml    # Main CloudFormation template
├── deploy-stack.ps1                     # Deployment script
├── delete-stack.ps1                     # Deletion script
├── stack-status.ps1                     # Status checking script
└── README.md                            # This file
```

## 🚀 **Quick Start**

### 1. **Deploy Complete Environment**

```powershell
# Deploy dev environment
.\cloudformation\deploy-stack.ps1 -Environment dev -GitHubToken "your_github_token"

# Deploy prod environment
.\cloudformation\deploy-stack.ps1 -Environment prod -GitHubToken "your_github_token"
```

### 2. **Check Stack Status**

```powershell
# Basic status
.\cloudformation\stack-status.ps1 -Environment dev

# Detailed status with resources and events
.\cloudformation\stack-status.ps1 -Environment dev -Detailed
```

### 3. **Delete Complete Environment**

```powershell
# Delete with confirmation prompt
.\cloudformation\delete-stack.ps1 -Environment dev

# Force delete without confirmation
.\cloudformation\delete-stack.ps1 -Environment dev -Force
```

## 📋 **What Gets Created**

### **Core Infrastructure**
- ✅ **VPC** with public/private subnets across 2 AZs
- ✅ **Internet Gateway** and **NAT Gateway**
- ✅ **Route Tables** and **Security Groups**
- ✅ **KMS Key** for encryption

### **Storage & Database**
- ✅ **DynamoDB Users Table** with GSI and encryption
- ✅ **S3 Frontend Bucket** with website hosting
- ✅ **S3 Terraform State Bucket** with versioning
- ✅ **DynamoDB Terraform Locks Table**

### **IAM & Security**
- ✅ **Lambda Execution Role** with required permissions
- ✅ **KMS Key Policies** for service access
- ✅ **S3 Bucket Policies** for public website access

### **Monitoring & Management**
- ✅ **CloudFormation Stack** with complete resource tracking
- ✅ **Resource Tags** for cost allocation and management
- ✅ **Stack Outputs** for easy resource reference

## 🔧 **Advanced Usage**

### **Custom Parameters**

```powershell
.\cloudformation\deploy-stack.ps1 `
  -Environment dev `
  -GitHubToken "your_token" `
  -ProjectName "my-custom-project" `
  -VpcCidr "172.16.0.0/16" `
  -Region "us-west-2"
```

### **Stack Outputs Usage**

After deployment, you can reference stack outputs in other templates:

```yaml
# In other CloudFormation templates
VpcId: 
  Fn::ImportValue: !Sub '${StackName}-VPC-ID'

KMSKeyArn:
  Fn::ImportValue: !Sub '${StackName}-KMSKey-ARN'
```

### **Integration with Terraform**

The CloudFormation stack creates the foundation. You can still use Terraform for application-specific resources:

```hcl
# In terraform/main.tf
data "aws_cloudformation_stack" "main" {
  name = "futureim-ecommerce-ai-platform-dev"
}

# Use stack outputs
vpc_id = data.aws_cloudformation_stack.main.outputs["VPCId"]
kms_key_arn = data.aws_cloudformation_stack.main.outputs["KMSKeyArn"]
```

## 🛠️ **Troubleshooting**

### **Stack Creation Failed**
```powershell
# Check stack events for errors
.\cloudformation\stack-status.ps1 -Environment dev -Detailed

# View specific error in AWS Console
# CloudFormation > Stacks > [StackName] > Events
```

### **Stack Deletion Failed**
```powershell
# Check for resources that prevent deletion
aws cloudformation describe-stack-resources --stack-name futureim-ecommerce-ai-platform-dev

# Manually empty S3 buckets if needed
aws s3 rm s3://bucket-name --recursive

# Retry deletion
.\cloudformation\delete-stack.ps1 -Environment dev -Force
```

### **Resource Already Exists**
```powershell
# If resources exist from previous deployments
# Option 1: Delete existing resources manually
# Option 2: Import into new stack (advanced)
# Option 3: Use different environment name
```

## 🔒 **Security Considerations**

### **Production Deployment**
- ✅ Use **AWS Secrets Manager** for sensitive values
- ✅ Enable **CloudTrail** for audit logging
- ✅ Configure **VPC Flow Logs** for network monitoring
- ✅ Use **least privilege** IAM policies

### **GitHub Token Security**
```powershell
# Store token in AWS Secrets Manager
aws secretsmanager create-secret \
  --name "github-token" \
  --secret-string "your_github_token"

# Reference in deployment
.\cloudformation\deploy-stack.ps1 -Environment prod -GitHubToken $(aws secretsmanager get-secret-value --secret-id github-token --query SecretString --output text)
```

## 📊 **Cost Management**

### **Stack-Level Cost Tracking**
- All resources tagged with `Project` and `Environment`
- Use **AWS Cost Explorer** to filter by tags
- Set up **billing alerts** for stack costs

### **Resource Optimization**
- **NAT Gateway**: Largest cost component (~$45/month)
- **DynamoDB**: Pay-per-request pricing
- **S3**: Minimal costs for small websites
- **KMS**: $1/month per key

## 🔄 **CI/CD Integration**

### **Pipeline Integration**
The CloudFormation stack creates the foundation. Your CI/CD pipeline can:

1. **Deploy Stack**: Use CloudFormation for infrastructure
2. **Deploy Apps**: Use CodePipeline for applications
3. **Update Stack**: Modify template and redeploy
4. **Clean Up**: Delete entire stack when done

### **Environment Promotion**
```powershell
# Deploy to dev
.\cloudformation\deploy-stack.ps1 -Environment dev -GitHubToken $token

# Test and validate

# Deploy to prod with same template
.\cloudformation\deploy-stack.ps1 -Environment prod -GitHubToken $token
```

## 🎉 **Next Steps**

After deploying the CloudFormation stack:

1. **✅ Foundation Ready**: VPC, security, storage created
2. **🔧 Deploy Applications**: Use Terraform/CodePipeline for Lambda functions
3. **🌐 Configure Frontend**: Upload React app to S3 bucket
4. **🔗 Setup CI/CD**: Configure CodePipeline for automated deployments
5. **📊 Monitor**: Use CloudWatch and stack events for monitoring

This approach gives you the **best of both worlds**: CloudFormation for infrastructure management and Terraform for application deployment!