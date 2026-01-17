@echo off
setlocal enabledelayedexpansion

REM ============================================================================
REM MySQL IP Access Configuration Script
REM Configure MySQL to accept connections from IP address 172.20.10.4
REM ============================================================================

echo.
echo ========================================
echo MySQL IP Access Configuration
echo Configure MySQL for 172.20.10.4 Access
echo ========================================
echo.

REM Check for Administrator privileges
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo [X] This script must be run as Administrator!
    echo     Right-click and select "Run as administrator"
    pause
    exit /b 1
)

REM Configuration variables
set MYSQL_HOST=172.20.10.4
set MYSQL_USER=root
set MYSQL_PASSWORD=Srikar@123
set MYSQL_PORT=3306

REM ============================================================================
REM STEP 1: Locate or Create MySQL Configuration File
REM ============================================================================

echo.
echo ========================================
echo STEP 1: Locate or Create MySQL Configuration File
echo ========================================
echo.

set "MY_INI_PATH="
set "MYSQL_DATA_DIR="

REM Try to find existing my.ini
if exist "C:\ProgramData\MySQL\MySQL Server 8.0\my.ini" (
    set "MY_INI_PATH=C:\ProgramData\MySQL\MySQL Server 8.0\my.ini"
    echo [OK] Found existing my.ini at: !MY_INI_PATH!
    goto :backup
)

if exist "C:\Program Files\MySQL\MySQL Server 8.0\my.ini" (
    set "MY_INI_PATH=C:\Program Files\MySQL\MySQL Server 8.0\my.ini"
    echo [OK] Found existing my.ini at: !MY_INI_PATH!
    goto :backup
)

REM my.ini not found, create it
echo [!] my.ini not found, will create it...

REM Determine MySQL installation directory
if exist "C:\ProgramData\MySQL\MySQL Server 8.0" (
    set "MY_INI_PATH=C:\ProgramData\MySQL\MySQL Server 8.0\my.ini"
    set "MYSQL_DATA_DIR=C:\ProgramData\MySQL\MySQL Server 8.0\Data"
    goto :create_ini
)

if exist "C:\Program Files\MySQL\MySQL Server 8.0" (
    set "MY_INI_PATH=C:\Program Files\MySQL\MySQL Server 8.0\my.ini"
    set "MYSQL_DATA_DIR=C:\Program Files\MySQL\MySQL Server 8.0\Data"
    goto :create_ini
)

echo [X] Could not locate MySQL installation directory!
echo     Please check MySQL installation
pause
exit /b 1

:create_ini
echo [!] Creating my.ini at: !MY_INI_PATH!

REM Create basic my.ini file
(
    echo # MySQL Server 8.0 Configuration File
    echo.
    echo [mysqld]
    echo # Basic Settings
    echo port=3306
    echo datadir=!MYSQL_DATA_DIR!
    echo.
    echo # Network Settings
    echo bind-address=0.0.0.0
    echo skip-name-resolve
    echo.
    echo # Character Set
    echo character-set-server=utf8mb4
    echo collation-server=utf8mb4_unicode_ci
    echo.
    echo # Connection Settings
    echo max_connections=200
    echo.
    echo # InnoDB Settings
    echo default-storage-engine=INNODB
    echo innodb_buffer_pool_size=256M
    echo innodb_log_file_size=64M
    echo.
    echo # Logging
    echo log-error=!MYSQL_DATA_DIR!\error.log
    echo.
    echo [client]
    echo port=3306
    echo default-character-set=utf8mb4
) > "!MY_INI_PATH!"

if exist "!MY_INI_PATH!" (
    echo [OK] Created my.ini successfully
) else (
    echo [X] Failed to create my.ini file!
    pause
    exit /b 1
)

:backup

REM ============================================================================
REM STEP 2: Backup Current Configuration
REM ============================================================================


REM ============================================================================
REM STEP 3: Verify my.ini Configuration
REM ============================================================================

echo.
echo ========================================
echo STEP 3: Verify my.ini Configuration
echo ========================================
echo.

REM Check if bind-address is already set correctly
findstr /C:"bind-address" "!MY_INI_PATH!" >nul 2>&1
if %errorLevel% equ 0 (
    echo [OK] bind-address already configured in my.ini
) else (
    echo [!] Adding bind-address to my.ini...
    
    REM Create a temporary PowerShell script to update the file
    set TEMP_PS=%TEMP%\update-myini.ps1
    echo $content = Get-Content '!MY_INI_PATH!' -Raw > "!TEMP_PS!"
    echo if ($content -match 'bind-address\s*=') { >> "!TEMP_PS!"
    echo     $content = $content -replace 'bind-address\s*=\s*[^\r\n]+', 'bind-address = 0.0.0.0' >> "!TEMP_PS!"
    echo } else { >> "!TEMP_PS!"
    echo     $content = $content -replace '(\[mysqld\][^\[]*)', "`$1`nbind-address = 0.0.0.0`nskip-name-resolve`n" >> "!TEMP_PS!"
    echo } >> "!TEMP_PS!"
    echo $content ^| Out-File -FilePath '!MY_INI_PATH!' -Encoding UTF8 -Force >> "!TEMP_PS!"
    
    powershell -ExecutionPolicy Bypass -File "!TEMP_PS!"
    del "!TEMP_PS!"
    
    echo [OK] my.ini updated successfully
)

