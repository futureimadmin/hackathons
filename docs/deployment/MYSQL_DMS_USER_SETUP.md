# MySQL DMS User Setup Guide

## Overview
This guide shows how to properly configure a dedicated MySQL user for AWS DMS replication with minimal security privileges (instead of using root).

## 🔐 **Security Best Practice**
- ✅ **Use dedicated user**: `dms_remote` (not `root`)
- ✅ **Minimal privileges**: Only what DMS needs
- ✅ **IP restrictions**: Limit access to specific IPs
- ✅ **Strong passwords**: Use secure passwords

## 🚀 **Step-by-Step Setup**

### **Step 1: Connect to MySQL as Root**
```powershell
# Connect to your MySQL server
mysql --host=172.20.10.2 --user=root --password=your_root_password --port=3306
```

### **Step 2: Create DMS User**
```sql
-- Create DMS user for specific IP
CREATE USER 'dms_remote'@'172.20.10.2' IDENTIFIED BY 'your_secure_dms_password';

-- Create DMS user for any IP (more flexible but less secure)
CREATE USER 'dms_remote'@'%' IDENTIFIED BY 'your_secure_dms_password';
```

### **Step 3: Grant Minimal Required Privileges**
```sql
-- Grant replication privileges (required for DMS)
GRANT REPLICATION SLAVE ON *.* TO 'dms_remote'@'172.20.10.2';
GRANT REPLICATION SLAVE ON *.* TO 'dms_remote'@'%';

-- Grant SELECT on the specific database (ecommerce)
GRANT SELECT ON ecommerce.* TO 'dms_remote'@'172.20.10.2';
GRANT SELECT ON ecommerce.* TO 'dms_remote'@'%';

-- Apply changes
FLUSH PRIVILEGES;
```

### **Step 4: Verify User Creation**
```sql
-- Check if user was created
SELECT user, host FROM mysql.user WHERE user = 'dms_remote';

-- Check user privileges
SHOW GRANTS FOR 'dms_remote'@'172.20.10.2';
SHOW GRANTS FOR 'dms_remote'@'%';
```

Expected output:
```
+------------+---------------+
| user       | host          |
+------------+---------------+
| dms_remote | %             |
| dms_remote | 172.20.10.2   |
+------------+---------------+
```

## 🧪 **Test the Connection**

### **From Command Line**
```powershell
# Test connection with DMS user
mysql --host=172.20.10.2 --user=dms_remote --password=your_secure_dms_password --port=3306 -e "SELECT VERSION();"

# Test database access
mysql --host=172.20.10.2 --user=dms_remote --password=your_secure_dms_password --port=3306 -e "USE ecommerce; SHOW TABLES;"
```

### **Test Replication Privileges**
```sql
-- Connect as dms_remote and test replication commands
SHOW MASTER STATUS;
SHOW SLAVE STATUS;
```

## 🔧 **AWS Secrets Manager Configuration**

Store the DMS password securely in AWS Secrets Manager:

```powershell
# Create secret for DMS password
aws secretsmanager create-secret \
  --name "ecommerce/onprem-mysql-password" \
  --description "MySQL password for DMS user" \
  --secret-string "your_secure_dms_password"
```

## 📋 **Terraform Configuration Validation**

Verify your Terraform configuration uses the correct user:

```hcl
# In terraform/variables.tf
variable "mysql_username" {
  description = "MySQL username for DMS"
  type        = string
  default     = "dms_remote"  # ✅ Correct - not "root"
}
```

## 🔍 **Security Comparison**

### ❌ **Bad Practice (Root User)**
```sql
-- DON'T DO THIS
CREATE USER 'root'@'%' IDENTIFIED BY 'password';
GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' WITH GRANT OPTION;
```
**Problems:**
- Full administrative access
- Can modify system tables
- Security risk if compromised
- Violates principle of least privilege

### ✅ **Good Practice (Dedicated DMS User)**
```sql
-- DO THIS INSTEAD
CREATE USER 'dms_remote'@'172.20.10.2' IDENTIFIED BY 'secure_password';
GRANT REPLICATION SLAVE ON *.* TO 'dms_remote'@'172.20.10.2';
GRANT SELECT ON ecommerce.* TO 'dms_remote'@'172.20.10.2';
```
**Benefits:**
- Minimal required privileges
- IP-restricted access
- Cannot modify system configuration
- Follows security best practices

## 🚨 **Troubleshooting**

### **Connection Denied**
```
ERROR 1045 (28000): Access denied for user 'dms_remote'@'172.20.10.2'
```
**Solutions:**
1. Verify user exists: `SELECT user, host FROM mysql.user WHERE user = 'dms_remote';`
2. Check password is correct
3. Verify IP address matches exactly
4. Ensure MySQL is listening on correct interface

### **Insufficient Privileges**
```
ERROR 1227 (42000): Access denied; you need (at least one of) the REPLICATION SLAVE privilege(s)
```
**Solution:**
```sql
GRANT REPLICATION SLAVE ON *.* TO 'dms_remote'@'172.20.10.2';
FLUSH PRIVILEGES;
```

### **Cannot Access Database**
```
ERROR 1044 (42000): Access denied for user 'dms_remote'@'172.20.10.2' to database 'ecommerce'
```
**Solution:**
```sql
GRANT SELECT ON ecommerce.* TO 'dms_remote'@'172.20.10.2';
FLUSH PRIVILEGES;
```

## 📊 **Privilege Summary**

| Privilege | Purpose | Required for DMS |
|-----------|---------|------------------|
| `REPLICATION SLAVE` | Read binary logs | ✅ Yes |
| `SELECT` on database | Read table data | ✅ Yes |
| `INSERT/UPDATE/DELETE` | Modify data | ❌ No |
| `CREATE/DROP` | Schema changes | ❌ No |
| `SUPER` | Administrative tasks | ❌ No |

## 🎯 **Final Validation**

After setup, verify everything works:

1. ✅ DMS user can connect from AWS IP
2. ✅ DMS user can read binary logs
3. ✅ DMS user can select from ecommerce database
4. ✅ DMS user cannot perform administrative tasks
5. ✅ Password is stored securely in AWS Secrets Manager

This setup provides the perfect balance of functionality and security for AWS DMS replication!