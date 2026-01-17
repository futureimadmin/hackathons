# Fix Terraform PATH for Kiro Terminal
# This script adds Terraform to the current session's PATH

Write-Host "Fixing Terraform PATH..." -ForegroundColor Cyan

# Common Terraform installation locations
$possiblePaths = @(
    "C:\Program Files\Hashicorp\terraform",
    "C:\HashiCorp\Terraform",
    "$env:LOCALAPPDATA\Programs\Terraform",
    "$env:ProgramFiles\Terraform",
    "${env:ProgramFiles(x86)}\Terraform"
)

# Find where terraform.exe is located
$terraformPath = $null
foreach ($path in $possiblePaths) {
    if (Test-Path "$path\terraform.exe") {
        $terraformPath = $path
        break
    }
}

# If not found in common locations, search
if (-not $terraformPath) {
    Write-Host "Searching for terraform.exe..." -ForegroundColor Yellow
    $found = Get-ChildItem -Path "C:\" -Filter "terraform.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($found) {
        $terraformPath = $found.DirectoryName
    }
}

if ($terraformPath) {
    Write-Host "✓ Found Terraform at: $terraformPath" -ForegroundColor Green
    
    # Add to current session PATH
    $env:PATH = "$terraformPath;$env:PATH"
    
    # Verify it works
    $version = terraform --version 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✓ Terraform is now available in this session" -ForegroundColor Green
        Write-Host $version -ForegroundColor Gray
        Write-Host ""
        Write-Host "You can now run terraform commands!" -ForegroundColor Cyan
    } else {
        Write-Host "✗ Terraform found but not working" -ForegroundColor Red
    }
} else {
    Write-Host "✗ Terraform not found" -ForegroundColor Red
    Write-Host "Please ensure Terraform is installed" -ForegroundColor Yellow
    Write-Host "Download from: https://www.terraform.io/downloads" -ForegroundColor Yellow
}
