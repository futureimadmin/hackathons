#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Run integration tests for eCommerce AI Platform

.DESCRIPTION
    This script runs all integration tests including:
    - End-to-end data pipeline tests
    - Property-based data consistency tests
    - AI systems integration tests

.PARAMETER TestType
    Type of tests to run: all, e2e, property, ai-systems

.PARAMETER Verbose
    Enable verbose output

.PARAMETER Coverage
    Generate coverage report

.EXAMPLE
    .\run_integration_tests.ps1 -TestType all
    .\run_integration_tests.ps1 -TestType e2e -Verbose
    .\run_integration_tests.ps1 -TestType ai-systems -Coverage
#>

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet("all", "e2e", "property", "ai-systems")]
    [string]$TestType = "all",
    
    [Parameter(Mandatory=$false)]
    [switch]$Verbose,
    
    [Parameter(Mandatory=$false)]
    [switch]$Coverage
)

# Configuration
$PROJECT_ROOT = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$INTEGRATION_TESTS_DIR = Join-Path $PROJECT_ROOT "tests\integration"

# Colors
$COLOR_GREEN = "Green"
$COLOR_RED = "Red"
$COLOR_YELLOW = "Yellow"
$COLOR_CYAN = "Cyan"

function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$Color = "White"
    )
    Write-Host $Message -ForegroundColor $Color
}

function Test-Prerequisites {
    Write-ColorOutput "`n=== Checking Prerequisites ===" $COLOR_CYAN
    
    # Check Python
    try {
        $pythonVersion = python --version 2>&1
        Write-ColorOutput "✓ Python: $pythonVersion" $COLOR_GREEN
    } catch {
        Write-ColorOutput "✗ Python not found" $COLOR_RED
        return $false
    }
    
    # Check pytest
    try {
        $pytestVersion = pytest --version 2>&1
        Write-ColorOutput "✓ pytest: $pytestVersion" $COLOR_GREEN
    } catch {
        Write-ColorOutput "✗ pytest not found. Install with: pip install pytest" $COLOR_RED
        return $false
    }
    
    # Check hypothesis
    try {
        python -c "import hypothesis" 2>&1 | Out-Null
        Write-ColorOutput "✓ hypothesis installed" $COLOR_GREEN
    } catch {
        Write-ColorOutput "✗ hypothesis not found. Install with: pip install hypothesis" $COLOR_RED
        return $false
    }
    
    # Check boto3
    try {
        python -c "import boto3" 2>&1 | Out-Null
        Write-ColorOutput "✓ boto3 installed" $COLOR_GREEN
    } catch {
        Write-ColorOutput "✗ boto3 not found. Install with: pip install boto3" $COLOR_RED
        return $false
    }
    
    # Check AWS credentials
    try {
        aws sts get-caller-identity | Out-Null
        Write-ColorOutput "✓ AWS credentials configured" $COLOR_GREEN
    } catch {
        Write-ColorOutput "⚠ AWS credentials not configured. Some tests may fail." $COLOR_YELLOW
    }
    
    return $true
}

function Get-TestFiles {
    param([string]$Type)
    
    switch ($Type) {
        "e2e" {
            return "test_data_pipeline_e2e.py"
        }
        "property" {
            return "test_data_consistency_property.py"
        }
        "ai-systems" {
            return "test_ai_systems_integration.py"
        }
        default {
            return "test_*.py"
        }
    }
}

function Run-Tests {
    param(
        [string]$TestPattern,
        [bool]$VerboseMode,
        [bool]$CoverageMode
    )
    
    Write-ColorOutput "`n=== Running Integration Tests ===" $COLOR_CYAN
    Write-ColorOutput "Test Pattern: $TestPattern" $COLOR_CYAN
    Write-ColorOutput "Directory: $INTEGRATION_TESTS_DIR`n" $COLOR_CYAN
    
    # Build pytest command
    $pytestArgs = @(
        $INTEGRATION_TESTS_DIR
        "-v"
        "--tb=short"
        "-m", "integration"
    )
    
    # Add test pattern
    if ($TestPattern -ne "test_*.py") {
        $pytestArgs += "-k"
        $pytestArgs += $TestPattern
    }
    
    # Add verbose flag
    if ($VerboseMode) {
        $pytestArgs += "-vv"
        $pytestArgs += "--hypothesis-show-statistics"
    }
    
    # Add coverage flag
    if ($CoverageMode) {
        $pytestArgs += "--cov=$INTEGRATION_TESTS_DIR"
        $pytestArgs += "--cov-report=html"
        $pytestArgs += "--cov-report=term"
    }
    
    # Run pytest
    Write-ColorOutput "Command: pytest $($pytestArgs -join ' ')`n" $COLOR_CYAN
    
    $startTime = Get-Date
    & pytest @pytestArgs
    $exitCode = $LASTEXITCODE
    $endTime = Get-Date
    $duration = $endTime - $startTime
    
    Write-ColorOutput "`n=== Test Results ===" $COLOR_CYAN
    Write-ColorOutput "Duration: $($duration.TotalSeconds) seconds" $COLOR_CYAN
    
    if ($exitCode -eq 0) {
        Write-ColorOutput "✓ All tests passed!" $COLOR_GREEN
    } else {
        Write-ColorOutput "✗ Some tests failed (exit code: $exitCode)" $COLOR_RED
    }
    
    if ($CoverageMode) {
        Write-ColorOutput "`nCoverage report generated in: htmlcov/index.html" $COLOR_CYAN
    }
    
    return $exitCode
}

# Main execution
Write-ColorOutput @"
╔═══════════════════════════════════════════════════════════╗
║   eCommerce AI Platform - Integration Test Runner        ║
╚═══════════════════════════════════════════════════════════╝
"@ $COLOR_CYAN

# Check prerequisites
if (-not (Test-Prerequisites)) {
    Write-ColorOutput "`n✗ Prerequisites check failed. Please install missing dependencies." $COLOR_RED
    exit 1
}

# Get test pattern
$testPattern = Get-TestFiles -Type $TestType

# Run tests
$exitCode = Run-Tests -TestPattern $testPattern -VerboseMode $Verbose -CoverageMode $Coverage

# Exit with test result code
exit $exitCode
