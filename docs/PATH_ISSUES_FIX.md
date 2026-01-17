# Path Issues Fix - Schema and Data Generator Not Found

## Problems Identified

1. **Schema scripts not found** - Tables not being created
2. **Data generator not found** - Script exists but can't be located

## Root Cause

The script navigates to the database folder correctly:
```powershell
Set-Location "$PSScriptRoot\..\database"
# Now we're in: C:\FutureIM\products\market-analyst\database
```

But then it was looking for files with incorrect paths:

### Problem 1: Schema Files
**Wrong path (line 268-269):**
```powershell
$schemaFiles = @(
    "database/schema/01_main_ecommerce_schema.sql",  # WRONG - adds database/ prefix
    "database/schema/02_system_specific_schemas.sql"
)
```

**Why it fails:**
- Current directory: `C:\FutureIM\products\market-analyst\database`
- Looking for: `database/schema/...`
- Full path becomes: `C:\FutureIM\products\market-analyst\database\database\schema\...` ❌

**Correct path:**
```powershell
$schemaFiles = @(
    "schema/01_main_ecommerce_schema.sql",  # CORRECT - relative to current dir
    "schema/02_system_specific_schemas.sql"
)
```

### Problem 2: Data Generator
**Wrong path (line 335):**
```powershell
if (Test-Path "database/data_generator/generate_sample_data.py") {
```

**Why it fails:**
- Current directory: `C:\FutureIM\products\market-analyst\database`
- Looking for: `database/data_generator/...`
- Full path becomes: `C:\FutureIM\products\market-analyst\database\database\data_generator\...` ❌

**Correct path:**
```powershell
if (Test-Path "data_generator/generate_sample_data.py") {
```

## Fix Applied

Changed all paths to be relative to the database folder since we're already navigated there:

1. **Schema files**: `database/schema/...` → `schema/...`
2. **Data generator**: `database/data_generator/...` → `data_generator/...`

## Added Debug Output

Added a line to show current directory:
```powershell
Write-ColorOutput "  Current directory: $(Get-Location)" $COLOR_CYAN
```

This helps verify we're in the right location.

## Expected Output After Fix

```
Step 1.1: Creating database schema...
  Current directory: C:\FutureIM\products\market-analyst\database
  → Creating database: ecommerce
  [OK] Database created
  → Running schema scripts...
  → Executing: schema/01_main_ecommerce_schema.sql
    [OK] Schema applied
  → Executing: schema/02_system_specific_schemas.sql
    [OK] Schema applied

Step 1.2: Generating sample data (500MB)...
  → This may take 5-10 minutes...
  → Running data generator...
  
============================================================
eCommerce Platform Sample Data Generator
============================================================

Database Configuration:
  Host:     172.20.10.4
  Port:     3306
  User:     dms_remote
  Database: ecommerce
  Target Size: 500MB

Connecting to database...
✓ Connected to database

Generating 10000 customers...
  Generated 1000 customers...
  [continues...]
```

## File Structure Reference

```
C:\FutureIM\products\market-analyst\
├── deployment/
│   └── step-by-step-deployment.ps1  (runs from here)
└── database/
    ├── schema/
    │   ├── 01_main_ecommerce_schema.sql
    │   └── 02_system_specific_schemas.sql
    └── data_generator/
        └── generate_sample_data.py
```

## Testing the Fix

Run the deployment script:
```powershell
cd deployment
.\step-by-step-deployment.ps1
```

The script will now:
1. ✓ Navigate to database folder correctly
2. ✓ Find and execute schema scripts
3. ✓ Create all tables
4. ✓ Find and run data generator
5. ✓ Generate 500MB of sample data
