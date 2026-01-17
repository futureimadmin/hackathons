#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Create ecommerce database if it doesn't exist

.EXAMPLE
    .\create-database.ps1
#>

param(
    [string]$MySQLHost = "172.20.10.4",
    [string]$MySQLUser = "root",
    [string]$MySQLPassword = "Srikar@123",
    [string]$MySQLDatabase = "ecommerce",
    [int]$MySQLPort = 3306
)

Write-Host "`nCreating database: $MySQLDatabase..." -ForegroundColor Cyan

# Create Python script
$pythonScript = @"
import sys
import mysql.connector
from mysql.connector import Error

try:
    # Connect without specifying database
    connection = mysql.connector.connect(
        host='$MySQLHost',
        port=$MySQLPort,
        user='$MySQLUser',
        password='$MySQLPassword'
    )
    
    if connection.is_connected():
        cursor = connection.cursor()
        
        # Create database
        cursor.execute("CREATE DATABASE IF NOT EXISTS $MySQLDatabase")
        print(f"[OK] Database '$MySQLDatabase' created or already exists")
        
        # Verify
        cursor.execute("SHOW DATABASES LIKE '$MySQLDatabase'")
        result = cursor.fetchone()
        if result:
            print(f"[OK] Database '$MySQLDatabase' verified")
        
        cursor.close()
        connection.close()
        sys.exit(0)
        
except Error as e:
    print(f"[X] Error: {e}")
    sys.exit(1)
"@

# Save and run Python script
$tempScript = [System.IO.Path]::GetTempFileName() + ".py"
$pythonScript | Out-File -FilePath $tempScript -Encoding UTF8

try {
    python $tempScript
    $exitCode = $LASTEXITCODE
    
    if ($exitCode -eq 0) {
        Write-Host "[OK] Database creation successful!" -ForegroundColor Green
        return $true
    } else {
        Write-Host "[X] Database creation failed!" -ForegroundColor Red
        return $false
    }
} finally {
    if (Test-Path $tempScript) {
        Remove-Item $tempScript -Force
    }
}
