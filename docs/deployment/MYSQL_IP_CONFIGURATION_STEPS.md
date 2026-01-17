# MySQL IP Address Configuration - Complete Guide

## Overview
This guide provides step-by-step instructions to configure MySQL 8.0.31 to accept connections from IP address **172.20.10.4** instead of just localhost.

---

## Prerequisites
- MySQL 8.0.31 installed on Windows
- Administrator access to Windows
- PowerShell with Administrator privileges
- MySQL root password: `Srikar@123`

---

## Quick Start (Automated)

### Option 1: Run Automated Configuration Script

```powershell
# Open PowerShell as Administrator
cd C:\FutureIM\products\market-analyst\deployment

# Run the automated configuration script
.\configure-mysql-ip-access.ps1
```

This script will:
1. ✅ Locate your my.ini file
2. ✅ Backup current configuration
3. ✅ Update bind-address to 0.0.0.0
4. ✅ Create MySQL users for IP access
5. ✅ Configure Windows Firewall
6. ✅ Restart MySQL service
7. ✅ Test connection from IP address

**After running the script, skip to Step 8 (Verification) below.**

---

## Manual Configuration (Step-by-Step)

If you prefer to configure manually or the automated script fails, follow these steps:

### Step 1: Find MySQL Configuration File (my.ini)

Run this PowerShell command to locate my.ini:

```powershell
# Search for my.ini
Get-ChildItem -Path "C:\ProgramData\MySQL" -Filter "my.ini" -Recurse -ErrorAction SilentlyContinue
Get-ChildItem -Path "C:\Program Files\MySQL" -Filter "my.ini" -Recurse -ErrorAction SilentlyContinue
```

Common locations:
- `C:\ProgramData\MySQL\MySQL Server 8.0\my.ini` ← Most common
- `C:\Program Files\MySQL\MySQL Server 8.0\my.ini`

**Note the path for the next steps.**

---

### Step 2: Backup Current Configuration

```powershell
# Replace with your actual path
$myIniPath = "C:\ProgramData\MySQL\MySQL Server 8.0\my.ini"

# Create backup
Copy-Item $myIniPath "$myIniPath.backup"

Write-Host "Backup created: $myIniPath.backup" -ForegroundColor Green
```

---

### Step 3: Edit my.ini File

1. **Open my.ini as Administrator**:
   ```powershell
   notepad $myIniPath
   ```
   Or right-click → "Run as Administrator"

2. **Find the `[mysqld]` section** (usually near the top)

3. **Add or modify these lines** under `[mysqld]`:
   ```ini
   [mysqld]
   # Bind to all network interfaces
   bind-address = 0.0.0.0
   
   # Skip DNS lookups for faster connections
   skip-name-resolve
   
   # Port (should already exist)
   port = 3306
   ```

4. **Save and close** the file

**Important Notes:**
- `bind-address = 0.0.0.0` allows connections from ANY IP address
- For more security, use: `bind-address = 172.20.10.4` (only that specific IP)
- Make sure there are no duplicate `bind-address` lines

---

### Step 4: Restart MySQL Service

```powershell
# Stop MySQL
Stop-Service -Name "MySQL80" -Force

# Wait a moment
Start-Sleep -Seconds 3

# Start MySQL
Start-Service -Name "MySQL80"

# Verify it's running
Get-Service -Name "MySQL80"
```

**Expected output:**
```
Status   Name               DisplayName
------   ----               -----------
Running  MySQL80            MySQL80
```

---

### Step 5: Create MySQL Users for IP Access

1. **Connect to MySQL** (using localhost initially):
   ```powershell
   mysql --host=localhost --user=root --password=Srikar@123
   ```

2. **Run these SQL commands**:
   ```sql
   -- Create user for specific IP address
   CREATE USER 'root'@'172.20.10.4' IDENTIFIED BY 'Srikar@123';
   GRANT ALL PRIVILEGES ON *.* TO 'root'@'172.20.10.4' WITH GRANT OPTION;
   
   -- Create user for IP subnet (allows 172.20.10.0-255)
   CREATE USER 'root'@'172.20.10.%' IDENTIFIED BY 'Srikar@123';
   GRANT ALL PRIVILEGES ON *.* TO 'root'@'172.20.10.%' WITH GRANT OPTION;
   
   -- Apply changes
   FLUSH PRIVILEGES;
   
   -- Verify users were created
   SELECT user, host FROM mysql.user WHERE user = 'root';
   
   -- Exit MySQL
   EXIT;
   ```

