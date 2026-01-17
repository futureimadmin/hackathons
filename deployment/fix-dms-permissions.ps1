#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Fix dms_remote user permissions for ecommerce database

.DESCRIPTION
    Grants full privileges to dms_remote user on ecommerce database
#>

$MYSQL_HOST = "172.20.10.4"
$MYSQL_USER = "dms_remote"
$MYSQL_PASSWORD = "SaiesaShanmukha@123"
$MYSQL_DATABASE = "ecommerce"

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Checking dms_remote Permissions" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Check current permissions
Write-Host "Checking current permissions for dms_remote..." -ForegroundColor Yellow

$checkScript = @"
import mysql.connector
import sys

try:
    # Connect as dms_remote
    conn = mysql.connector.connect(
        host='$MYSQL_HOST',
        user='$MYSQL_USER',
        password='$MYSQL_PASSWORD'
    )
    
    cursor = conn.cursor()
    
    # Check grants
    cursor.execute("SHOW GRANTS FOR '$MYSQL_USER'@'%'")
    grants = cursor.fetchall()
    
    print('[OK] Current grants for dms_remote@%:')
    for grant in grants:
        print('  ' + grant[0])
    
    # Check if database exists
    cursor.execute("SHOW DATABASES LIKE '$MYSQL_DATABASE'")
    db_exists = cursor.fetchone()
    
    if db_exists:
        print('[OK] Database $MYSQL_DATABASE exists')
    else:
        print('[X] Database $MYSQL_DATABASE does NOT exist')
    
    # Try to access the database
    try:
        cursor.execute("USE $MYSQL_DATABASE")
        print('[OK] Can access database $MYSQL_DATABASE')
        
        # Try to show tables
        cursor.execute("SHOW TABLES")
        tables = cursor.fetchall()
        print('[OK] Can list tables (' + str(len(tables)) + ' tables found)')
        
        # Try to create a test table
        try:
            cursor.execute("CREATE TABLE IF NOT EXISTS _permission_test (id INT)")
            cursor.execute("DROP TABLE IF EXISTS _permission_test")
            print('[OK] Can CREATE and DROP tables')
        except Exception as e:
            print('[X] Cannot CREATE/DROP tables: ' + str(e))
            
    except Exception as e:
        print('[X] Cannot access database: ' + str(e))
    
    cursor.close()
    conn.close()
    sys.exit(0)
    
except Exception as e:
    print('[X] Error: ' + str(e))
    sys.exit(1)
"@

$tempCheck = [System.IO.Path]::GetTempFileName() + ".py"
$checkScript | Out-File -FilePath $tempCheck -Encoding UTF8

try {
    python $tempCheck
    $checkResult = $LASTEXITCODE
} finally {
    Remove-Item $tempCheck -Force
}

Write-Host ""

if ($checkResult -ne 0) {
    Write-Host "========================================" -ForegroundColor Red
    Write-Host "PERMISSIONS ISSUE DETECTED" -ForegroundColor Red
    Write-Host "========================================`n" -ForegroundColor Red
    
    Write-Host "To fix this, you need to grant permissions as root user." -ForegroundColor Yellow
    Write-Host "Run these commands in MySQL as root:`n" -ForegroundColor Yellow
    
    Write-Host "mysql -u root -p" -ForegroundColor White
    Write-Host "-- Then run these SQL commands:" -ForegroundColor Gray
    Write-Host "GRANT ALL PRIVILEGES ON $MYSQL_DATABASE.* TO '$MYSQL_USER'@'%';" -ForegroundColor Cyan
    Write-Host "FLUSH PRIVILEGES;" -ForegroundColor Cyan
    Write-Host "EXIT;" -ForegroundColor Cyan
    Write-Host ""
    
    Write-Host "Or run this one-liner:" -ForegroundColor Yellow
    Write-Host "mysql -u root -p -e `"GRANT ALL PRIVILEGES ON $MYSQL_DATABASE.* TO '$MYSQL_USER'@'%'; FLUSH PRIVILEGES;`"" -ForegroundColor White
    Write-Host ""
} else {
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "PERMISSIONS OK" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "dms_remote user has proper permissions on $MYSQL_DATABASE" -ForegroundColor Green
    Write-Host ""
}
