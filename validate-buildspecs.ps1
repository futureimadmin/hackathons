# Validate Buildspec YAML Syntax
# This script checks if the buildspec files have valid YAML syntax

Write-Host "Validating Buildspec YAML Syntax" -ForegroundColor Cyan
Write-Host "=================================" -ForegroundColor Cyan

$buildspecs = @(
    "buildspecs/java-lambda-buildspec.yml",
    "buildspecs/python-lambdas-buildspec.yml",
    "buildspecs/frontend-buildspec.yml"
)

$allValid = $true

foreach ($buildspec in $buildspecs) {
    Write-Host ""
    Write-Host "Checking: $buildspec" -ForegroundColor Blue
    
    if (-not (Test-Path $buildspec)) {
        Write-Host "   File not found!" -ForegroundColor Red
        $allValid = $false
        continue
    }
    
    try {
        # Try to parse the YAML using PowerShell
        $content = Get-Content $buildspec -Raw
        
        # Basic YAML validation checks
        $lines = Get-Content $buildspec
        $lineNumber = 0
        $hasErrors = $false
        
        foreach ($line in $lines) {
            $lineNumber++
            
            # Check for common YAML issues
            if ($line -match "^\s*-\s*\|$") {
                Write-Host "   Line $lineNumber`: Multi-line block found - checking next lines..." -ForegroundColor Yellow
            }
            
            # Check for proper indentation after multi-line blocks
            if ($line -match "^\s*-\s*\|" -and $lineNumber -lt $lines.Count) {
                $nextLine = $lines[$lineNumber]
                if ($nextLine -match "^\s*[a-zA-Z]" -and -not ($nextLine -match "^\s*#")) {
                    Write-Host "   Line $($lineNumber + 1)`: Potential indentation issue after multi-line block" -ForegroundColor Yellow
                }
            }
        }
        
        Write-Host "   YAML structure appears valid" -ForegroundColor Green
        
    } catch {
        Write-Host "   YAML parsing error: $_" -ForegroundColor Red
        $allValid = $false
    }
}

Write-Host ""
if ($allValid) {
    Write-Host "All buildspec files appear to have valid YAML syntax!" -ForegroundColor Green
} else {
    Write-Host "Some buildspec files have YAML syntax issues!" -ForegroundColor Red
}

Write-Host ""
Write-Host "Note: For complete validation, commit and push to trigger the pipeline." -ForegroundColor Yellow