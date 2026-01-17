#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Diagnose MySQL connection issues

.DESCRIPTION
    Tests MySQL connection with both root and dms_remote users
    to identify which credentials work
#>

$MYSQL_HOST = "172.20.10.4"
$MYSQL_DATABASE = "ecommerce"

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "MySQL Connection Diagnostics" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Test 1: Check if mysql-connector-python is installed
Write-Host "Test 1: Checking mysql-connector-python..." -ForegroundColor Yellow
$checkScript = @"
import sys
try:
    import mysql.connector
    print('[OK] mysql-connector-python is installed')
    print('[OK] Version: ' + mysql.connector.__version__)
    sys.exit(0)
except ImportError:
    print('[X] mysql-connector-python is NOT installed')
    print('    Install with: pip install mysql-connector-python')
    sys.exit(1)
"@

$tempCheck = [System.IO.Path]::GetTempFileName() + ".py"
$checkScript | Out-File -FilePath $tempCheck -Encoding UTF8

try {
    python $tempCheck
    if ($LASTEXITCODE -ne 0) {
        Write-Host "`nInstalling mysql-connector-python..." -ForegroundColor Yellow
        pip install mysql-connector-python
    }
} finally {
    Remove-Item $tempCheck -Force
}

Write-Host ""

# Test 2: Test connection with root user
Write-Host "Test 2: Testing connection with root user..." -ForegroundColor Yellow
Write-Host "  Host: $MYSQL_HOST" -ForegroundColor White
Write-Host "  User: root" -ForegroundColor White
Write-Host "  Password: Srikar@123" -ForegroundColor White

$rootTestScript = @"
import mysql.connector
import sys
try:
    conn = mysql.connector.connect(
        host='$MYSQL_HOST',
        user='root',
        password='Srikar@123'
    )
    cursor = conn.cursor()
    cursor.execute('SELECT VERSION()')
    version = cursor.fetchone()
    print('[OK] Connection successful with root user!')
    print('[OK] MySQL version: ' + str(version[0]))
    cursor.close()
    conn.close()
    sys.exit(0)
except Exception as e:
    print('[X] Connection failed with root user')
    print('[X] Error: ' + str(e))
    sys.exit(1)
"@

$tempRoot = [System.IO.Path]::GetTempFileName() + ".py"
$rootTestScript | Out-File -FilePath $tempRoot -Encoding UTF8

try {
    python $tempRoot
    $rootSuccess = ($LASTEXITCODE -eq 0)
} finally {
    Remove-Item $tempRoot -Force
}

Write-Host ""

# Test 3: Test connection with dms_remote user
Write-Host "Test 3: Testing connection with dms_remote user..." -ForegroundColor Yellow
Write-Host "  Host: $MYSQL_HOST" -ForegroundColor White
Write-Host "  User: dms_remote" -ForegroundColor White
Write-Host "  Password: SaiesaShanmukha@123" -ForegroundColor White

$dmsTestScript = @"
import mysql.connector
import sys
try:
    conn = mysql.connector.connect(
        host='$MYSQL_HOST',
        user='dms_remote',
        password='SaiesaShanmukha@123'
    )
    cursor = conn.cursor()
    cursor.execute('SELECT VERSION()')
    version = cursor.fetchone()
    print('[OK] Connection successful with dms_remote user!')
    print('[OK] MySQL version: ' + str(version[0]))
    cursor.close()
    conn.close()
    sys.exit(0)
except Exception as e:
    print('[X] Connection failed with dms_remote user')
    print('[X] Error: ' + str(e))
    sys.exit(1)
"@

$tempDms = [System.IO.Path]::GetTempFileName() + ".py"
$dmsTestScript | Out-File -FilePath $tempDms -Encoding UTF8

try {
    python $tempDms
    $dmsSuccess = ($LASTEXITCODE -eq 0)
} finally {
    Remove-Item $tempDms -Force
}

Write-Host ""

# Test 4: Test database access
Write-Host "Test 4: Testing database access to '$MYSQL_DATABASE'..." -ForegroundColor Yellow

$dbTestScript = @"
import mysql.connector
import sys

# Try with whichever user worked
users = [
    ('root', 'Srikar@123'),
    ('dms_remote', 'SaiesaShanmukha@123')
]

for user, password in users:
    try:
        conn = mysql.connector.connect(
            host='$MYSQL_HOST',
            user=user,
            password=password,
            database='$MYSQL_DATABASE'
        )
        cursor = conn.cursor()
        cursor.execute('SHOW TABLES')
        tables = cursor.fetchall()
        print('[OK] Connected to database with user: ' + user)
        if tables:
            print('[OK] Found ' + str(len(tables)) + ' tables')
            for table in tables[:5]:
                print('     - ' + table[0])
        else:
            print('[!] Database exists but has no tables')
        cursor.close()
        conn.close()
        sys.exit(0)
    except Exception as e:
        print('[X] Failed with user ' + user + ': ' + str(e))
        continue

print('[X] Could not connect to database with any user')
sys.exit(1)
"@

$tempDb = [System.IO.Path]::GetTempFileName() + ".py"
$dbTestScript | Out-File -FilePath $tempDb -Encoding UTF8

try {
    python $tempDb
} finally {
    Remove-Item $tempDb -Force
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Diagnostic Summary" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

if ($rootSuccess) {
    Write-Host "[OK] root user can connect" -ForegroundColor Green
} else {
    Write-Host "[X] root user CANNOT connect" -ForegroundColor Red
}

if ($dmsSuccess) {
    Write-Host "[OK] dms_remote user can connect" -ForegroundColor Green
} else {
    Write-Host "[X] dms_remote user CANNOT connect" -ForegroundColor Red
}

Write-Host ""

if (-not $rootSuccess -and -not $dmsSuccess) {
    Write-Host "RECOMMENDATION: Check MySQL server status and firewall rules" -ForegroundColor Yellow
} elseif (-not $rootSuccess -and $dmsSuccess) {
    Write-Host "RECOMMENDATION: Use dms_remote user for deployment script" -ForegroundColor Yellow
    Write-Host "  or grant privileges to root user from your IP" -ForegroundColor Yellow
} elseif ($rootSuccess -and -not $dmsSuccess) {
    Write-Host "RECOMMENDATION: Deployment script should work with root user" -ForegroundColor Green
} else {
    Write-Host "RECOMMENDATION: Both users work - deployment script should succeed" -ForegroundColor Green
}

Write-Host ""
