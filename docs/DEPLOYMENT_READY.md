# Deployment Ready - Step-by-Step Process

## Summary

Your eCommerce AI Platform is ready for step-by-step deployment following your exact workflow.

## Your Deployment Workflow

### ✅ Step 1: Create MySQL Schema and Sample Data (500MB)
**Location**: 172.20.10.4
**Database**: ecommerce
**User**: root / Srikar@123

### ✅ Step 2: Configure AWS (MySQL + JWT)
**Storage**: AWS SSM Parameter Store
**JWT**: Non-expiring tokens

### ✅ Step 3: Create AWS Infrastructure
**Resources**: VPC, S3 (15 buckets), DMS, Lambda, API Gateway, DynamoDB, Glue, Athena
**Time**: 15-20 minutes
**Cost**: ~$280-450/month

### ✅ Step 4: Build and Deploy Modules
**Services**: 
- Auth Service (Java)
- Analytics Service (Python)
- 5 AI Systems (Python)

### ✅ Step 5: Setup API Gateway
**Verification**: Test endpoints and Lambda integrations

### ✅ Step 6: Deploy React Frontend
**Target**: S3 Static Website Hosting

### ✅ Step 7: Publish URLs
**Output**: All URLs saved to DEPLOYMENT_URLS.txt

## How to Deploy

### Option 1: Automated Step-by-Step (Recommended)

Run the interactive deployment script:

```powershell
cd deployment
.\step-by-step-deployment.ps1
```

**Features**:
- Guides you through each step
- Asks for confirmation before proceeding
- Prompts for any required input
- Verifies each step completion
- Displays progress and status
- Saves all URLs at the end

**Time**: 45-60 minutes (with prompts)

### Option 2: Manual Step-by-Step

Follow the detailed guide:

```powershell
# Read the guide
cat deployment/STEP_BY_STEP_GUIDE.md

# Then execute each step manually
```

## What's Configured

### MySQL Connection
```
Host:     172.20.10.4
Port:     3306
User:     root
Password: Srikar@123
Database: ecommerce
```

### JWT Tokens
```
Expiration: NEVER (non-expiring)
Algorithm:  HMAC256
Secret:     64-byte cryptographically random
Storage:    AWS SSM Parameter Store (encrypted)
```

### AWS Infrastructure
```
Region:      us-east-1
Environment: dev
Project:     ecommerce-ai-platform
```

## Files Created

### Deployment Scripts
1. **deployment/step-by-step-deployment.ps1** - Main deployment script
2. **deployment/configure-mysql-connection.ps1** - MySQL and JWT configuration
3. **deployment/STEP_BY_STEP_GUIDE.md** - Detailed guide
4. **terraform/setup-terraform.ps1** - Terraform backend setup

### Configuration Files
1. **terraform/terraform.tfvars** - Terraform variables
2. **terraform/backend.tfvars** - Backend configuration
3. **auth-service/.../JwtService.java** - Updated for non-expiring tokens

### Documentation
1. **deployment/README.md** - Deployment overview
2. **deployment/INFRASTRUCTURE_DEPLOYMENT_GUIDE.md** - Complete guide
3. **deployment/MYSQL_JWT_CONFIGURATION_SUMMARY.md** - Configuration reference
4. **deployment/mysql-connection-setup.md** - Network connectivity guide
5. **MYSQL_JWT_SETUP_COMPLETE.md** - Configuration summary

## Prerequisites Check

Before running the deployment, ensure you have:

- ✅ AWS CLI installed and configured
- ✅ Terraform >= 1.0 installed
- ✅ MySQL client installed
- ✅ Python 3.9+ installed
- ✅ Maven installed (for Java builds)
- ✅ Node.js 18+ installed (for React)
- ✅ PowerShell 7+ installed
- ✅ MySQL server running at 172.20.10.4
- ✅ AWS account with appropriate permissions

## Quick Start

```powershell
# 1. Verify prerequisites
aws --version
terraform --version
mysql --version
python --version
mvn --version
node --version

# 2. Test MySQL connection
mysql -h 172.20.10.4 -u root -p'Srikar@123' -e "SELECT VERSION();"

# 3. Test AWS credentials
aws sts get-caller-identity

# 4. Run deployment
cd deployment
.\step-by-step-deployment.ps1
```

## What the Script Does

### Step 1: Database Setup
- Tests MySQL connection
- Creates database schema
- Generates 500MB of sample data
- Verifies data insertion

### Step 2: AWS Configuration
- Generates JWT secrets
- Stores MySQL credentials in SSM
- Stores JWT secrets in SSM
- Tests configuration

### Step 3: Infrastructure Creation
- Sets up Terraform backend
- Initializes Terraform
- Plans infrastructure
- Creates all AWS resources
- Displays outputs

### Step 4: Module Deployment
- Builds Auth Service (Java)
- Builds Analytics Service (Python)
- Builds 5 AI Systems (Python)
- Deploys all to Lambda
- Verifies deployments

### Step 5: API Gateway Setup
- Retrieves API Gateway URL
- Tests health endpoint
- Verifies Lambda integrations