3. **Expected output** from SELECT command:
   ```
   +------+---------------+
   | user | host          |
   +------+---------------+
   | root | %             |
   | root | 172.20.10.%   |
   | root | 172.20.10.4   |
   | root | localhost     |
   +------+---------------+
   ```

---

### Step 6: Configure Windows Firewall

```powershell
# Allow MySQL through Windows Firewall
New-NetFirewallRule -DisplayName "MySQL Server" `
    -Direction Inbound `
    -Protocol TCP `
    -LocalPort 3306 `
    -Action Allow

# Verify the rule
Get-NetFirewallRule -DisplayName "MySQL Server"
```

**Expected output:**
```
Name                  : {GUID}
DisplayName           : MySQL Server
Enabled               : True
Direction             : Inbound
Action                : Allow
```

---

### Step 7: Verify MySQL is Listening on Correct Interface

```powershell
# Check what MySQL is listening on
netstat -an | Select-String "3306"
```

**Expected output:**
```
TCP    0.0.0.0:3306           0.0.0.0:0              LISTENING
```

This shows MySQL is listening on ALL interfaces (0.0.0.0), which means it will accept connections from 172.20.10.4.

---

### Step 8: Test Connection from IP Address

#### Test 1: Using mysql command-line
```powershell
mysql --host=172.20.10.4 --user=root --password=Srikar@123 --port=3306 -e "SELECT VERSION();"
```

**Expected output:**
```
+-----------+
| VERSION() |
+-----------+
| 8.0.31    |
+-----------+
```

#### Test 2: Using Python script
```powershell
cd C:\FutureIM\products\market-analyst\deployment
.\test-mysql-connection.ps1 -MySQLHost 172.20.10.4
```

**Expected output:**
```
Testing MySQL Connection...
Host: 172.20.10.4
Port: 3306
User: root
Database: ecommerce
[OK] Successfully connected to MySQL Server version 8.0.31
[OK] Connected to database: ecommerce
[OK] MySQL connection test successful!
```

---

## Verification Checklist

After configuration, verify these items:

- [ ] my.ini contains `bind-address = 0.0.0.0`
- [ ] MySQL service is running
- [ ] MySQL users created for 172.20.10.4
- [ ] Windows Firewall allows port 3306
- [ ] MySQL listening on 0.0.0.0:3306
- [ ] Connection test from 172.20.10.4 succeeds

---

## Troubleshooting

### Issue 1: MySQL won't start after editing my.ini

**Symptoms:**
```
Start-Service : Service 'MySQL80' failed to start
```

**Solution:**
```powershell
# Restore backup
Copy-Item "C:\ProgramData\MySQL\MySQL Server 8.0\my.ini.backup" `
          "C:\ProgramData\MySQL\MySQL Server 8.0\my.ini" -Force

# Start MySQL
Start-Service -Name "MySQL80"

# Check error log
Get-Content "C:\ProgramData\MySQL\MySQL Server 8.0\Data\*.err" -Tail 50
```

**Common causes:**
- Syntax error in my.ini (missing quotes, wrong format)
- Duplicate `bind-address` lines
- Invalid configuration values

---

### Issue 2: "Access denied for user 'root'@'172.20.10.4'"

**Symptoms:**
```
ERROR 1045 (28000): Access denied for user 'root'@'172.20.10.4'
```

**Solution:**
```powershell
# Connect via localhost
mysql --host=localhost --user=root --password=Srikar@123

# Re-create the user
DROP USER IF EXISTS 'root'@'172.20.10.4';
CREATE USER 'root'@'172.20.10.4' IDENTIFIED BY 'Srikar@123';
GRANT ALL PRIVILEGES ON *.* TO 'root'@'172.20.10.4' WITH GRANT OPTION;
FLUSH PRIVILEGES;
EXIT;
```

---

### Issue 3: "Can't connect to MySQL server on '172.20.10.4'"

**Symptoms:**
```
ERROR 2003 (HY000): Can't connect to MySQL server on '172.20.10.4'
```

**Solution:**

1. **Check if MySQL is listening:**
   ```powershell
   netstat -an | Select-String "3306"
   ```
   Should show: `0.0.0.0:3306` or `172.20.10.4:3306`

2. **Check bind-address in my.ini:**
   ```powershell
   Get-Content "C:\ProgramData\MySQL\MySQL Server 8.0\my.ini" | Select-String "bind-address"
   ```
   Should show: `bind-address = 0.0.0.0`

3. **Check firewall:**
   ```powershell
   Get-NetFirewallRule -DisplayName "MySQL Server"
   ```

4. **Restart MySQL:**
   ```powershell
   Restart-Service -Name "MySQL80"
   ```

---

### Issue 4: Connection works from localhost but not from IP

**Symptoms:**
- `mysql --host=localhost` works
- `mysql --host=172.20.10.4` fails

**Solution:**

1. **Verify bind-address is NOT 127.0.0.1:**
   ```powershell
   Get-Content "C:\ProgramData\MySQL\MySQL Server 8.0\my.ini" | Select-String "bind-address"
   ```
   If it shows `127.0.0.1`, change to `0.0.0.0`

2. **Check Windows Firewall is not blocking:**
   ```powershell
   # Temporarily disable firewall to test
   Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled False
   
   # Test connection
   mysql --host=172.20.10.4 --user=root --password=Srikar@123 -e "SELECT 1;"
   
   # Re-enable firewall
   Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled True
   ```

3. **Check antivirus software** - some antivirus programs block MySQL network connections

---

## Complete my.ini Example

Here's a complete example of the `[mysqld]` section with recommended settings:

```ini
[mysqld]
# Basic Settings
port=3306
bind-address=0.0.0.0
skip-name-resolve

