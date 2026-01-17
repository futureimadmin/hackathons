#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Configure MySQL to accept connections from IP address 172.20.10.4

.DESCRIPTION
    This script automates the configuration of MySQL to accept network connections

.EXAMPLE
    .\configure-mysql-ip-access.ps1
#>

param(
    [string]$MySQLHost = "172.20.10.4",
    [string]$MySQLUser = "root",
    [string]$MySQLPassword = "Srikar@123",
    [int]$MySQLPort = 3306
)

$COLOR_GREEN = "Green"
$COLOR_RED = "Red"
$COLOR_YELLOW = "Yellow"
$COLOR_CYAN = "Cyan"
$COLOR_WHITE = "White"

function Write-ColorOutput {
    param([string]$Message, [string]$Color = "White")
    Write-Host $Message -ForegroundColor $Color
}

function Write-StepHeader {
    param([string]$StepNumber, [string]$Title)
    Write-ColorOutput "`n========================================" $COLOR_CYAN
    Write-ColorOutput "STEP $StepNumber : $Title" $COLOR_CYAN
    Write-ColorOutput "========================================" $COLOR_CYAN
}

# Check if running as Administrator
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-ColorOutput "[X] This script must be run as Administrator!" $COLOR_RED
    Write-ColorOutput "    Right-click PowerShell and select 'Run as Administrator'" $COLOR_YELLOW
    exit 1
}

Write-ColorOutput @"

╔═══════════════════════════════════════════════════════════╗
║   MySQL IP Access Configuration                          ║
║   Configure MySQL for 172.20.10.4 Access                 ║
╚═══════════════════════════════════════════════════════════╝

"@ $COLOR_CYAN

# ============================================================================
# STEP 1: Locate my.ini File
# ============================================================================

Write-StepHeader "1" "Locate MySQL Configuration File (my.ini)"

$possiblePaths = @(
    "C:\ProgramData\MySQL\MySQL Server 8.0\my.ini",
    "C:\Program Files\MySQL\MySQL Server 8.0\my.ini",
    "C:\MySQL\my.ini"
)

$myIniPath = $null
foreach ($path in $possiblePaths) {
    if (Test-Path $path) {
        $myIniPath = $path
        Write-ColorOutput "[OK] Found my.ini at: $myIniPath" $COLOR_GREEN
        break
    }
}

if (-not $myIniPath) {
    Write-ColorOutput "[!] Searching for my.ini in common locations..." $COLOR_YELLOW
    $found = Get-ChildItem -Path "C:\ProgramData\MySQL" -Filter "my.ini" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($found) {
        $myIniPath = $found.FullName
        Write-ColorOutput "[OK] Found my.ini at: $myIniPath" $COLOR_GREEN
    } else {
        Write-ColorOutput "[X] Could not locate my.ini file!" $COLOR_RED
        Write-ColorOutput "    Please specify the path manually" $COLOR_YELLOW
        exit 1
    }
}

# ============================================================================
# STEP 2: Backup Current Configuration
# ============================================================================

Write-StepHeader "2" "Backup Current Configuration"

$backupPath = "$myIniPath.backup-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
try {
    Copy-Item $myIniPath $backupPath -Force
    Write-ColorOutput "[OK] Backup created: $backupPath" $COLOR_GREEN
} catch {
    Write-ColorOutput "[X] Failed to create backup: $_" $COLOR_RED
    exit 1
}

# ============================================================================
# STEP 3: Update my.ini Configuration
# ============================================================================

Write-StepHeader "3" "Update my.ini Configuration"

try {
    $content = Get-Content $myIniPath -Raw
    
    # Check if bind-address already exists
    if ($content -match 'bind-address\s*=') {
        Write-ColorOutput "[!] bind-address setting found, updating..." $COLOR_YELLOW
        $content = $content -replace 'bind-address\s*=\s*[^\r\n]+', "bind-address = 0.0.0.0"
    } else {
        Write-ColorOutput "[!] bind-address not found, adding to [mysqld] section..." $COLOR_YELLOW
        # Add after [mysqld] section
        if ($content -match '\[mysqld\]') {
            $content = $content -replace '(\[mysqld\][^\[]*)', "`$1`nbind-address = 0.0.0.0`nskip-name-resolve`n"
        } else {
            Write-ColorOutput "[X] Could not find [mysqld] section in my.ini" $COLOR_RED
            exit 1
        }
    }
    
    # Write updated content
    $content | Out-File -FilePath $myIniPath -Encoding UTF8 -Force
    Write-ColorOutput "[OK] my.ini updated successfully" $COLOR_GREEN
    Write-ColorOutput "    bind-address = 0.0.0.0" $COLOR_CYAN
    Write-ColorOutput "    skip-name-resolve" $COLOR_CYAN
    
} catch {
    Write-ColorOutput "[X] Failed to update my.ini: $_" $COLOR_RED
    Write-ColorOutput "[!] Restoring backup..." $COLOR_YELLOW
    Copy-Item $backupPath $myIniPath -Force
    exit 1
}

