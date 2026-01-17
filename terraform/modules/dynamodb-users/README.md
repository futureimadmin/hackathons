# DynamoDB Users Table Module

This Terraform module creates a DynamoDB table for storing user authentication data.

## Features

- User table with userId as primary key
- Global Secondary Index (GSI) for email lookup
- Point-in-time recovery enabled
- Server-side encryption with KMS
- TTL for reset tokens
- Optional DynamoDB streams for audit logging
- CloudWatch alarms for capacity and throttling

## Table Schema

**Table Name:** `ecommerce-users`

**Primary Key:**
- `userId` (String) - Partition key (UUID)

**Attributes:**
- `email` (String) - User email address
- `passwordHash` (String) - BCrypt hashed password
- `name` (String) - User's full name
- `resetToken` (String) - Password reset token (optional)
- `resetTokenExpiry` (Number) - Unix timestamp for TTL
- `createdAt` (String) - ISO 8601 timestamp
- `updatedAt` (String) - ISO 8601 timestamp

**Global Secondary Index:**
- `email-index` - For querying users by email
  - Partition key: `email`
  - Projection: ALL

## Usage

```hcl
module "dynamodb_users" {
  source = "./modules/dynamodb-users"

  table_name   = "ecommerce-users"
  billing_mode = "PAY_PER_REQUEST"
  
  enable_point_in_time_recovery = true
  enable_streams                = false
  
  kms_key_arn = aws_kms_key.dynamodb.arn
  
  alarm_actions = [aws_sns_topic.alerts.arn]
  
  tags = {
    Environment = "production"
    Project     = "ecommerce-ai-platform"
  }
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| table_name | Name of the DynamoDB table | string | "ecommerce-users" | no |
| billing_mode | Billing mode (PROVISIONED or PAY_PER_REQUEST) | string | "PAY_PER_REQUEST" | no |
| read_capacity | Read capacity units (PROVISIONED only) | number | 5 | no |
| write_capacity | Write capacity units (PROVISIONED only) | number | 5 | no |
| gsi_read_capacity | GSI read capacity units (PROVISIONED only) | number | 5 | no |
| gsi_write_capacity | GSI write capacity units (PROVISIONED only) | number | 5 | no |
| enable_point_in_time_recovery | Enable point-in-time recovery | bool | true | no |
| kms_key_arn | ARN of KMS key for encryption | string | null | no |
| enable_streams | Enable DynamoDB streams | bool | false | no |
| alarm_actions | List of ARNs to notify when alarms trigger | list(string) | [] | no |
| tags | Tags to apply to all resources | map(string) | {} | no |

## Outputs

| Name | Description |
|------|-------------|
| table_name | Name of the DynamoDB table |
| table_arn | ARN of the DynamoDB table |
| table_id | ID of the DynamoDB table |
| stream_arn | ARN of the DynamoDB stream |
| email_index_name | Name of the email GSI |

## Billing Modes

### PAY_PER_REQUEST (Recommended)

- No capacity planning required
- Automatically scales with traffic
- Pay only for what you use
- Best for unpredictable workloads

### PROVISIONED

- Fixed capacity units
- Lower cost for predictable workloads
- Requires capacity planning
- Can use auto-scaling

## Security Features

### Encryption at Rest

- Server-side encryption enabled by default
- Optional KMS key for customer-managed encryption
- Protects data stored in DynamoDB

### Point-in-Time Recovery

- Continuous backups for 35 days
- Restore to any point in time
- No performance impact

### TTL for Reset Tokens

- Automatically deletes expired reset tokens
- Reduces storage costs
- Improves security

## CloudWatch Monitoring

### Alarms

1. **Read Capacity Alarm** (PROVISIONED only)
   - Triggers when > 80% capacity used
   - Period: 5 minutes
   - Evaluation: 2 periods

2. **Write Capacity Alarm** (PROVISIONED only)
   - Triggers when > 80% capacity used
   - Period: 5 minutes
   - Evaluation: 2 periods

3. **Throttled Requests Alarm**
   - Triggers when > 10 throttled requests
   - Period: 5 minutes
   - Evaluation: 1 period

### Metrics

- ConsumedReadCapacityUnits
- ConsumedWriteCapacityUnits
- UserErrors (throttling)
- SystemErrors

## Example Queries

### Get User by ID

```python
import boto3

dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table('ecommerce-users')

response = table.get_item(Key={'userId': 'user-uuid'})
user = response.get('Item')
```

### Get User by Email (using GSI)

```python
response = table.query(
    IndexName='email-index',
    KeyConditionExpression='email = :email',
    ExpressionAttributeValues={':email': 'user@example.com'}
)
users = response.get('Items', [])
```

### Create User

```python
from datetime import datetime

table.put_item(
    Item={
        'userId': 'user-uuid',
        'email': 'user@example.com',
        'passwordHash': 'bcrypt-hash',
        'name': 'John Doe',
        'createdAt': datetime.utcnow().isoformat(),
        'updatedAt': datetime.utcnow().isoformat()
    }
)
```

### Update Password

```python
table.update_item(
    Key={'userId': 'user-uuid'},
    UpdateExpression='SET passwordHash = :hash, updatedAt = :updated',
    ExpressionAttributeValues={
        ':hash': 'new-bcrypt-hash',
        ':updated': datetime.utcnow().isoformat()
    }
)
```

## Cost Estimation

### PAY_PER_REQUEST

- Write: $1.25 per million requests
- Read: $0.25 per million requests
- Storage: $0.25 per GB-month

**Example:** 100K users, 1M logins/month
- Writes: 100K * $1.25/1M = $0.125
- Reads: 1M * $0.25/1M = $0.25
- Storage: 0.1 GB * $0.25 = $0.025
- **Total: ~$0.40/month**

### PROVISIONED

- Write: $0.00065 per WCU-hour
- Read: $0.00013 per RCU-hour
- Storage: $0.25 per GB-month

**Example:** 5 RCU, 5 WCU
- Reads: 5 * $0.00013 * 730 = $0.47
- Writes: 5 * $0.00065 * 730 = $2.37
- Storage: 0.1 GB * $0.25 = $0.025
- **Total: ~$2.87/month**

## Best Practices

1. **Use PAY_PER_REQUEST** for unpredictable workloads
2. **Enable point-in-time recovery** for production
3. **Use KMS encryption** for sensitive data
4. **Monitor CloudWatch alarms** for capacity issues
5. **Use GSI efficiently** - avoid full table scans
6. **Implement TTL** for temporary data (reset tokens)
7. **Use batch operations** for bulk reads/writes
8. **Enable streams** only if needed for audit logging

## References

- [DynamoDB Documentation](https://docs.aws.amazon.com/dynamodb/)
- [DynamoDB Best Practices](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/best-practices.html)
- [DynamoDB Pricing](https://aws.amazon.com/dynamodb/pricing/)
