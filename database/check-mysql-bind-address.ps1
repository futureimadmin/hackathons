# Check and Fix MySQL Bind Address Configuration
# Run this script on the machine where MySQL is installed (172.20.10.2)

param(
    [Parameter(Mandatory=$false)]
    [string]$MySQLHost = "172.20.10.2",
    
    [Parameter(Mandatory=$false)]
    [int]$MySQLPort = 3306
)

$ErrorActionPreference = "Continue"

Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "MySQL Bind Address Configuration Check" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""

# Step 1: Find MySQL configuration file
Write-Host "Step 1: Locating MySQL Configuration File..." -ForegroundColor Yellow
Write-Host ""

$possibleConfigPaths = @(
    "C:\ProgramData\MySQL\MySQL Server 8.0\my.ini",
    "C:\ProgramData\MySQL\MySQL Server 5.7\my.ini",
    "C:\Program Files\MySQL\MySQL Server 8.0\my.ini",
    "C:\Program Files\MySQL\MySQL Server 5.7\my.ini",
    "C:\MySQL\my.ini",
    "C:\my.ini"
)

$configPath = $null
foreach ($path in $possibleConfigPaths) {
    if (Test-Path $path) {
        $configPath = $path
        Write-Host "  [OK] Found MySQL config: $configPath" -ForegroundColor Green
        break
    }
}

if (!$configPath) {
    Write-Host "  [!] Could not auto-detect my.ini location" -ForegroundColor Yellow
    $customPath = Read-Host "  Please enter the full path to your my.ini file"
    if (Test-Path $customPath) {
        $configPath = $customPath
        Write-Host "  [OK] Using: $configPath" -ForegroundColor Green
    } else {
        Write-Host "  [X] File not found: $customPath" -ForegroundColor Red
        exit 1
    }
}

# Step 2: Check current bind-address setting
Write-Host ""
Write-Host "Step 2: Checking Current Bind Address..." -ForegroundColor Yellow
Write-Host ""

$configContent = Get-Content $configPath -Raw
$bindAddressMatch = [regex]::Match($configContent, '(?m)^\s*bind-address\s*=\s*(.+)$')

if ($bindAddressMatch.Success) {
    $currentBindAddress = $bindAddressMatch.Groups[1].Value.Trim()
    Write-Host "  Current bind-address: $currentBindAddress" -ForegroundColor Cyan
    
    if ($currentBindAddress -eq "127.0.0.1" -or $currentBindAddress -eq "localhost") {
        Write-Host "  [X] MySQL is bound to localhost only!" -ForegroundColor Red
        Write-Host "  This prevents remote connections from AWS DMS" -ForegroundColor Red
        $needsFix = $true
    } elseif ($currentBindAddress -eq "0.0.0.0" -or $currentBindAddress -eq "*") {
        Write-Host "  [OK] MySQL accepts connections from all interfaces" -ForegroundColor Green
        $needsFix = $false
    } elseif ($currentBindAddress -eq $MySQLHost) {
        Write-Host "  [OK] MySQL is bound to $MySQLHost" -ForegroundColor Green
        $needsFix = $false
    } else {
        Write-Host "  [!] MySQL is bound to: $currentBindAddress" -ForegroundColor Yellow
        Write-Host "  Expected: 0.0.0.0 or $MySQLHost" -ForegroundColor Yellow
        $needsFix = $true
    }
} else {
    Write-Host "  [!] No bind-address setting found in config" -ForegroundColor Yellow
    Write-Host "  MySQL may be using default (127.0.0.1)" -ForegroundColor Yellow
    $needsFix = $true
}

# Step 3: Check if MySQL is actually listening
Write-Host ""
Write-Host "Step 3: Checking MySQL Listening Status..." -ForegroundColor Yellow
Write-Host ""

try {
    $netstatOutput = netstat -ano | Select-String ":$MySQLPort"
    
    if ($netstatOutput) {
        Write-Host "  MySQL is listening on:" -ForegroundColor Cyan
        foreach ($line in $netstatOutput) {
            Write-Host "    $line" -ForegroundColor White
            
            # Check if listening on all interfaces or specific IP
            if ($line -match "0\.0\.0\.0:$MySQLPort" -or $line -match "\*:$MySQLPort") {
                Write-Host "    [OK] Listening on all interfaces (0.0.0.0)" -ForegroundColor Green
            } elseif ($line -match "127\.0\.0\.1:$MySQLPort") {
                Write-Host "    [X] Only listening on localhost!" -ForegroundColor Red
            } elseif ($line -match "$MySQLHost`:$MySQLPort") {
                Write-Host "    [OK] Listening on $MySQLHost" -ForegroundColor Green
            }
        }
    } else {
        Write-Host "  [X] MySQL is not listening on port $MySQLPort" -ForegroundColor Red
        Write-Host "  Is MySQL service running?" -ForegroundColor Yellow
    }
} catch {
    Write-Host "  [!] Could not check listening ports: $_" -ForegroundColor Yellow
}

