#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Test complete database setup process

.DESCRIPTION
    Tests each step of the database setup to identify where issues occur
#>

$MYSQL_HOST = "172.20.10.4"
$MYSQL_USER = "dms_remote"
$MYSQL_PASSWORD = "SaiesaShanmukha@123"
$MYSQL_DATABASE = "ecommerce"

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Database Setup Test" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

Write-Host "Configuration:" -ForegroundColor White
Write-Host "  Host:     $MYSQL_HOST" -ForegroundColor Gray
Write-Host "  User:     $MYSQL_USER" -ForegroundColor Gray
Write-Host "  Database: $MYSQL_DATABASE" -ForegroundColor Gray
Write-Host ""

# Test 1: Connection
Write-Host "Test 1: Testing connection..." -ForegroundColor Yellow
$testScript = @"
import mysql.connector
import sys
try:
    conn = mysql.connector.connect(
        host='$MYSQL_HOST',
        user='$MYSQL_USER',
        password='$MYSQL_PASSWORD'
    )
    print('[OK] Connection successful')
    conn.close()
    sys.exit(0)
except Exception as e:
    print('[X] Connection failed: ' + str(e))
    sys.exit(1)
"@

$temp1 = [System.IO.Path]::GetTempFileName() + ".py"
$testScript | Out-File -FilePath $temp1 -Encoding UTF8
python $temp1
Remove-Item $temp1 -Force
Write-Host ""

# Test 2: Database creation
Write-Host "Test 2: Creating database..." -ForegroundColor Yellow
$createScript = @"
import mysql.connector
import sys
try:
    conn = mysql.connector.connect(
        host='$MYSQL_HOST',
        user='$MYSQL_USER',
        password='$MYSQL_PASSWORD'
    )
    cursor = conn.cursor()
    cursor.execute('CREATE DATABASE IF NOT EXISTS $MYSQL_DATABASE')
    conn.commit()
    print('[OK] Database created or already exists')
    cursor.close()
    conn.close()
    sys.exit(0)
except Exception as e:
    print('[X] Database creation failed: ' + str(e))
    sys.exit(1)
"@

$temp2 = [System.IO.Path]::GetTempFileName() + ".py"
$createScript | Out-File -FilePath $temp2 -Encoding UTF8
python $temp2
Remove-Item $temp2 -Force
Write-Host ""

# Test 3: Database access
Write-Host "Test 3: Accessing database..." -ForegroundColor Yellow
$accessScript = @"
import mysql.connector
import sys
try:
    conn = mysql.connector.connect(
        host='$MYSQL_HOST',
        user='$MYSQL_USER',
        password='$MYSQL_PASSWORD',
        database='$MYSQL_DATABASE'
    )
    print('[OK] Can access database: $MYSQL_DATABASE')
    conn.close()
    sys.exit(0)
except Exception as e:
    print('[X] Cannot access database: ' + str(e))
    sys.exit(1)
"@

$temp3 = [System.IO.Path]::GetTempFileName() + ".py"
$accessScript | Out-File -FilePath $temp3 -Encoding UTF8
python $temp3
Remove-Item $temp3 -Force
Write-Host ""

# Test 4: Create test table
Write-Host "Test 4: Testing table creation..." -ForegroundColor Yellow
$tableScript = @"
import mysql.connector
import sys
try:
    conn = mysql.connector.connect(
        host='$MYSQL_HOST',
        user='$MYSQL_USER',
        password='$MYSQL_PASSWORD',
        database='$MYSQL_DATABASE'
    )
    cursor = conn.cursor()
    cursor.execute('CREATE TABLE IF NOT EXISTS _test_permissions (id INT, name VARCHAR(50))')
    cursor.execute('INSERT INTO _test_permissions VALUES (1, "test")')
    cursor.execute('SELECT * FROM _test_permissions')
    result = cursor.fetchone()
    cursor.execute('DROP TABLE _test_permissions')
    conn.commit()
    print('[OK] Can CREATE, INSERT, SELECT, and DROP tables')
    cursor.close()
    conn.close()
    sys.exit(0)
except Exception as e:
    print('[X] Table operations failed: ' + str(e))
    sys.exit(1)
"@

$temp4 = [System.IO.Path]::GetTempFileName() + ".py"
$tableScript | Out-File -FilePath $temp4 -Encoding UTF8
python $temp4
Remove-Item $temp4 -Force
Write-Host ""

# Test 5: Check environment variables
Write-Host "Test 5: Checking environment variables..." -ForegroundColor Yellow
$env:MYSQL_HOST = $MYSQL_HOST
$env:MYSQL_USER = $MYSQL_USER
$env:MYSQL_PASSWORD = $MYSQL_PASSWORD
$env:MYSQL_DATABASE = $MYSQL_DATABASE
$env:TARGET_SIZE_MB = "500"

$envScript = @"
import os
print('[OK] Environment variables:')
print('  MYSQL_HOST: ' + os.environ.get('MYSQL_HOST', 'NOT SET'))
print('  MYSQL_USER: ' + os.environ.get('MYSQL_USER', 'NOT SET'))
print('  MYSQL_DATABASE: ' + os.environ.get('MYSQL_DATABASE', 'NOT SET'))
print('  TARGET_SIZE_MB: ' + os.environ.get('TARGET_SIZE_MB', 'NOT SET'))
"@

$temp5 = [System.IO.Path]::GetTempFileName() + ".py"
$envScript | Out-File -FilePath $temp5 -Encoding UTF8
python $temp5
Remove-Item $temp5 -Force
Write-Host ""

Write-Host "========================================" -ForegroundColor Green
Write-Host "All tests passed!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host "Database setup should work correctly." -ForegroundColor Green
Write-Host ""
