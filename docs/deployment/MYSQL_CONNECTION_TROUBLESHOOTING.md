# MySQL Connection Troubleshooting Guide

## Issue Identified

**Error**: `Access denied for user 'root'@'SSS' (using password: YES)`

This means:
- ✅ Network connectivity is working (port 3306 is reachable)
- ✅ MySQL server is running
- ❌ Authentication failed

## Root Causes

### 1. Password Incorrect
The password "Srikar@123" may not be correct for the root user.

### 2. Host Permission Issue
MySQL root user may not be allowed to connect from your machine (SSS).

MySQL users have host-specific permissions. The root user might only be allowed to connect from:
- `root@localhost` - Only from the MySQL server itself
- `root@127.0.0.1` - Only from loopback
- `root@specific-ip` - Only from a specific IP

Your machine appears to be connecting from hostname 'SSS', but root may not have permission for that host.

## Solutions

### Solution 1: Verify Password

Connect to the MySQL server (172.20.10.4) directly and verify the password:

```bash
# On the MySQL server machine
mysql -u root -p
# Enter password when prompted
```

### Solution 2: Grant Remote Access to Root User

On the MySQL server (172.20.10.4), run these commands:

```sql
-- Connect to MySQL as root
mysql -u root -p

-- Grant access from your machine
CREATE USER 'root'@'%' IDENTIFIED BY 'Srikar@123';
GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' WITH GRANT OPTION;
FLUSH PRIVILEGES;

-- Or grant access from specific IP
CREATE USER 'root'@'172.20.10.4' IDENTIFIED BY 'Srikar@123';
GRANT ALL PRIVILEGES ON *.* TO 'root'@'172.20.10.4' WITH GRANT OPTION;
FLUSH PRIVILEGES;
```

### Solution 3: Create Dedicated User for Deployment

**RECOMMENDED**: Instead of using root, create a dedicated user:

```sql
-- On MySQL server
mysql -u root -p

-- Create deployment user
CREATE USER 'ecommerce_deploy'@'%' IDENTIFIED BY 'YourSecurePassword123!';
GRANT ALL PRIVILEGES ON ecommerce.* TO 'ecommerce_deploy'@'%';
FLUSH PRIVILEGES;
```

Then update your deployment script to use this user:
```powershell
$MYSQL_USER = "ecommerce_deploy"
$MYSQL_PASSWORD = "YourSecurePassword123!"
```

### Solution 4: Check MySQL Configuration

On the MySQL server, verify the bind-address setting:

```bash
# Check MySQL configuration
cat /etc/mysql/mysql.conf.d/mysqld.cnf | grep bind-address

# Should be:
bind-address = 0.0.0.0  # Allows connections from any IP
# NOT:
bind-address = 127.0.0.1  # Only allows local connections
```

If bind-address is 127.0.0.1, change it to 0.0.0.0 and restart MySQL:

```bash
sudo nano /etc/mysql/mysql.conf.d/mysqld.cnf
# Change bind-address to 0.0.0.0
sudo systemctl restart mysql
```

### Solution 5: Check Firewall

Ensure the MySQL server firewall allows connections on port 3306:

```bash
# On MySQL server
sudo ufw status
sudo ufw allow 3306/tcp
```

## Testing Connection

After making changes, test the connection:

```powershell
# Test with Python script
.\deployment\test-mysql-connection.ps1

# Or test with specific credentials
.\deployment\test-mysql-connection.ps1 -MySQLUser "ecommerce_deploy" -MySQLPassword "YourPassword"
```

## Current Status

### What's Working
- ✅ Network connectivity to 172.20.10.4:3306
- ✅ MySQL server is running and accepting connections
- ✅ Python mysql-connector installed

### What Needs Fixing
- ❌ MySQL user authentication
- ❌ Host permission for remote connections

## Recommended Next Steps

1. **Immediate**: Connect to MySQL server (172.20.10.4) and verify:
   - Root password is correct
   - Root user has remote access permissions
   - bind-address is set to 0.0.0.0

2. **Best Practice**: Create a dedicated deployment user instead of using root

3. **Security**: After deployment, restrict the deployment user to only necessary permissions

## Quick Fix Commands

Run these on the MySQL server (172.20.10.4):

```bash
# Connect to MySQL
mysql -u root -p

# Run these SQL commands
USE mysql;
SELECT user, host FROM user WHERE user='root';

# If root@'%' doesn't exist, create it
CREATE USER 'root'@'%' IDENTIFIED BY 'Srikar@123';
GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' WITH GRANT OPTION;
FLUSH PRIVILEGES;

# Verify
SELECT user, host FROM user WHERE user='root';
EXIT;
```

## Alternative: Use SSH Tunnel

If you cannot modify MySQL permissions, use an SSH tunnel:

```powershell
# Create SSH tunnel (requires SSH access to MySQL server)
ssh -L 3306:localhost:3306 user@172.20.10.4

# Then connect to localhost:3306 instead
.\deployment\test-mysql-connection.ps1 -MySQLHost "localhost"
```

## Contact

If issues persist:
1. Check MySQL error log: `/var/log/mysql/error.log`
2. Verify MySQL is listening: `netstat -tlnp | grep 3306`
3. Check user permissions: `SELECT user, host FROM mysql.user;`