# ============================================================================
# STEP 4: Restart MySQL Service
# ============================================================================

Write-StepHeader "4" "Restart MySQL Service"

try {
    Write-ColorOutput "[!] Stopping MySQL service..." $COLOR_YELLOW
    Stop-Service -Name "MySQL80" -Force -ErrorAction Stop
    Start-Sleep -Seconds 3
    
    Write-ColorOutput "[!] Starting MySQL service..." $COLOR_YELLOW
    Start-Service -Name "MySQL80" -ErrorAction Stop
    Start-Sleep -Seconds 3
    
    $service = Get-Service -Name "MySQL80"
    if ($service.Status -eq "Running") {
        Write-ColorOutput "[OK] MySQL service restarted successfully" $COLOR_GREEN
    } else {
        Write-ColorOutput "[X] MySQL service is not running!" $COLOR_RED
        exit 1
    }
} catch {
    Write-ColorOutput "[X] Failed to restart MySQL service: $_" $COLOR_RED
    Write-ColorOutput "[!] Restoring backup configuration..." $COLOR_YELLOW
    Copy-Item $backupPath $myIniPath -Force
    Start-Service -Name "MySQL80" -ErrorAction SilentlyContinue
    exit 1
}

# ============================================================================
# STEP 5: Grant Privileges to Existing Root User
# ============================================================================

Write-StepHeader "5" "Grant Privileges for IP Access"

Write-ColorOutput "[!] Granting privileges to root user for IP access..." $COLOR_YELLOW
Write-ColorOutput "    Note: Root user already exists, just updating permissions" $COLOR_CYAN

# Use Python to execute SQL commands
$pythonScript = @"
import sys
import mysql.connector
from mysql.connector import Error

try:
    connection = mysql.connector.connect(
        host='localhost',
        user='$MySQLUser',
        password='$MySQLPassword'
    )
    
    if connection.is_connected():
        cursor = connection.cursor()
        
        # Grant privileges for specific IP
        cursor.execute("GRANT ALL PRIVILEGES ON *.* TO '$MySQLUser'@'$MySQLHost' IDENTIFIED BY '$MySQLPassword' WITH GRANT OPTION")
        print("[OK] Granted privileges for $MySQLUser@$MySQLHost")
        
        # Grant privileges for IP subnet
        cursor.execute("GRANT ALL PRIVILEGES ON *.* TO '$MySQLUser'@'172.20.10.%' IDENTIFIED BY '$MySQLPassword' WITH GRANT OPTION")
        print("[OK] Granted privileges for $MySQLUser@172.20.10.%")
        
        # Flush privileges
        cursor.execute("FLUSH PRIVILEGES")
        print("[OK] Privileges flushed")
        
        # Show users
        cursor.execute("SELECT user, host FROM mysql.user WHERE user = '$MySQLUser'")
        users = cursor.fetchall()
        print("[OK] Current root users:")
        for user in users:
            print(f"     - {user[0]}@{user[1]}")
        
        cursor.close()
        connection.close()
        sys.exit(0)
        
except Error as e:
    print(f"[X] Error: {e}")
    sys.exit(1)
"@

$tempScript = [System.IO.Path]::GetTempFileName() + ".py"
$pythonScript | Out-File -FilePath $tempScript -Encoding UTF8

try {
    python $tempScript
    if ($LASTEXITCODE -eq 0) {
        Write-ColorOutput "[OK] Privileges granted successfully" $COLOR_GREEN
    } else {
        Write-ColorOutput "[X] Failed to grant privileges" $COLOR_RED
    }
} catch {
    Write-ColorOutput "[X] Error granting privileges: $_" $COLOR_RED
} finally {
    if (Test-Path $tempScript) {
        Remove-Item $tempScript -Force
    }
}

# ============================================================================
# STEP 6: Configure Windows Firewall
# ============================================================================

Write-StepHeader "6" "Configure Windows Firewall"

