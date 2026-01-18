# Terraform Backend Configuration
# This file configures where Terraform stores its state

# S3 Backend Configuration
bucket         = "futureim-ecommerce-ai-platform-terraform-state"
key            = "dev/terraform.tfstate"
region         = "us-east-2"
encrypt        = true
dynamodb_table = "futureim-ecommerce-ai-platform-terraform-locks"

# Before running terraform init, create the S3 bucket and DynamoDB table:
# 
# aws s3 mb s3://futureim-ecommerce-ai-platform-terraform-state --region us-east-2
# aws s3api put-bucket-versioning --bucket futureim-ecommerce-ai-platform-terraform-state --versioning-configuration Status=Enabled
# aws s3api put-bucket-encryption --bucket futureim-ecommerce-ai-platform-terraform-state --server-side-encryption-configuration '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'
# 
# aws dynamodb create-table \
#   --table-name futureim-ecommerce-ai-platform-terraform-locks \
#   --attribute-definitions AttributeName=LockID,AttributeType=S \
#   --key-schema AttributeName=LockID,KeyType=HASH \
#   --billing-mode PAY_PER_REQUEST \
#   --region us-east-2

# Before running terraform init, create the S3 bucket and DynamoDB table:
# 
# aws s3 mb s3://ecommerce-ai-platform-terraform-state --region us-east-1
# aws s3api put-bucket-versioning --bucket ecommerce-ai-platform-terraform-state --versioning-configuration Status=Enabled
# aws s3api put-bucket-encryption --bucket ecommerce-ai-platform-terraform-state --server-side-encryption-configuration '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'
# 
# aws dynamodb create-table \
#   --table-name ecommerce-ai-platform-terraform-locks \
#   --attribute-definitions AttributeName=LockID,AttributeType=S \
#   --key-schema AttributeName=LockID,KeyType=HASH \
#   --billing-mode PAY_PER_REQUEST \
#   --region us-east-1