# Step 4: Check MySQL service status
Write-Host ""
Write-Host "Step 4: Checking MySQL Service Status..." -ForegroundColor Yellow
Write-Host ""

$mysqlServices = Get-Service | Where-Object { $_.Name -like "*mysql*" }

if ($mysqlServices) {
    foreach ($service in $mysqlServices) {
        Write-Host "  Service: $($service.Name)" -ForegroundColor Cyan
        Write-Host "    Status: $($service.Status)" -ForegroundColor $(if ($service.Status -eq "Running") { "Green" } else { "Red" })
        Write-Host "    Display Name: $($service.DisplayName)" -ForegroundColor White
    }
} else {
    Write-Host "  [X] No MySQL service found" -ForegroundColor Red
}

# Step 5: Check Windows Firewall
Write-Host ""
Write-Host "Step 5: Checking Windows Firewall Rules..." -ForegroundColor Yellow
Write-Host ""

try {
    $firewallRules = Get-NetFirewallRule | Where-Object { 
        $_.DisplayName -like "*MySQL*" -or $_.DisplayName -like "*3306*" 
    }
    
    if ($firewallRules) {
        Write-Host "  Found MySQL firewall rules:" -ForegroundColor Cyan
        foreach ($rule in $firewallRules) {
            Write-Host "    Rule: $($rule.DisplayName)" -ForegroundColor White
            Write-Host "      Enabled: $($rule.Enabled)" -ForegroundColor $(if ($rule.Enabled) { "Green" } else { "Red" })
            Write-Host "      Direction: $($rule.Direction)" -ForegroundColor White
            Write-Host "      Action: $($rule.Action)" -ForegroundColor White
        }
    } else {
        Write-Host "  [!] No MySQL-specific firewall rules found" -ForegroundColor Yellow
        Write-Host "  Checking if port 3306 is allowed..." -ForegroundColor Yellow
        
        # Check for port 3306 rules
        $portRules = Get-NetFirewallPortFilter | Where-Object { $_.LocalPort -eq 3306 }
        if ($portRules) {
            Write-Host "  [OK] Found firewall rules for port 3306" -ForegroundColor Green
        } else {
            Write-Host "  [X] No firewall rules found for port 3306" -ForegroundColor Red
            Write-Host "  You may need to create a firewall rule" -ForegroundColor Yellow
        }
    }
} catch {
    Write-Host "  [!] Could not check firewall rules: $_" -ForegroundColor Yellow
}

# Step 6: Offer to fix bind-address
if ($needsFix) {
    Write-Host ""
    Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host "Fix Required" -ForegroundColor Cyan
    Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "MySQL needs to be configured to accept remote connections." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Recommended fix:" -ForegroundColor Cyan
    Write-Host "  Change bind-address to: 0.0.0.0" -ForegroundColor White
    Write-Host "  This allows MySQL to accept connections from any interface" -ForegroundColor Gray
    Write-Host ""
    
    $fix = Read-Host "Do you want to fix the bind-address now? (y/n)"
    
    if ($fix -eq "y") {
        Write-Host ""
        Write-Host "Creating backup of my.ini..." -ForegroundColor Yellow
        $backupPath = "$configPath.backup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
        Copy-Item $configPath $backupPath
        Write-Host "  [OK] Backup created: $backupPath" -ForegroundColor Green
        
        Write-Host ""
        Write-Host "Updating bind-address..." -ForegroundColor Yellow
        
        if ($bindAddressMatch.Success) {
            # Replace existing bind-address
            $newContent = $configContent -replace '(?m)^\s*bind-address\s*=\s*.+$', 'bind-address = 0.0.0.0'
        } else {
            # Add bind-address under [mysqld] section
            $newContent = $configContent -replace '(?m)^\[mysqld\]', "[mysqld]`r`nbind-address = 0.0.0.0"
        }
        
        Set-Content -Path $configPath -Value $newContent
        Write-Host "  [OK] Updated bind-address to 0.0.0.0" -ForegroundColor Green
        
        Write-Host ""
        Write-Host "MySQL service needs to be restarted for changes to take effect." -ForegroundColor Yellow
        $restart = Read-Host "Do you want to restart MySQL now? (y/n)"
        
        if ($restart -eq "y") {
            Write-Host ""
            Write-Host "Restarting MySQL service..." -ForegroundColor Yellow
            
            $mysqlService = Get-Service | Where-Object { $_.Name -like "*mysql*" -and $_.Status -eq "Running" } | Select-Object -First 1
            
            if ($mysqlService) {
                try {
                    Restart-Service $mysqlService.Name -Force
                    Start-Sleep -Seconds 5
                    
                    $serviceStatus = Get-Service $mysqlService.Name
                    if ($serviceStatus.Status -eq "Running") {
                        Write-Host "  [OK] MySQL service restarted successfully" -ForegroundColor Green
                    } else {
                        Write-Host "  [X] MySQL service failed to start" -ForegroundColor Red
                        Write-Host "  Status: $($serviceStatus.Status)" -ForegroundColor Red
                    }
                } catch {
                    Write-Host "  [X] Failed to restart MySQL: $_" -ForegroundColor Red
                    Write-Host "  You may need to restart manually with administrator privileges" -ForegroundColor Yellow
                }
            } else {
                Write-Host "  [X] Could not find running MySQL service" -ForegroundColor Red
            }
        } else {
            Write-Host ""
            Write-Host "  [!] Please restart MySQL manually:" -ForegroundColor Yellow
            Write-Host "    1. Open Services (services.msc)" -ForegroundColor White
            Write-Host "    2. Find MySQL service" -ForegroundColor White
            Write-Host "    3. Right-click and select Restart" -ForegroundColor White
        }
    } else {
        Write-Host ""
        Write-Host "  Manual fix instructions:" -ForegroundColor Yellow
        Write-Host "  1. Open: $configPath" -ForegroundColor White
        Write-Host "  2. Find the [mysqld] section" -ForegroundColor White
        Write-Host "  3. Change or add: bind-address = 0.0.0.0" -ForegroundColor White
        Write-Host "  4. Save the file" -ForegroundColor White
        Write-Host "  5. Restart MySQL service" -ForegroundColor White
    }
}

