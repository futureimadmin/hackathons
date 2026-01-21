# Test PowerShell Syntax
# This script tests if the CloudFormation scripts have correct syntax

Write-Host "Testing PowerShell Script Syntax..." -ForegroundColor Green

$scripts = @(
    "cloudformation/deploy-stack.ps1",
    "cloudformation/delete-stack.ps1", 
    "cloudformation/stack-status.ps1",
    "cloudformation/validate-prerequisites.ps1"
)

$allPassed = $true

foreach ($script in $scripts) {
    Write-Host "Testing: $script" -ForegroundColor Cyan
    
    try {
        # Test syntax by parsing the script
        $null = [System.Management.Automation.PSParser]::Tokenize((Get-Content $script -Raw), [ref]$null)
        Write-Host "  PASS - Syntax is valid" -ForegroundColor Green
    } catch {
        Write-Host "  FAIL - Syntax error: $_" -ForegroundColor Red
        $allPassed = $false
    }
}

Write-Host ""
if ($allPassed) {
    Write-Host "All scripts passed syntax validation!" -ForegroundColor Green
    Write-Host "You can now run the CloudFormation deployment scripts." -ForegroundColor White
} else {
    Write-Host "Some scripts have syntax errors that need to be fixed." -ForegroundColor Red
}

# Clean up
Remove-Item $MyInvocation.MyCommand.Path -Force