# MySQL IP Address Update Summary

## 🔄 **IP Address Change**
- **Old IP**: `172.20.10.4`
- **New IP**: `172.20.10.2`

## 📝 **Files Updated**

### ✅ **Terraform Configuration**
1. **`terraform/variables.tf`**
   - Updated `mysql_server_name` default value
   - Changed from `172.20.10.4` to `172.20.10.2`

2. **`terraform/modules/vpc/security_groups.tf`**
   - Updated DMS security group CIDR block
   - Changed from `172.20.10.4/32` to `172.20.10.2/32`

### ✅ **CloudFormation Template**
3. **`cloudformation/ecommerce-ai-platform-stack.yaml`**
   - Added `MySQLServerIP` parameter with default `172.20.10.2`
   - Added DMS security group with MySQL access rule
   - Added outputs for MySQL IP and DMS security group

4. **`cloudformation/deploy-stack.ps1`**
   - Added `MySQLServerIP` parameter support
   - Defaults to `172.20.10.2`

### ✅ **Documentation**
5. **`.kiro/specs/ecommerce-ai-platform/design.md`**
   - Updated all references from `172.20.10.4` to `172.20.10.2`
   - Updated architecture diagrams and configuration examples

## 🚀 **How to Apply Changes**

### **Option 1: Use the Quick Update Script**
```powershell
# Update IP and apply changes automatically
.\update-mysql-ip.ps1 -NewMySQLIP "172.20.10.2" -Environment dev
```

### **Option 2: Manual Terraform Update**
```powershell
# Navigate to terraform directory
cd terraform

# Plan changes
terraform plan -var-file="terraform.dev.tfvars"

# Apply changes
terraform apply -var-file="terraform.dev.tfvars"
```

### **Option 3: CloudFormation Stack Update**
```powershell
# Update existing stack with new IP
.\cloudformation\deploy-stack.ps1 -Environment dev -GitHubToken "your_token" -MySQLServerIP "172.20.10.2"
```

## 🔍 **What Gets Updated**

### **AWS Resources**
- ✅ **DMS Security Group**: Updated to allow access from `172.20.10.2`
- ✅ **DMS Source Endpoint**: Will use new IP for MySQL connection
- ✅ **VPC Security Rules**: Updated CIDR blocks

### **Configuration Files**
- ✅ **Terraform Variables**: New default MySQL IP
- ✅ **CloudFormation Parameters**: New MySQL IP parameter
- ✅ **Documentation**: All references updated

## 🧪 **Testing the Update**

### **1. Verify Network Connectivity**
```powershell
# Test connection from your machine
Test-NetConnection -ComputerName 172.20.10.2 -Port 3306
```

### **2. Test MySQL Connection**
```powershell
# Test MySQL connection with DMS user
mysql --host=172.20.10.2 --user=dms_remote --password=your_secure_dms_password --port=3306 -e "SELECT VERSION();"
```

### **3. Verify DMS Connectivity**
After applying Terraform changes:
1. Go to AWS Console → DMS → Endpoints
2. Test the source endpoint connection
3. Verify it connects to `172.20.10.2:3306`

## ⚠️ **Important Notes**

### **MySQL Server Configuration**
Make sure your MySQL server at `172.20.10.2` is configured with the dedicated DMS user (NOT root for security):

```sql
-- Connect to MySQL as root and create/update the DMS user:
CREATE USER 'dms_remote'@'172.20.10.2' IDENTIFIED BY 'your_secure_dms_password';
CREATE USER 'dms_remote'@'%' IDENTIFIED BY 'your_secure_dms_password';

-- Grant necessary privileges for DMS replication (minimal permissions)
GRANT REPLICATION SLAVE ON *.* TO 'dms_remote'@'172.20.10.2';
GRANT REPLICATION SLAVE ON *.* TO 'dms_remote'@'%';
GRANT SELECT ON ecommerce.* TO 'dms_remote'@'172.20.10.2';
GRANT SELECT ON ecommerce.* TO 'dms_remote'@'%';

FLUSH PRIVILEGES;
```

**Security Note**: We use a dedicated `dms_remote` user with minimal privileges instead of `root` for better security.

### **Network Configuration**
Ensure your MySQL server's `my.ini` file has:
```ini
bind-address = 0.0.0.0
# OR specifically
bind-address = 172.20.10.2
```

### **Firewall Rules**
Make sure Windows Firewall allows MySQL connections on port 3306.

## 🎯 **Verification Checklist**

After applying the updates:

- [ ] Terraform plan shows security group changes
- [ ] Terraform apply completes successfully
- [ ] DMS endpoint test connection succeeds
- [ ] MySQL server accepts connections from new IP
- [ ] No hardcoded references to old IP remain
- [ ] Documentation reflects new IP address

## 🔧 **Rollback Plan**

If you need to rollback to the old IP:

```powershell
# Rollback using the update script
.\update-mysql-ip.ps1 -NewMySQLIP "172.20.10.4" -Environment dev
```

## 📞 **Support**

If you encounter issues:
1. Check MySQL server logs
2. Verify network connectivity
3. Test DMS endpoint connection in AWS Console
4. Review Terraform plan output for unexpected changes

The update process is designed to be safe and reversible. All changes are tracked in version control and can be rolled back if needed.