### Step 6: Frontend Deployment
- Installs npm dependencies
- Builds React application
- Creates S3 bucket
- Enables static hosting
- Uploads files
- Configures public access

### Step 7: URL Publishing
- Displays frontend URL
- Displays API Gateway URL
- Lists all S3 buckets
- Lists all Lambda functions
- Shows CloudWatch links
- Saves URLs to file

## Expected Outputs

### Frontend URL
```
http://ecommerce-ai-platform-frontend-dev.s3-website-us-east-1.amazonaws.com
```

### API Gateway URL
```
https://xxxxxxxxxx.execute-api.us-east-1.amazonaws.com/dev
```

### S3 Buckets (15 total)
```
ecommerce-ai-platform-market-intelligence-hub-raw-dev
ecommerce-ai-platform-market-intelligence-hub-curated-dev
ecommerce-ai-platform-market-intelligence-hub-prod-dev
... (12 more buckets for other systems)
```

### Lambda Functions (7 total)
```
ecommerce-ai-platform-dev-auth
ecommerce-ai-platform-dev-analytics
ecommerce-ai-platform-dev-market-intelligence
ecommerce-ai-platform-dev-demand-insights
ecommerce-ai-platform-dev-compliance-guardian
ecommerce-ai-platform-dev-retail-copilot
ecommerce-ai-platform-dev-global-market-pulse
```

## Interactive Prompts

The script will ask for confirmation at each step:

1. **Before database setup**: "Proceed with database setup?"
2. **Before AWS configuration**: "Proceed with AWS configuration?"
3. **Before infrastructure creation**: "Review the plan. Proceed with infrastructure creation?"
4. **Before module deployment**: "Proceed with building and deploying modules?"
5. **Before API Gateway setup**: "Proceed with API Gateway setup?"
6. **Before frontend deployment**: "Proceed with frontend deployment?"

You can skip any step by answering "no".

## Time Estimates

| Step | Time |
|------|------|
| 1. Database Setup | 5-10 minutes |
| 2. AWS Configuration | 2-3 minutes |
| 3. Infrastructure Creation | 15-20 minutes |
| 4. Module Deployment | 10-15 minutes |
| 5. API Gateway Setup | 2-3 minutes |
| 6. Frontend Deployment | 5-7 minutes |
| 7. URL Publishing | 1 minute |
| **Total** | **45-60 minutes** |

## Cost Estimate

### Development Environment
- **Monthly**: ~$280-450
- **Daily**: ~$9-15
- **Hourly**: ~$0.40-0.60

### Main Cost Drivers
- DMS Replication Instance: $184/month
- NAT Gateway: $32/month
- S3 Storage: $2.30/month
- Lambda: $0.20/month
- Other services: $60-230/month

## Network Connectivity Note

⚠️ **Important**: Your MySQL server (172.20.10.4) is on a local network. For AWS DMS to replicate data, you'll need to setup network connectivity:

**Recommended**: AWS Site-to-Site VPN (~$36/month, 1-2 hours setup)

See `deployment/mysql-connection-setup.md` for detailed instructions.

## Troubleshooting

### Common Issues

1. **MySQL Connection Failed**
   - Verify MySQL is running
   - Check bind-address in my.cnf
   - Test connection manually

2. **AWS Credentials Error**
   - Run `aws configure`
   - Verify credentials with `aws sts get-caller-identity`

3. **Terraform Backend Error**
   - Run `.\terraform\setup-terraform.ps1`
   - Verify S3 bucket and DynamoDB table exist

4. **Lambda Deployment Failed**
   - Ensure Terraform created functions first
   - Check function names match
   - Verify IAM permissions

5. **Frontend Not Loading**
   - Check bucket policy allows public read
   - Verify static website hosting enabled
   - Ensure index.html exists

## Support

For detailed troubleshooting:
1. Check `deployment/STEP_BY_STEP_GUIDE.md`
2. Review `docs/TROUBLESHOOTING_GUIDE.md`
3. Check CloudWatch Logs
4. Verify Terraform state

## Next Steps After Deployment

1. **Test the Application**
   - Access frontend URL
   - Test login/registration
   - Verify API endpoints

2. **Setup Monitoring**
   - Configure CloudWatch alarms
   - Setup SNS notifications
   - Enable X-Ray tracing

3. **Setup CI/CD Pipeline**
   ```powershell
   cd deployment/deployment-pipeline
   .\setup-pipeline.ps1
   ```

4. **Configure Custom Domain** (Optional)
   - Register domain in Route 53
   - Create CloudFront distribution
   - Setup SSL certificate

5. **Enable DMS Replication**
   - Start replication tasks
   - Monitor replication lag
   - Verify data in S3

6. **Run Integration Tests**
   ```powershell
   cd tests/integration
   .\run_integration_tests.ps1
   ```

## Ready to Deploy?

```powershell
cd deployment
.\step-by-step-deployment.ps1
```

The script will guide you through each step with clear prompts and confirmations.

---

**Generated**: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
**Status**: Ready for deployment
**Configuration**: MySQL 172.20.10.4:3306, JWT non-expiring, AWS us-east-1

🚀 **Let's deploy!**