# Step 7: Test local connectivity
Write-Host ""
Write-Host "Step 7: Testing Local MySQL Connectivity..." -ForegroundColor Yellow
Write-Host ""

$mysqlPath = Get-Command mysql -ErrorAction SilentlyContinue

if ($mysqlPath) {
    Write-Host "  MySQL client found: $($mysqlPath.Source)" -ForegroundColor Green
    
    $testLocal = Read-Host "  Do you want to test MySQL connection? (y/n)"
    
    if ($testLocal -eq "y") {
        $username = Read-Host "  Enter MySQL username"
        Write-Host "  Enter MySQL password (will be hidden)" -ForegroundColor Gray
        $password = Read-Host "  Password" -AsSecureString
        $passwordPlain = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
            [Runtime.InteropServices.Marshal]::SecureStringToBSTR($password)
        )
        
        Write-Host ""
        Write-Host "  Testing connection to localhost..." -ForegroundColor Yellow
        $result = mysql -h localhost -P $MySQLPort -u $username -p$passwordPlain -e "SELECT 1 as test;" 2>&1
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  [OK] Successfully connected to MySQL on localhost" -ForegroundColor Green
        } else {
            Write-Host "  [X] Failed to connect: $result" -ForegroundColor Red
        }
        
        Write-Host ""
        Write-Host "  Testing connection to $MySQLHost..." -ForegroundColor Yellow
        $result = mysql -h $MySQLHost -P $MySQLPort -u $username -p$passwordPlain -e "SELECT 1 as test;" 2>&1
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  [OK] Successfully connected to MySQL on $MySQLHost" -ForegroundColor Green
        } else {
            Write-Host "  [X] Failed to connect: $result" -ForegroundColor Red
        }
    }
} else {
    Write-Host "  [!] MySQL client not found" -ForegroundColor Yellow
    Write-Host "  Install MySQL client to test connectivity" -ForegroundColor Gray
}

# Summary
Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "Summary and Next Steps" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Configuration file: $configPath" -ForegroundColor Cyan
Write-Host ""

if ($needsFix -and $fix -ne "y") {
    Write-Host "[ACTION REQUIRED] Update MySQL bind-address configuration" -ForegroundColor Red
    Write-Host ""
    Write-Host "Steps:" -ForegroundColor Yellow
    Write-Host "  1. Edit: $configPath" -ForegroundColor White
    Write-Host "  2. Under [mysqld] section, set: bind-address = 0.0.0.0" -ForegroundColor White
    Write-Host "  3. Restart MySQL service" -ForegroundColor White
    Write-Host "  4. Run this script again to verify" -ForegroundColor White
} else {
    Write-Host "[OK] MySQL bind-address appears to be configured correctly" -ForegroundColor Green
}

Write-Host ""
Write-Host "Additional checks needed:" -ForegroundColor Yellow
Write-Host "  - Ensure Windows Firewall allows inbound TCP 3306" -ForegroundColor White
Write-Host "  - Verify MySQL user has remote connection privileges" -ForegroundColor White
Write-Host "  - Check that VPN tunnel is UP (if using VPN)" -ForegroundColor White
Write-Host "  - Verify routing from AWS to 172.20.10.2" -ForegroundColor White
Write-Host ""
Write-Host "To test from AWS, run:" -ForegroundColor Cyan
Write-Host "  cd terraform" -ForegroundColor White
Write-Host "  .\test-mysql-connectivity.ps1" -ForegroundColor White
Write-Host ""
