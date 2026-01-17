# MySQL Connection Setup Guide

## Overview
This guide helps you configure the connection from AWS to your local MySQL server at `172.20.10.4`.

## MySQL Server Details
- **Host**: 172.20.10.4
- **Port**: 3306
- **Username**: root
- **Password**: Srikar@123
- **Database**: ecommerce

## Network Connectivity Options

### Option 1: AWS Site-to-Site VPN (Recommended for Production)
Establishes an encrypted VPN tunnel between your local network and AWS VPC.

**Steps:**
1. Create a Customer Gateway in AWS pointing to your local network's public IP
2. Create a Virtual Private Gateway and attach to your VPC
3. Create a Site-to-Site VPN connection
4. Configure your local router/firewall to establish the VPN tunnel
5. Update route tables to route traffic to 172.20.10.4 through the VPN

**Cost**: ~$36/month per VPN connection

### Option 2: AWS Direct Connect (Enterprise)
Dedicated network connection between your data center and AWS.

**Cost**: Starting at $300/month + data transfer

### Option 3: Public IP with Security Groups (Development Only)
Expose MySQL on a public IP with strict security group rules.

**⚠️ WARNING**: Not recommended for production due to security risks.

**Steps:**
1. Ensure 172.20.10.4 is accessible via a public IP
2. Configure MySQL to accept remote connections
3. Add AWS DMS IP ranges to MySQL firewall
4. Use SSL/TLS for encryption

### Option 4: SSH Tunnel (Development/Testing)
Create an SSH tunnel from AWS to your local MySQL server.

**Steps:**
1. Set up an SSH server on your local network
2. Configure AWS Lambda or EC2 to create SSH tunnel
3. Route MySQL traffic through the tunnel

## For Development: Direct Connection Setup

Since you're using a local IP (172.20.10.4), this appears to be a development setup. Here's how to configure it:

### 1. Ensure MySQL is Accessible

On your MySQL server (172.20.10.4), verify:

```sql
-- Check if root can connect from remote hosts
SELECT host, user FROM mysql.user WHERE user = 'root';

-- If needed, grant remote access
CREATE USER 'root'@'%' IDENTIFIED BY 'Srikar@123';
GRANT ALL PRIVILEGES ON ecommerce.* TO 'root'@'%';
FLUSH PRIVILEGES;
```

### 2. Configure MySQL for Remote Connections

Edit MySQL configuration file (`my.cnf` or `my.ini`):

```ini
[mysqld]
bind-address = 0.0.0.0
port = 3306
```

Restart MySQL service.

### 3. Test Connection from AWS

Once VPN or network connectivity is established, test from an EC2 instance:

```bash
mysql -h 172.20.10.4 -u root -p'Srikar@123' -e "SHOW DATABASES;"
```

## Security Recommendations

1. **Never use root in production** - Create a dedicated DMS user:
```sql
CREATE USER 'dms_user'@'%' IDENTIFIED BY 'SecurePassword123!';
GRANT SELECT, REPLICATION CLIENT, REPLICATION SLAVE ON *.* TO 'dms_user'@'%';
FLUSH PRIVILEGES;
```

2. **Use SSL/TLS** - Configure MySQL to require SSL connections

3. **Rotate passwords regularly** - Update SSM Parameter Store when changed

4. **Restrict IP ranges** - Only allow AWS VPC CIDR blocks

5. **Enable binary logging** for CDC (Change Data Capture):
```ini
[mysqld]
server-id = 1
log_bin = mysql-bin
binlog_format = ROW
binlog_row_image = FULL
```

## Storing Credentials in AWS

The setup script will store credentials in AWS Systems Manager Parameter Store:

```
/ecommerce-ai-platform/dev/mysql/host = 172.20.10.4
/ecommerce-ai-platform/dev/mysql/user = root
/ecommerce-ai-platform/dev/mysql/password = Srikar@123 (encrypted)
/ecommerce-ai-platform/dev/mysql/database = ecommerce

/ecommerce-ai-platform/prod/mysql/host = <prod-mysql-host>
/ecommerce-ai-platform/prod/mysql/user = <prod-user>
/ecommerce-ai-platform/prod/mysql/password = <prod-password> (encrypted)
/ecommerce-ai-platform/prod/mysql/database = ecommerce
```

## Next Steps

1. Choose your connectivity option (VPN recommended)
2. Run the configuration script: `.\deployment\configure-mysql-connection.ps1`
3. Test the connection
4. Proceed with Terraform deployment
