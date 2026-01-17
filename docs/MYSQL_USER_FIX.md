# MySQL User Connection Fix

## Problem Identified

The deployment script was failing to connect to MySQL with the following error:
```
[X] MySQL connection failed
Error: 1045 (28000): Access denied for user 'root'@'SSS' (using password: YES)
```

## Root Cause

MySQL was configured to deny remote access for the `root` user from your machine's hostname ('SSS'). The root user typically only has access from localhost for security reasons.

However, the `dms_remote` user was specifically created with remote access privileges:
```sql
CREATE USER 'dms_remote'@'%' IDENTIFIED BY 'SaiesaShanmukha@123';
GRANT ALL PRIVILEGES ON ecommerce.* TO 'dms_remote'@'%';
```

## Diagnostic Results

Created and ran `deployment/diagnose-mysql-connection.ps1` which revealed:

```
Test 2: Testing connection with root user...
  [X] Connection failed with root user
  [X] Error: 1045 (28000): Access denied for user 'root'@'SSS' (using password: YES)

Test 3: Testing connection with dms_remote user...
  [OK] Connection successful with dms_remote user!
  [OK] MySQL version: 8.0.31

Test 4: Testing database access to 'ecommerce'...
  [OK] Connected to database with user: dms_remote
  [!] Database exists but has no tables
```

## Solution Applied

Updated `deployment/step-by-step-deployment.ps1` to use `dms_remote` user instead of `root` user:

**Before:**
```powershell
$MYSQL_USER = "root"
$MYSQL_PASSWORD = "Srikar@123"
```

**After:**
```powershell
$MYSQL_USER = "dms_remote"
$MYSQL_PASSWORD = "SaiesaShanmukha@123"
```

## Why This Works

1. **dms_remote has full privileges** on the ecommerce database:
   - Can create/drop tables
   - Can insert/update/delete data
   - Can run schema scripts
   - Can generate sample data

2. **Remote access is enabled** for dms_remote from any host (`'%'`)

3. **Same user for local and AWS DMS** - Simplifies configuration since both use the same credentials

## Files Modified

1. **deployment/step-by-step-deployment.ps1**
   - Changed `$MYSQL_USER` from "root" to "dms_remote"
   - Changed `$MYSQL_PASSWORD` from "Srikar@123" to "SaiesaShanmukha@123"
   - Added better error handling for mysql-connector-python installation

2. **deployment/diagnose-mysql-connection.ps1** (NEW)
   - Diagnostic script to test both root and dms_remote connections
   - Helps identify which user has proper access
   - Tests database access and shows tables

## Alternative Solution (Not Implemented)

If you wanted to use the root user instead, you would need to grant remote access:

```sql
-- Connect to MySQL as root locally
mysql -u root -p

-- Grant remote access to root from your machine
GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' IDENTIFIED BY 'Srikar@123';
-- OR for specific IP only (more secure)
GRANT ALL PRIVILEGES ON *.* TO 'root'@'YOUR_IP_ADDRESS' IDENTIFIED BY 'Srikar@123';

FLUSH PRIVILEGES;
```

However, using a dedicated user like `dms_remote` is better practice for security reasons.

## Testing the Fix

Run the deployment script again:

```powershell
cd deployment
.\step-by-step-deployment.ps1
```

Expected output:
```
Testing MySQL connection...
[OK] mysql-connector-python is installed
[OK] MySQL connection successful!
[OK] MySQL version: 8.0.31
✓ MySQL connection successful!
```

## Database Status

- **Database**: ecommerce (exists)
- **Tables**: None yet (will be created by schema scripts)
- **User**: dms_remote (has full privileges)
- **Ready for**: Schema creation and data generation

## Next Steps

The deployment script will now:
1. ✓ Connect successfully with dms_remote user
2. Create database schema (01_main_ecommerce_schema.sql, 02_system_specific_schemas.sql)
3. Generate 500MB of sample data
4. Verify database setup

All operations will use the dms_remote user which has the necessary privileges.
