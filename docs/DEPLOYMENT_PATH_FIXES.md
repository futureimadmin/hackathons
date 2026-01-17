# Deployment Script Path Fixes

## Issues Fixed

### 1. Database Folder Path Issue
**Problem**: Script was looking for `deployment/database` but database folder is at project root level.

**Solution**: 
- Changed navigation from `Push-Location database` to `Set-Location "$PSScriptRoot\..\database"`
- This correctly navigates from deployment folder to project root, then into database folder

### 2. Data Generator Not Found
**Problem**: Data generator script path was incorrect after navigation changes.

**Solution**:
- Ensured we're in the database folder before looking for `data_generator/generate_sample_data.py`
- Added better error message showing full path when script not found

### 3. MySQL Connection Test Failing
**Problem**: MySQL command-line tool was having issues with password escaping and hostname resolution (showing 'SSS' instead of IP).

**Solution**:
- Replaced `mysql` command-line tool with Python `mysql.connector` for all MySQL operations
- Python provides more reliable connection handling and better error messages
- No issues with password special characters or hostname resolution

### 4. Data Generator Hardcoded Configuration
**Problem**: Data generator had hardcoded database connection values:
- host: 'localhost' (should be 172.20.10.4)
- database: 'ecommerce_platform' (should be 'ecommerce')

**Solution**:
- Updated data generator to read from environment variables:
  - `MYSQL_HOST` (default: localhost)
  - `MYSQL_PORT` (default: 3306)
  - `MYSQL_USER` (default: root)
  - `MYSQL_PASSWORD` (default: Srikar@123)
  - `MYSQL_DATABASE` (default: ecommerce)
  - `TARGET_SIZE_MB` (default: 500)
- Deployment script now sets these environment variables before calling data generator
- Added configuration display at start of data generation

### 5. Database Verification Using mysql Command
**Problem**: Database verification was using `mysql` command which had the same issues as connection test.

**Solution**:
- Replaced with Python script that uses `mysql.connector`
- Shows list of tables created
- More reliable error handling

## Files Modified

1. **deployment/step-by-step-deployment.ps1**
   - Fixed database folder navigation
   - Replaced mysql command-line calls with Python scripts
   - Better error messages and path display

2. **database/data_generator/generate_sample_data.py**
   - Added environment variable support for all configuration
   - Added configuration display at startup
   - Made data volumes scale based on TARGET_SIZE_MB

## Testing the Fixes

Run the deployment script from the deployment folder:

```powershell
cd deployment
.\step-by-step-deployment.ps1
```

The script will now:
1. Test MySQL connection using Python (more reliable)
2. Navigate correctly to database folder at project root
3. Create database and run schema scripts
4. Generate sample data with correct configuration
5. Verify database setup with Python

## Expected Output

```
Testing MySQL connection...
[OK] MySQL connection successful!
[OK] MySQL version: 8.0.31

Step 1.1: Creating database schema...
  → Creating database: ecommerce
  ✓ Database created
  → Executing: schema/01_main_ecommerce_schema.sql
    ✓ Schema applied
  → Executing: schema/02_system_specific_schemas.sql
    ✓ Schema applied

Step 1.2: Generating sample data (500MB)...
  → Running data generator...

============================================================
eCommerce Platform Sample Data Generator
============================================================

Database Configuration:
  Host:     172.20.10.4
  Port:     3306
  User:     root
  Database: ecommerce
  Target Size: 500MB

Connecting to database...
✓ Connected to database

Generating 10000 customers...
  Generated 1000 customers...
  ...
```

## Notes

- All MySQL operations now use Python for consistency and reliability
- Environment variables allow easy configuration changes
- Better error messages help with troubleshooting
- Script is more portable across different systems
