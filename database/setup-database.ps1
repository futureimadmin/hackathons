# Setup Script for eCommerce Platform Database
# This script sets up the MySQL database and generates sample data

Write-Host "=" -NoNewline -ForegroundColor Cyan
Write-Host ("=" * 59) -ForegroundColor Cyan
Write-Host "eCommerce Platform Database Setup" -ForegroundColor Cyan
Write-Host ("=" * 60) -ForegroundColor Cyan
Write-Host ""

# Check if MySQL is installed
Write-Host "Checking MySQL installation..." -ForegroundColor Yellow
$mysqlPath = Get-Command mysql -ErrorAction SilentlyContinue

if (-not $mysqlPath) {
    Write-Host "✗ MySQL not found in PATH" -ForegroundColor Red
    Write-Host "Please install MySQL 8.0+ and add it to your PATH" -ForegroundColor Red
    Write-Host "Download from: https://dev.mysql.com/downloads/installer/" -ForegroundColor Yellow
    exit 1
}

Write-Host "✓ MySQL found: $($mysqlPath.Source)" -ForegroundColor Green
Write-Host ""

# Check if MySQL service is running
Write-Host "Checking MySQL service..." -ForegroundColor Yellow
$mysqlService = Get-Service -Name "MySQL*" -ErrorAction SilentlyContinue | Where-Object { $_.Status -eq 'Running' }

if (-not $mysqlService) {
    Write-Host "✗ MySQL service is not running" -ForegroundColor Red
    Write-Host "Starting MySQL service..." -ForegroundColor Yellow
    
    try {
        Start-Service -Name "MySQL80" -ErrorAction Stop
        Write-Host "✓ MySQL service started" -ForegroundColor Green
    } catch {
        Write-Host "✗ Failed to start MySQL service" -ForegroundColor Red
        Write-Host "Please start MySQL manually: net start MySQL80" -ForegroundColor Yellow
        exit 1
    }
} else {
    Write-Host "✓ MySQL service is running" -ForegroundColor Green
}
Write-Host ""

# Get MySQL credentials
Write-Host "MySQL Connection Details" -ForegroundColor Cyan
Write-Host "------------------------" -ForegroundColor Cyan
$mysqlUser = Read-Host "MySQL Username (default: root)"
if ([string]::IsNullOrWhiteSpace($mysqlUser)) {
    $mysqlUser = "root"
}

$mysqlPassword = Read-Host "MySQL Password" -AsSecureString
$mysqlPasswordPlain = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
    [Runtime.InteropServices.Marshal]::SecureStringToBSTR($mysqlPassword)
)
Write-Host ""

# Test MySQL connection
Write-Host "Testing MySQL connection..." -ForegroundColor Yellow
$testQuery = "SELECT VERSION();"
$testResult = & mysql -u $mysqlUser -p"$mysqlPasswordPlain" -e $testQuery 2>&1

if ($LASTEXITCODE -ne 0) {
    Write-Host "✗ Failed to connect to MySQL" -ForegroundColor Red
    Write-Host "Error: $testResult" -ForegroundColor Red
    exit 1
}

Write-Host "✓ Connected to MySQL successfully" -ForegroundColor Green
Write-Host ""

# Create database and tables
Write-Host "Creating database schema..." -ForegroundColor Yellow
Write-Host "  - Creating main eCommerce schema..." -ForegroundColor Gray

$schema1 = Get-Content -Path "schema/01_main_ecommerce_schema.sql" -Raw
$result1 = $schema1 | & mysql -u $mysqlUser -p"$mysqlPasswordPlain" 2>&1

if ($LASTEXITCODE -ne 0) {
    Write-Host "✗ Failed to create main schema" -ForegroundColor Red
    Write-Host "Error: $result1" -ForegroundColor Red
    exit 1
}

Write-Host "  ✓ Main eCommerce schema created" -ForegroundColor Green

Write-Host "  - Creating system-specific schemas..." -ForegroundColor Gray
$schema2 = Get-Content -Path "schema/02_system_specific_schemas.sql" -Raw
$result2 = $schema2 | & mysql -u $mysqlUser -p"$mysqlPasswordPlain" 2>&1

if ($LASTEXITCODE -ne 0) {
    Write-Host "✗ Failed to create system-specific schemas" -ForegroundColor Red
    Write-Host "Error: $result2" -ForegroundColor Red
    exit 1
}

Write-Host "  ✓ System-specific schemas created" -ForegroundColor Green
Write-Host ""

# Check Python installation
Write-Host "Checking Python installation..." -ForegroundColor Yellow
$pythonPath = Get-Command python -ErrorAction SilentlyContinue

if (-not $pythonPath) {
    Write-Host "✗ Python not found in PATH" -ForegroundColor Red
    Write-Host "Please install Python 3.8+ from https://www.python.org/downloads/" -ForegroundColor Yellow
    Write-Host "Skipping data generation..." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "To generate data later, run:" -ForegroundColor Yellow
    Write-Host "  cd data_generator" -ForegroundColor Gray
    Write-Host "  pip install -r requirements.txt" -ForegroundColor Gray
    Write-Host "  python generate_sample_data.py" -ForegroundColor Gray
    exit 0
}

Write-Host "✓ Python found: $($pythonPath.Source)" -ForegroundColor Green
Write-Host ""

# Install Python dependencies
Write-Host "Installing Python dependencies..." -ForegroundColor Yellow
Push-Location data_generator

$pipInstall = & pip install -r requirements.txt 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "✗ Failed to install Python dependencies" -ForegroundColor Red
    Write-Host "Error: $pipInstall" -ForegroundColor Red
    Pop-Location
    exit 1
}

Write-Host "✓ Python dependencies installed" -ForegroundColor Green
Write-Host ""

# Generate sample data
Write-Host "Generating sample data..." -ForegroundColor Yellow
Write-Host "This may take 5-10 minutes..." -ForegroundColor Gray
Write-Host ""

$dataGenResult = & python generate_sample_data.py 2>&1
Write-Host $dataGenResult

if ($LASTEXITCODE -ne 0) {
    Write-Host "✗ Failed to generate sample data" -ForegroundColor Red
    Pop-Location
    exit 1
}

Pop-Location

Write-Host ""
Write-Host "=" -NoNewline -ForegroundColor Green
Write-Host ("=" * 59) -ForegroundColor Green
Write-Host "Database Setup Complete!" -ForegroundColor Green
Write-Host ("=" * 60) -ForegroundColor Green
Write-Host ""
Write-Host "Next Steps:" -ForegroundColor Cyan
Write-Host "1. Verify data in MySQL:" -ForegroundColor White
Write-Host "   mysql -u $mysqlUser -p" -ForegroundColor Gray
Write-Host "   USE ecommerce_platform;" -ForegroundColor Gray
Write-Host "   SELECT COUNT(*) FROM customers;" -ForegroundColor Gray
Write-Host ""
Write-Host "2. Configure DMS replication (Task 14.4)" -ForegroundColor White
Write-Host "   See terraform/modules/dms/README.md" -ForegroundColor Gray
Write-Host ""
Write-Host "3. Verify end-to-end flow (Task 15)" -ForegroundColor White
Write-Host "   MySQL → DMS → S3 → Glue → Athena" -ForegroundColor Gray
Write-Host ""
