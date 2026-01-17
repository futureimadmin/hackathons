#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Test MySQL connection using Python instead of MySQL client

.DESCRIPTION
    This script tests MySQL connectivity using Python's mysql-connector library
    which doesn't require MySQL client installation

.EXAMPLE
    .\test-mysql-connection.ps1
#>

param(
    [string]$MySQLHost = "172.20.10.4",
    [string]$MySQLUser = "dms_remote",
    [string]$MySQLPassword = "SaiesaShanmukha@123",
    [string]$MySQLDatabase = "ecommerce",
    [int]$MySQLPort = 3306
)

Write-Host "`nTesting MySQL Connection..." -ForegroundColor Cyan
Write-Host "Host: $MySQLHost" -ForegroundColor White
Write-Host "Port: $MySQLPort" -ForegroundColor White
Write-Host "User: $MySQLUser" -ForegroundColor White
Write-Host "Database: $MySQLDatabase" -ForegroundColor White

# Create Python test script
$pythonScript = @"
import sys
try:
    import mysql.connector
    from mysql.connector import Error
    
    try:
        connection = mysql.connector.connect(
            host='$MySQLHost',
            port=$MySQLPort,
            user='$MySQLUser',
            password='$MySQLPassword',
            database='$MySQLDatabase'
        )
        
        if connection.is_connected():
            db_info = connection.get_server_info()
            print(f"[OK] Successfully connected to MySQL Server version {db_info}")
            
            cursor = connection.cursor()
            cursor.execute("SELECT DATABASE();")
            record = cursor.fetchone()
            print(f"[OK] Connected to database: {record[0]}")
            
            cursor.execute("SHOW TABLES;")
            tables = cursor.fetchall()
            if tables:
                print(f"[OK] Found {len(tables)} tables in database")
                for table in tables[:5]:
                    print(f"     - {table[0]}")
                if len(tables) > 5:
                    print(f"     ... and {len(tables) - 5} more")
            else:
                print("[!] No tables found in database")
            
            cursor.close()
            connection.close()
            print("[OK] MySQL connection test successful!")
            sys.exit(0)
            
    except Error as e:
        print(f"[X] Error connecting to MySQL: {e}")
        sys.exit(1)
        
except ImportError:
    print("[X] mysql-connector-python not installed")
    print("    Install it with: pip install mysql-connector-python")
    sys.exit(2)
"@

# Save Python script temporarily
$tempScript = [System.IO.Path]::GetTempFileName() + ".py"
$pythonScript | Out-File -FilePath $tempScript -Encoding UTF8

try {
    # Run Python script
    python $tempScript
    $exitCode = $LASTEXITCODE
    
    if ($exitCode -eq 0) {
        Write-Host "`n[OK] MySQL connection test passed!" -ForegroundColor Green
        return $true
    } elseif ($exitCode -eq 2) {
        Write-Host "`n[!] Installing mysql-connector-python..." -ForegroundColor Yellow
        pip install mysql-connector-python
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "[OK] Package installed. Retrying connection..." -ForegroundColor Green
            python $tempScript
            if ($LASTEXITCODE -eq 0) {
                Write-Host "`n[OK] MySQL connection test passed!" -ForegroundColor Green
                return $true
            }
        }
    }
    
    Write-Host "`n[X] MySQL connection test failed!" -ForegroundColor Red
    return $false
    
} finally {
    # Clean up temp file
    if (Test-Path $tempScript) {
        Remove-Item $tempScript -Force
    }
}