try {
    # Check if rule already exists
    $existingRule = Get-NetFirewallRule -DisplayName "MySQL Server" -ErrorAction SilentlyContinue
    
    if ($existingRule) {
        Write-ColorOutput "[!] Firewall rule already exists, updating..." $COLOR_YELLOW
        Remove-NetFirewallRule -DisplayName "MySQL Server" -ErrorAction SilentlyContinue
    }
    
    New-NetFirewallRule -DisplayName "MySQL Server" `
        -Direction Inbound `
        -Protocol TCP `
        -LocalPort $MySQLPort `
        -Action Allow `
        -ErrorAction Stop | Out-Null
    
    Write-ColorOutput "[OK] Windows Firewall configured" $COLOR_GREEN
    Write-ColorOutput "    Allowed TCP port $MySQLPort" $COLOR_CYAN
} catch {
    Write-ColorOutput "[!] Warning: Could not configure firewall: $_" $COLOR_YELLOW
    Write-ColorOutput "    You may need to configure firewall manually" $COLOR_YELLOW
}

# ============================================================================
# STEP 7: Verify Configuration
# ============================================================================

Write-StepHeader "7" "Verify Configuration"

Write-ColorOutput "[!] Checking if MySQL is listening on correct interface..." $COLOR_YELLOW
$netstat = netstat -an | Select-String "3306"
if ($netstat) {
    Write-ColorOutput "[OK] MySQL is listening:" $COLOR_GREEN
    $netstat | ForEach-Object { Write-ColorOutput "    $_" $COLOR_CYAN }
} else {
    Write-ColorOutput "[X] MySQL is not listening on port 3306!" $COLOR_RED
}

# ============================================================================
# STEP 8: Test Connection
# ============================================================================

Write-StepHeader "8" "Test Connection from IP Address"

Write-ColorOutput "[!] Testing connection to $MySQLHost..." $COLOR_YELLOW

# Test using Python script
$pythonTestScript = @"
import sys
try:
    import mysql.connector
    from mysql.connector import Error
    
    try:
        connection = mysql.connector.connect(
            host='$MySQLHost',
            port=$MySQLPort,
            user='$MySQLUser',
            password='$MySQLPassword'
        )
        
        if connection.is_connected():
            db_info = connection.get_server_info()
            print(f"[OK] Successfully connected to MySQL Server version {db_info}")
            print(f"[OK] Connection from IP: $MySQLHost")
            
            cursor = connection.cursor()
            cursor.execute("SELECT USER(), @@hostname;")
            result = cursor.fetchone()
            print(f"[OK] Connected as: {result[0]}")
            print(f"[OK] Server hostname: {result[1]}")
            
            cursor.close()
            connection.close()
            sys.exit(0)
            
    except Error as e:
        print(f"[X] Error connecting to MySQL: {e}")
        sys.exit(1)
        
except ImportError:
    print("[X] mysql-connector-python not installed")
    print("    Install it with: pip install mysql-connector-python")
    sys.exit(2)
"@

$tempTestScript = [System.IO.Path]::GetTempFileName() + ".py"
$pythonTestScript | Out-File -FilePath $tempTestScript -Encoding UTF8

try {
    python $tempTestScript
    $exitCode = $LASTEXITCODE
    
    if ($exitCode -eq 0) {
        Write-ColorOutput "`n[OK] Connection test PASSED!" $COLOR_GREEN
    } elseif ($exitCode -eq 2) {
        Write-ColorOutput "`n[!] Installing mysql-connector-python..." $COLOR_YELLOW
        pip install mysql-connector-python
        python $tempTestScript
        if ($LASTEXITCODE -eq 0) {
            Write-ColorOutput "`n[OK] Connection test PASSED!" $COLOR_GREEN
        } else {
            Write-ColorOutput "`n[X] Connection test FAILED!" $COLOR_RED
        }
    } else {
        Write-ColorOutput "`n[X] Connection test FAILED!" $COLOR_RED
    }
} finally {
    if (Test-Path $tempTestScript) {
        Remove-Item $tempTestScript -Force
    }
}

# ============================================================================
# Summary
# ============================================================================

Write-ColorOutput "`n╔═══════════════════════════════════════════════════════════╗" $COLOR_GREEN
Write-ColorOutput "║   CONFIGURATION COMPLETE                                 ║" $COLOR_GREEN
Write-ColorOutput "╚═══════════════════════════════════════════════════════════╝" $COLOR_GREEN

Write-ColorOutput "`nConfiguration Summary:" $COLOR_CYAN
Write-ColorOutput "  - my.ini location: $myIniPath" $COLOR_WHITE
Write-ColorOutput "  - Backup created: $backupPath" $COLOR_WHITE
Write-ColorOutput "  - bind-address: 0.0.0.0 (all interfaces)" $COLOR_WHITE
Write-ColorOutput "  - MySQL privileges granted for: $MySQLHost" $COLOR_WHITE
Write-ColorOutput "  - Firewall rule: Enabled for port $MySQLPort" $COLOR_WHITE

Write-ColorOutput "`nNext Steps:" $COLOR_CYAN
Write-ColorOutput "1. Run deployment script with IP address configuration" $COLOR_WHITE
Write-ColorOutput "2. Monitor MySQL error log for any issues" $COLOR_WHITE
Write-ColorOutput "3. Test database operations" $COLOR_WHITE

Write-ColorOutput "`nMySQL Error Log Location:" $COLOR_CYAN
Write-ColorOutput "  C:\ProgramData\MySQL\MySQL Server 8.0\Data\*.err" $COLOR_WHITE

Write-ColorOutput "`nTo revert changes:" $COLOR_YELLOW
$revertCmd1 = "  Copy-Item `"$backupPath`" `"$myIniPath`" -Force"
$revertCmd2 = "  Restart-Service -Name MySQL80"
Write-ColorOutput $revertCmd1 $COLOR_YELLOW
Write-ColorOutput $revertCmd2 $COLOR_YELLOW

exit 0
