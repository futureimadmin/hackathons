# Build script for Authentication Service
# Compiles Java code and creates deployment JAR

$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Building Authentication Service" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check if Maven is installed
try {
    $mavenVersion = mvn --version 2>&1 | Select-String "Apache Maven"
    Write-Host "✓ Maven found: $mavenVersion" -ForegroundColor Green
} catch {
    Write-Host "✗ Maven not found. Please install Maven 3.8 or higher." -ForegroundColor Red
    exit 1
}

# Check if Java is installed
try {
    $javaVersion = java -version 2>&1 | Select-String "version"
    Write-Host "✓ Java found: $javaVersion" -ForegroundColor Green
} catch {
    Write-Host "✗ Java not found. Please install Java 17 or higher." -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Cleaning previous builds..." -ForegroundColor Cyan
mvn clean

if ($LASTEXITCODE -ne 0) {
    Write-Host "✗ Clean failed" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Compiling and packaging..." -ForegroundColor Cyan
mvn package -DskipTests

if ($LASTEXITCODE -ne 0) {
    Write-Host "✗ Build failed" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Build Successful!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$jarPath = "target\auth-service.jar"
if (Test-Path $jarPath) {
    $jarSize = [math]::Round((Get-Item $jarPath).Length / 1MB, 2)
    Write-Host "JAR file created: $jarPath" -ForegroundColor Green
    Write-Host "Size: $jarSize MB" -ForegroundColor Gray
    Write-Host ""
    Write-Host "To deploy to AWS Lambda:" -ForegroundColor Cyan
    Write-Host "  aws lambda update-function-code --function-name ecommerce-auth-service --zip-file fileb://$jarPath" -ForegroundColor White
} else {
    Write-Host "✗ JAR file not found" -ForegroundColor Red
    exit 1
}