# Character Set
character-set-server=utf8mb4
collation-server=utf8mb4_unicode_ci

# Connection Settings
max_connections=200
max_allowed_packet=256M
connect_timeout=10
wait_timeout=28800

# Performance Tuning
innodb_buffer_pool_size=1G
innodb_log_file_size=256M
innodb_flush_log_at_trx_commit=2
innodb_flush_method=O_DIRECT

# Logging
log-error="C:/ProgramData/MySQL/MySQL Server 8.0/Data/error.log"
general_log=0
slow_query_log=1
slow_query_log_file="C:/ProgramData/MySQL/MySQL Server 8.0/Data/slow-query.log"
long_query_time=2

# Security
sql_mode=STRICT_TRANS_TABLES,NO_ENGINE_SUBSTITUTION

# Data Directory
datadir="C:/ProgramData/MySQL/MySQL Server 8.0/Data"
```

---

## Security Best Practices

⚠️ **Important Security Considerations:**

1. **Use specific IP instead of 0.0.0.0 in production:**
   ```ini
   bind-address = 172.20.10.4
   ```

2. **Use strong passwords** (not the default)

3. **Limit user privileges:**
   ```sql
   -- Instead of ALL PRIVILEGES, grant only what's needed
   GRANT SELECT, INSERT, UPDATE, DELETE ON ecommerce.* TO 'app_user'@'172.20.10.4';
   ```

4. **Enable SSL/TLS for encrypted connections**

5. **Regularly update MySQL** to latest security patches

6. **Monitor MySQL logs** for suspicious activity

---

## Next Steps

After successfully configuring MySQL for IP access:

1. **Run the deployment script:**
   ```powershell
   cd C:\FutureIM\products\market-analyst\deployment
   .\step-by-step-deployment.ps1
   ```

2. **Monitor MySQL error log:**
   ```powershell
   Get-Content "C:\ProgramData\MySQL\MySQL Server 8.0\Data\*.err" -Tail 50 -Wait
   ```

3. **Test database operations** to ensure everything works correctly

---

## Quick Reference Commands

```powershell
# Find my.ini
Get-ChildItem -Path "C:\ProgramData\MySQL" -Filter "my.ini" -Recurse

# Backup my.ini
Copy-Item "C:\ProgramData\MySQL\MySQL Server 8.0\my.ini" `
          "C:\ProgramData\MySQL\MySQL Server 8.0\my.ini.backup"

# Edit my.ini
notepad "C:\ProgramData\MySQL\MySQL Server 8.0\my.ini"

# Restart MySQL
Restart-Service -Name "MySQL80"

# Check MySQL status
Get-Service -Name "MySQL80"

# Test connection
mysql --host=172.20.10.4 --user=root --password=Srikar@123 -e "SELECT VERSION();"

# Check listening ports
netstat -an | Select-String "3306"

# View error log
Get-Content "C:\ProgramData\MySQL\MySQL Server 8.0\Data\*.err" -Tail 50

# Check firewall rules
Get-NetFirewallRule -DisplayName "MySQL Server"
```

---

## Summary

You have successfully configured MySQL to accept connections from IP address 172.20.10.4. The deployment scripts have been updated to use this IP address instead of localhost.

**Configuration Changes Made:**
- ✅ my.ini: `bind-address = 0.0.0.0`
- ✅ MySQL users created for 172.20.10.4
- ✅ Windows Firewall configured
- ✅ Deployment scripts updated to use 172.20.10.4

**You can now run the deployment script!**
