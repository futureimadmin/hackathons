# Security Testing Guide

## Overview

Comprehensive security testing guide for the eCommerce AI Analytics Platform covering vulnerability scanning, penetration testing, and security hardening.

## Table of Contents

1. [OWASP ZAP Vulnerability Scanning](#owasp-zap-vulnerability-scanning)
2. [SQL Injection Testing](#sql-injection-testing)
3. [XSS Prevention Testing](#xss-prevention-testing)
4. [Authentication & Authorization Testing](#authentication--authorization-testing)
5. [Data Encryption Testing](#data-encryption-testing)
6. [Sensitive Data Masking Verification](#sensitive-data-masking-verification)
7. [Security Hardening Checklist](#security-hardening-checklist)

---

## OWASP ZAP Vulnerability Scanning

### Setup

```bash
# Install OWASP ZAP
# Windows: Download from https://www.zaproxy.org/download/
# Linux: sudo apt-get install zaproxy
# Mac: brew install --cask owasp-zap

# Or use Docker
docker pull owasp/zap2docker-stable
```

### Running Automated Scan

```bash
# Basic scan
zap-cli quick-scan --self-contained --start-options '-config api.disablekey=true' https://api.example.com

# Full scan with authentication
zap-cli quick-scan \
  --self-contained \
  --start-options '-config api.disablekey=true' \
  --auth-mode form \
  --auth-url https://api.example.com/auth/login \
  --auth-username test@example.com \
  --auth-password TestPassword123! \
  https://api.example.com

# Generate HTML report
zap-cli report -o security-scan-report.html -f html
```

### Docker-Based Scan

```bash
# Baseline scan
docker run -v $(pwd):/zap/wrk/:rw -t owasp/zap2docker-stable zap-baseline.py \
  -t https://api.example.com \
  -r baseline-report.html

# Full scan
docker run -v $(pwd):/zap/wrk/:rw -t owasp/zap2docker-stable zap-full-scan.py \
  -t https://api.example.com \
  -r full-scan-report.html
```

### Expected Vulnerabilities to Check

✅ **Should Pass:**
- No SQL injection vulnerabilities
- No XSS vulnerabilities
- No CSRF vulnerabilities
- HTTPS enforced
- Secure headers present
- No sensitive data exposure

⚠️ **Common Issues:**
- Missing security headers
- Weak SSL/TLS configuration
- Information disclosure
- Clickjacking vulnerabilities

---

## SQL Injection Testing

### Test Cases

#### 1. Authentication Bypass

```bash
# Test login endpoint
curl -X POST https://api.example.com/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "admin@example.com'\'' OR '\''1'\''='\''1",
    "password": "anything"
  }'

# Expected: 401 Unauthorized (not 200 OK)
```

#### 2. Analytics Query Injection

```bash
# Test analytics endpoint
curl -X POST https://api.example.com/analytics/query \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "system": "market-intelligence",
    "query": "SELECT * FROM customers WHERE customer_id = '\''CUST001'\'' OR '\''1'\''='\''1'\''"
  }'

# Expected: 400 Bad Request with validation error
```

#### 3. Athena Query Injection

```bash
# Test with malicious SQL
curl -X POST https://api.example.com/analytics/query \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "system": "demand-insights",
    "query": "SELECT * FROM orders; DROP TABLE customers; --"
  }'

# Expected: 400 Bad Request (query validation should block)
```

### SQL Injection Prevention Verification

**Check analytics service code:**

```python
# ✅ Good: Parameterized queries
def execute_query(query, params):
    # Whitelist allowed tables
    allowed_tables = ['customers', 'orders', 'products']
    
    # Validate query structure
    if not validate_query_structure(query):
        raise ValueError("Invalid query structure")
    
    # Use parameterized queries
    cursor.execute(query, params)

# ✅ Good: Input validation
def validate_query_structure(query):
    # Check for dangerous keywords
    dangerous_keywords = ['DROP', 'DELETE', 'UPDATE', 'INSERT', 'ALTER', 'CREATE']
    query_upper = query.upper()
    
    for keyword in dangerous_keywords:
        if keyword in query_upper:
            return False
    
    return True
```

---

## XSS Prevention Testing

### Test Cases

#### 1. Reflected XSS

```bash
# Test search endpoint
curl "https://api.example.com/search?q=<script>alert('XSS')</script>"

# Expected: Escaped output or sanitized input
```

#### 2. Stored XSS

```bash
# Test chat endpoint
curl -X POST https://api.example.com/retail-copilot/chat \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "user_id": "USER001",
    "message": "<script>alert('\''XSS'\'')</script>"
  }'

# Expected: Message sanitized before storage
```

#### 3. DOM-Based XSS

**Test frontend:**

```javascript
// Check if user input is properly escaped
const userInput = "<img src=x onerror=alert('XSS')>";
document.getElementById('output').textContent = userInput;  // ✅ Safe
document.getElementById('output').innerHTML = userInput;    // ❌ Unsafe
```

### XSS Prevention Verification

**Frontend (React):**

```typescript
// ✅ Good: React automatically escapes
function UserMessage({ message }: { message: string }) {
  return <div>{message}</div>;  // Automatically escaped
}

// ❌ Bad: dangerouslySetInnerHTML
function UnsafeMessage({ message }: { message: string }) {
  return <div dangerouslySetInnerHTML={{ __html: message }} />;  // Unsafe!
}

// ✅ Good: Sanitize before rendering
import DOMPurify from 'dompurify';

function SafeMessage({ message }: { message: string }) {
  const clean = DOMPurify.sanitize(message);
  return <div dangerouslySetInnerHTML={{ __html: clean }} />;
}
```

**Backend (Python):**

```python
import html

# ✅ Good: Escape user input
def sanitize_input(user_input):
    return html.escape(user_input)

# ✅ Good: Validate input format
def validate_message(message):
    # Remove HTML tags
    clean_message = re.sub('<[^<]+?>', '', message)
    return clean_message
```

---

## Authentication & Authorization Testing

### Test Cases

#### 1. JWT Token Validation

```bash
# Test with expired token
curl -X GET https://api.example.com/market-intelligence/forecast \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.EXPIRED_TOKEN"

# Expected: 401 Unauthorized

# Test with invalid signature
curl -X GET https://api.example.com/market-intelligence/forecast \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.INVALID_SIGNATURE"

# Expected: 401 Unauthorized

# Test without token
curl -X GET https://api.example.com/market-intelligence/forecast

# Expected: 401 Unauthorized
```

#### 2. Authorization Testing

```bash
# Test accessing admin endpoint as regular user
curl -X POST https://api.example.com/admin/systems \
  -H "Authorization: Bearer $USER_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "system_name": "test-system",
    "description": "Test"
  }'

# Expected: 403 Forbidden

# Test accessing other user's data
curl -X GET https://api.example.com/retail-copilot/conversations/USER002 \
  -H "Authorization: Bearer $USER001_TOKEN"

# Expected: 403 Forbidden
```

#### 3. Password Strength Testing

```bash
# Test weak password
curl -X POST https://api.example.com/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "password": "123456",
    "firstName": "Test",
    "lastName": "User"
  }'

# Expected: 400 Bad Request with password requirements

# Test strong password
curl -X POST https://api.example.com/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "password": "StrongP@ssw0rd123!",
    "firstName": "Test",
    "lastName": "User"
  }'

# Expected: 201 Created
```

### Password Requirements Verification

**Check auth service:**

```java
// ✅ Good: Strong password requirements
public boolean isPasswordStrong(String password) {
    if (password.length() < 12) return false;
    if (!password.matches(".*[A-Z].*")) return false;  // Uppercase
    if (!password.matches(".*[a-z].*")) return false;  // Lowercase
    if (!password.matches(".*[0-9].*")) return false;  // Number
    if (!password.matches(".*[!@#$%^&*].*")) return false;  // Special char
    return true;
}

// ✅ Good: BCrypt hashing
public String hashPassword(String password) {
    return BCrypt.hashpw(password, BCrypt.gensalt(12));
}
```

---

## Data Encryption Testing

### Test Cases

#### 1. Data at Rest Encryption

```bash
# Check S3 bucket encryption
aws s3api get-bucket-encryption --bucket ecommerce-ai-platform-raw

# Expected: AES256 or aws:kms

# Check DynamoDB encryption
aws dynamodb describe-table --table-name ecommerce-ai-platform-users

# Expected: SSEDescription with KMS key

# Check RDS encryption
aws rds describe-db-instances --db-instance-identifier ecommerce-db

# Expected: StorageEncrypted: true
```

#### 2. Data in Transit Encryption

```bash
# Check SSL/TLS configuration
openssl s_client -connect api.example.com:443 -tls1_2

# Expected: TLS 1.2 or higher

# Check for weak ciphers
nmap --script ssl-enum-ciphers -p 443 api.example.com

# Expected: No weak ciphers (RC4, DES, MD5)
```

#### 3. API Encryption

```bash
# Test HTTP (should redirect to HTTPS)
curl -I http://api.example.com

# Expected: 301 Moved Permanently to https://

# Test HTTPS
curl -I https://api.example.com

# Expected: 200 OK with security headers
```

### Encryption Verification

**Check Terraform configurations:**

```terraform
# ✅ S3 encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "raw" {
  bucket = aws_s3_bucket.raw.id
  
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.main.arn
    }
  }
}

# ✅ DynamoDB encryption
resource "aws_dynamodb_table" "users" {
  server_side_encryption {
    enabled     = true
    kms_key_arn = aws_kms_key.main.arn
  }
}

# ✅ CloudWatch Logs encryption
resource "aws_cloudwatch_log_group" "lambda" {
  kms_key_id = aws_kms_key.main.arn
}
```

---

## Sensitive Data Masking Verification

### Test Cases

#### 1. Credit Card Masking

```bash
# Test PCI compliance endpoint
curl -X POST https://api.example.com/compliance/pci-compliance \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "payment_ids": ["PAY001", "PAY002"]
  }'

# Expected response:
# {
#   "masked_data": {
#     "PAY001": {
#       "card_number": "****-****-****-1234",
#       "cvv": "***"
#     }
#   }
# }
```

#### 2. PII Masking in Logs

```bash
# Check CloudWatch logs
aws logs filter-log-events \
  --log-group-name /aws/lambda/ecommerce-ai-platform-auth \
  --filter-pattern "credit_card OR ssn OR password"

# Expected: No sensitive data in logs
```

#### 3. Database Query Results

```bash
# Test customer data endpoint
curl -X GET https://api.example.com/analytics/query \
  -H "Authorization: Bearer $TOKEN" \
  -d '{
    "system": "demand-insights",
    "query": "SELECT * FROM customers LIMIT 10"
  }'

# Expected: Sensitive fields masked (SSN, credit card, etc.)
```

### Masking Verification

**Check compliance checker:**

```python
# ✅ Good: Credit card masking
def mask_credit_card(card_number):
    if len(card_number) < 4:
        return "****"
    return f"****-****-****-{card_number[-4:]}"

# ✅ Good: PII masking
def mask_pii(data):
    if 'ssn' in data:
        data['ssn'] = f"***-**-{data['ssn'][-4:]}"
    if 'credit_card' in data:
        data['credit_card'] = mask_credit_card(data['credit_card'])
    if 'cvv' in data:
        data['cvv'] = "***"
    return data

# ✅ Good: Log sanitization
def sanitize_log(message):
    # Remove credit card numbers
    message = re.sub(r'\d{4}[-\s]?\d{4}[-\s]?\d{4}[-\s]?\d{4}', '****-****-****-****', message)
    # Remove SSN
    message = re.sub(r'\d{3}-\d{2}-\d{4}', '***-**-****', message)
    return message
```

---

## Security Hardening Checklist

### Infrastructure Security

- [ ] **VPC Configuration**
  - [ ] Private subnets for Lambda functions
  - [ ] NAT Gateway for outbound traffic
  - [ ] Security groups with least privilege
  - [ ] Network ACLs configured

- [ ] **IAM Policies**
  - [ ] Least privilege access
  - [ ] No wildcard permissions
  - [ ] MFA enabled for admin users
  - [ ] Regular access reviews

- [ ] **Encryption**
  - [ ] S3 buckets encrypted (KMS)
  - [ ] DynamoDB tables encrypted (KMS)
  - [ ] CloudWatch Logs encrypted
  - [ ] Secrets Manager for credentials
  - [ ] TLS 1.2+ enforced

- [ ] **API Gateway**
  - [ ] WAF enabled with OWASP rules
  - [ ] Throttling configured
  - [ ] API keys for programmatic access
  - [ ] CORS properly configured
  - [ ] Request validation enabled

### Application Security

- [ ] **Authentication**
  - [ ] Strong password requirements (12+ chars, mixed case, numbers, special)
  - [ ] BCrypt password hashing (cost factor 12+)
  - [ ] JWT tokens with 1-hour expiry
  - [ ] Secure token storage (httpOnly cookies or secure storage)
  - [ ] Account lockout after failed attempts

- [ ] **Authorization**
  - [ ] Role-based access control (RBAC)
  - [ ] Resource-level permissions
  - [ ] JWT token validation on every request
  - [ ] Admin endpoints protected

- [ ] **Input Validation**
  - [ ] SQL injection prevention (parameterized queries)
  - [ ] XSS prevention (input sanitization)
  - [ ] CSRF protection
  - [ ] File upload validation
  - [ ] Request size limits

- [ ] **Data Protection**
  - [ ] PII masking in logs
  - [ ] Credit card masking (PCI DSS)
  - [ ] Sensitive data encryption
  - [ ] Secure data deletion

### Monitoring & Logging

- [ ] **Security Monitoring**
  - [ ] CloudTrail enabled (all regions)
  - [ ] CloudWatch Logs for all services
  - [ ] Failed authentication attempts logged
  - [ ] Suspicious activity alerts
  - [ ] Regular security audits

- [ ] **Incident Response**
  - [ ] Incident response plan documented
  - [ ] Security contact information
  - [ ] Backup and recovery procedures
  - [ ] Regular security drills

### Compliance

- [ ] **PCI DSS**
  - [ ] Credit card data encrypted
  - [ ] CVV not stored
  - [ ] Cardholder data masked
  - [ ] Access logs maintained

- [ ] **GDPR**
  - [ ] Data retention policies
  - [ ] Right to deletion implemented
  - [ ] Data export functionality
  - [ ] Privacy policy documented

- [ ] **SOC 2**
  - [ ] Access controls documented
  - [ ] Change management process
  - [ ] Incident response procedures
  - [ ] Regular audits

---

## Security Testing Automation

### CI/CD Integration

```yaml
# GitHub Actions example
name: Security Testing

on: [push, pull_request]

jobs:
  security-scan:
    runs-on: ubuntu-latest
    
    steps:
      - uses: actions/checkout@v2
      
      - name: Run OWASP ZAP Scan
        uses: zaproxy/action-baseline@v0.7.0
        with:
          target: 'https://api-staging.example.com'
          rules_file_name: '.zap/rules.tsv'
          cmd_options: '-a'
      
      - name: Run Snyk Security Scan
        uses: snyk/actions/node@master
        env:
          SNYK_TOKEN: ${{ secrets.SNYK_TOKEN }}
      
      - name: Run Trivy Vulnerability Scanner
        uses: aquasecurity/trivy-action@master
        with:
          scan-type: 'fs'
          scan-ref: '.'
          format: 'sarif'
          output: 'trivy-results.sarif'
```

---

## Security Testing Schedule

### Daily
- Automated vulnerability scanning
- Failed authentication monitoring
- Suspicious activity alerts

### Weekly
- Manual security testing
- Access log review
- Security patch updates

### Monthly
- Full penetration testing
- Security audit
- Compliance review

### Quarterly
- Third-party security assessment
- Disaster recovery drill
- Security training

---

## Reporting Security Issues

### Internal Reporting
1. Document the vulnerability
2. Assess severity (Critical, High, Medium, Low)
3. Create remediation plan
4. Track in issue tracker
5. Verify fix

### External Reporting
- Security contact: security@example.com
- Bug bounty program (if applicable)
- Responsible disclosure policy

---

## References

- [OWASP Top 10](https://owasp.org/www-project-top-ten/)
- [AWS Security Best Practices](https://aws.amazon.com/security/best-practices/)
- [PCI DSS Requirements](https://www.pcisecuritystandards.org/)
- [NIST Cybersecurity Framework](https://www.nist.gov/cyberframework)
