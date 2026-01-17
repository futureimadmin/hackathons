# Configure MySQL for IP Address Access (172.20.10.4)

## Overview
This guide will help you configure MySQL 8.0.31 to accept connections from IP address 172.20.10.4 instead of just localhost.

## Step 1: Locate MySQL Configuration File

MySQL on Windows typically uses `my.ini` located in one of these directories:
- `C:\ProgramData\MySQL\MySQL Server 8.0\my.ini` (most common)
- `C:\Program Files\MySQL\MySQL Server 8.0\my.ini`
- MySQL installation directory

### Find Your my.ini File
Run this PowerShell command to locate it:
```powershell
Get-ChildItem -Path "C:\ProgramData\MySQL" -Filter "my.ini" -Recurse -ErrorAction SilentlyContinue
Get-ChildItem -Path "C:\Program Files\MySQL" -Filter "my.ini" -Recurse -ErrorAction SilentlyContinue
```

## Step 2: Backup Current Configuration

Before making changes, backup your current configuration:
```powershell
# Replace with your actual path
Copy-Item "C:\ProgramData\MySQL\MySQL Server 8.0\my.ini" "C:\ProgramData\MySQL\MySQL Server 8.0\my.ini.backup"
```

## Step 3: Edit my.ini Configuration

Open `my.ini` as Administrator in Notepad or your preferred editor.

### Find and Modify the [mysqld] Section

Look for the `[mysqld]` section and modify/add these settings:

```ini
[mysqld]
# Bind to all network interfaces (allows connections from any IP)
bind-address = 0.0.0.0

# OR bind to specific IP address
# bind-address = 172.20.10.4

# Port configuration
port = 3306

# Skip name resolution for faster connections
skip-name-resolve

# Maximum connections
max_connections = 200
```

### Important Notes:
- `bind-address = 0.0.0.0` allows connections from ANY IP address
- `bind-address = 172.20.10.4` restricts to only that specific IP
- `skip-name-resolve` prevents DNS lookups and speeds up connections

## Step 4: Restart MySQL Service

After editing my.ini, restart MySQL:

### Using PowerShell (as Administrator):
```powershell
# Stop MySQL service
Stop-Service -Name "MySQL80" -Force

# Wait a moment
Start-Sleep -Seconds 3

# Start MySQL service
Start-Service -Name "MySQL80"

# Verify service is running
Get-Service -Name "MySQL80"
```

### Using Services GUI:
1. Press `Win + R`, type `services.msc`, press Enter
2. Find "MySQL80" in the list
3. Right-click → Restart

## Step 5: Create MySQL User for IP Access

Connect to MySQL and create a user that can connect from 172.20.10.4:

```powershell
# Connect to MySQL
mysql --host=localhost --user=root --password=Srikar@123
```

Then run these SQL commands:

```sql
-- Create user for IP address access
CREATE USER 'root'@'172.20.10.4' IDENTIFIED BY 'Srikar@123';

-- Grant all privileges
GRANT ALL PRIVILEGES ON *.* TO 'root'@'172.20.10.4' WITH GRANT OPTION;

-- Also grant for wildcard (allows from any IP in subnet)
CREATE USER 'root'@'172.20.10.%' IDENTIFIED BY 'Srikar@123';
GRANT ALL PRIVILEGES ON *.* TO 'root'@'172.20.10.%' WITH GRANT OPTION;

-- Flush privileges to apply changes
FLUSH PRIVILEGES;

-- Verify users
SELECT user, host FROM mysql.user WHERE user = 'root';

-- Exit MySQL
EXIT;
```

## Step 6: Configure Windows Firewall

Allow MySQL through Windows Firewall:

```powershell
# Allow MySQL port 3306 through firewall
New-NetFirewallRule -DisplayName "MySQL Server" -Direction Inbound -Protocol TCP -LocalPort 3306 -Action Allow

# Verify the rule was created
Get-NetFirewallRule -DisplayName "MySQL Server"
```

## Step 7: Test Connection from IP Address

Test the connection using the IP address:

```powershell
# Test connection
mysql --host=172.20.10.4 --user=root --password=Srikar@123 --port=3306 -e "SELECT VERSION();"
```

If successful, you should see the MySQL version output.

## Step 8: Verify Configuration

Run this verification script:

```powershell
# Check if MySQL is listening on the correct interface
netstat -an | Select-String "3306"

# Should show: 0.0.0.0:3306 or 172.20.10.4:3306
```

## Troubleshooting

### Issue: "Can't connect to MySQL server"
**Solution**: 
- Verify MySQL service is running: `Get-Service MySQL80`
- Check bind-address in my.ini
- Restart MySQL service

### Issue: "Access denied for user 'root'@'172.20.10.4'"
**Solution**:
- Verify user was created: `SELECT user, host FROM mysql.user WHERE user = 'root';`
- Re-run the GRANT commands
- Run `FLUSH PRIVILEGES;`

### Issue: "Connection timeout"
**Solution**:
- Check Windows Firewall rules
- Verify bind-address is not 127.0.0.1
- Check if antivirus is blocking port 3306

### Issue: MySQL won't start after editing my.ini
**Solution**:
- Restore backup: `Copy-Item my.ini.backup my.ini`
- Check for syntax errors in my.ini
- Review MySQL error log: `C:\ProgramData\MySQL\MySQL Server 8.0\Data\*.err`

## Complete my.ini Example

Here's a complete example of the [mysqld] section:

```ini
[mysqld]
# Server Configuration
port=3306
bind-address=0.0.0.0
skip-name-resolve

# Character Set
character-set-server=utf8mb4
collation-server=utf8mb4_unicode_ci

# Connection Settings
max_connections=200
max_allowed_packet=256M

# Performance
innodb_buffer_pool_size=1G
innodb_log_file_size=256M

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

## Security Considerations

⚠️ **Important Security Notes**:
1. Using `bind-address = 0.0.0.0` allows connections from ANY IP
2. For production, use specific IP: `bind-address = 172.20.10.4`
3. Use strong passwords for all MySQL users
4. Consider using SSL/TLS for encrypted connections
5. Limit user privileges to only what's needed
6. Regularly update MySQL to latest security patches

## Next Steps

After completing this configuration:
1. Test connection from deployment script
2. Verify database operations work correctly
3. Run the deployment script with IP address configuration
4. Monitor MySQL logs for any connection issues

## Quick Reference Commands

```powershell
# Find my.ini location
Get-ChildItem -Path "C:\ProgramData\MySQL" -Filter "my.ini" -Recurse

# Restart MySQL
Restart-Service -Name "MySQL80"

# Check MySQL status
Get-Service -Name "MySQL80"

# Test connection
mysql --host=172.20.10.4 --user=root --password=Srikar@123 -e "SELECT VERSION();"

# Check listening ports
netstat -an | Select-String "3306"

# View MySQL error log
Get-Content "C:\ProgramData\MySQL\MySQL Server 8.0\Data\*.err" -Tail 50
```