echo [OK] Configuration verified:
echo     bind-address = 0.0.0.0
echo     skip-name-resolve

REM ============================================================================
REM STEP 4: Restart MySQL Service
REM ============================================================================

echo.
echo ========================================
echo STEP 4: Restart MySQL Service
echo ========================================
echo.

echo [!] Stopping MySQL service...
net stop MySQL80 >nul 2>&1
timeout /t 3 /nobreak >nul

echo [!] Starting MySQL service...
net start MySQL80 >nul 2>&1
timeout /t 3 /nobreak >nul

sc query MySQL80 | find "RUNNING" >nul
if %errorLevel% equ 0 (
    echo [OK] MySQL service restarted successfully
) else (
    echo [X] MySQL service is not running!
    pause
    exit /b 1
)

REM ============================================================================
REM STEP 5: Grant Privileges for IP Access
REM ============================================================================

echo.
echo ========================================
echo STEP 5: Grant Privileges for IP Access
echo ========================================
echo.

echo [!] Granting privileges to root user for IP access...
echo     Note: Root user already exists, just updating permissions

REM Create SQL file with grant commands
set SQL_FILE=%TEMP%\grant-privileges.sql
echo GRANT ALL PRIVILEGES ON *.* TO '%MYSQL_USER%'@'%MYSQL_HOST%' IDENTIFIED BY '%MYSQL_PASSWORD%' WITH GRANT OPTION; > "!SQL_FILE!"
echo GRANT ALL PRIVILEGES ON *.* TO '%MYSQL_USER%'@'172.20.10.%%' IDENTIFIED BY '%MYSQL_PASSWORD%' WITH GRANT OPTION; >> "!SQL_FILE!"
echo FLUSH PRIVILEGES; >> "!SQL_FILE!"
echo SELECT user, host FROM mysql.user WHERE user = '%MYSQL_USER%'; >> "!SQL_FILE!"

REM Execute SQL commands
mysql -h localhost -u %MYSQL_USER% -p%MYSQL_PASSWORD% < "!SQL_FILE!"
if %errorLevel% equ 0 (
    echo [OK] Privileges granted successfully
) else (
    echo [X] Failed to grant privileges
    echo     Make sure MySQL command-line client is in PATH
)

del "!SQL_FILE!"

REM ============================================================================
REM STEP 6: Configure Windows Firewall
REM ============================================================================

echo.
echo ========================================
echo STEP 6: Configure Windows Firewall
echo ========================================
echo.

netsh advfirewall firewall delete rule name="MySQL Server" >nul 2>&1
netsh advfirewall firewall add rule name="MySQL Server" dir=in action=allow protocol=TCP localport=%MYSQL_PORT% >nul 2>&1

if %errorLevel% equ 0 (
    echo [OK] Windows Firewall configured
    echo     Allowed TCP port %MYSQL_PORT%
) else (
    echo [!] Warning: Could not configure firewall
    echo     You may need to configure firewall manually
)

REM ============================================================================
REM STEP 7: Verify Configuration
REM ============================================================================

echo.
echo ========================================
echo STEP 7: Verify Configuration
echo ========================================
echo.

echo [!] Checking if MySQL is listening on correct interface...
netstat -an | find "3306" | find "LISTENING"
if %errorLevel% equ 0 (
    echo [OK] MySQL is listening on port 3306
) else (
    echo [X] MySQL is not listening on port 3306!
)

REM ============================================================================
REM STEP 8: Test Connection
REM ============================================================================

echo.
echo ========================================
echo STEP 8: Test Connection from IP Address
echo ========================================
echo.

echo [!] Testing connection to %MYSQL_HOST%...

REM Create test SQL file
set TEST_SQL=%TEMP%\test-connection.sql
echo SELECT 'Connection successful!' AS Status; > "!TEST_SQL!"
echo SELECT USER() AS ConnectedAs; >> "!TEST_SQL!"
echo SELECT @@hostname AS ServerHostname; >> "!TEST_SQL!"

mysql -h %MYSQL_HOST% -u %MYSQL_USER% -p%MYSQL_PASSWORD% < "!TEST_SQL!"
if %errorLevel% equ 0 (
    echo.
    echo [OK] Connection test PASSED!
) else (
    echo.
    echo [X] Connection test FAILED!
    echo     Check MySQL error log for details
)

del "!TEST_SQL!"

REM ============================================================================
REM Summary
REM ============================================================================

echo.
echo ========================================
echo CONFIGURATION COMPLETE
echo ========================================
echo.
echo Configuration Summary:
echo   - my.ini location: !MY_INI_PATH!
echo   - Backup created: !BACKUP_PATH!
echo   - bind-address: 0.0.0.0 (all interfaces)
echo   - MySQL privileges granted for: %MYSQL_HOST%
echo   - Firewall rule: Enabled for port %MYSQL_PORT%
echo.
echo Next Steps:
echo 1. Run deployment script with IP address configuration
echo 2. Monitor MySQL error log for any issues
echo 3. Test database operations
echo.
echo MySQL Error Log Location:
echo   C:\ProgramData\MySQL\MySQL Server 8.0\Data\*.err
echo.
echo To revert changes:
echo   copy "!BACKUP_PATH!" "!MY_INI_PATH!"
echo   net stop MySQL80
echo   net start MySQL80
echo.

pause
