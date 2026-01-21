# Quick script to update MySQL IP address in existing deployment
# Use this when you only need to change the MySQL IP without redeploying everything

param(
    [Parameter(Mandatory=$true)]
    [string]$NewMySQLIP,
    
    [Parameter(Mandatory=$true)]
    [ValidateSet("dev", "staging", "prod")]
    [string]$Environment,
    
    [string]$ProjectName = "futureim-ecommerce-ai-platform",
    [string]$Region = "us-east-2"
)

Write-Host "🔄 Updating MySQL IP Address" -ForegroundColor Green
Write-Host "New IP: $NewMySQLIP" -ForegroundColor Yellow
Write-Host "Environment: $Environment" -ForegroundColor Yellow

# Update Terraform variables
Write-Host "📝 Updating Terraform variables..." -ForegroundColor Blue
$terraformVarsPath = "terraform/terraform.$Environment.tfvars"

if (Test-Path $terraformVarsPath) {
    # Read current content
    $content = Get-Content $terraformVarsPath
    
    # Update MySQL server name
    $updatedContent = $content -replace 'mysql_server_name\s*=\s*"[^"]*"', "mysql_server_name = `"$NewMySQLIP`""
    
    # Write back to file
    $updatedContent | Set-Content $terraformVarsPath
    Write-Host "✅ Updated $terraformVarsPath" -ForegroundColor Green
} else {
    Write-Host "⚠️  Terraform vars file not found: $terraformVarsPath" -ForegroundColor Yellow
}

# Update CloudFormation stack if it exists
$StackName = "$ProjectName-$Environment"

Write-Host "🔍 Checking if CloudFormation stack exists..." -ForegroundColor Blue
try {
    aws cloudformation describe-stacks --stack-name $StackName --region $Region --output table 2>$null
    $stackExists = $true
    Write-Host "✅ Stack exists - updating MySQL IP parameter" -ForegroundColor Green
} catch {
    $stackExists = $false
    Write-Host "📦 Stack does not exist - skipping CloudFormation update" -ForegroundColor Yellow
}

if ($stackExists) {
    Write-Host "🔄 Updating CloudFormation stack with new MySQL IP..." -ForegroundColor Blue
    
    # Get current parameters
    $currentParams = aws cloudformation describe-stacks --stack-name $StackName --region $Region --query "Stacks[0].Parameters" --output json | ConvertFrom-Json
    
    # Build parameter overrides
    $paramOverrides = @()
    foreach ($param in $currentParams) {
        if ($param.ParameterKey -eq "MySQLServerIP") {
            $paramOverrides += "$($param.ParameterKey)=$NewMySQLIP"
        } else {
            $paramOverrides += "$($param.ParameterKey)=$($param.ParameterValue)"
        }
    }
    
    # Update stack
    try {
        aws cloudformation deploy `
            --template-file "cloudformation/ecommerce-ai-platform-stack.yaml" `
            --stack-name $StackName `
            --region $Region `
            --capabilities "CAPABILITY_NAMED_IAM" `
            --parameter-overrides $paramOverrides
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✅ CloudFormation stack updated successfully!" -ForegroundColor Green
        } else {
            Write-Host "❌ CloudFormation stack update failed!" -ForegroundColor Red
        }
    } catch {
        Write-Host "❌ Error updating CloudFormation stack: $_" -ForegroundColor Red
    }
}

# Update Terraform if needed
Write-Host "🔄 Applying Terraform changes..." -ForegroundColor Blue
try {
    Set-Location terraform
    
    # Plan changes
    terraform plan -var-file="terraform.$Environment.tfvars" -out=tfplan
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "📋 Terraform plan completed. Review changes above." -ForegroundColor Blue
        $apply = Read-Host "Apply Terraform changes? (y/N)"
        
        if ($apply -eq "y" -or $apply -eq "Y") {
            terraform apply tfplan
            
            if ($LASTEXITCODE -eq 0) {
                Write-Host "✅ Terraform changes applied successfully!" -ForegroundColor Green
            } else {
                Write-Host "❌ Terraform apply failed!" -ForegroundColor Red
            }
        } else {
            Write-Host "⏭️  Skipping Terraform apply" -ForegroundColor Yellow
        }
    } else {
        Write-Host "❌ Terraform plan failed!" -ForegroundColor Red
    }
} catch {
    Write-Host "❌ Error running Terraform: $_" -ForegroundColor Red
} finally {
    Set-Location ..
}

Write-Host ""
Write-Host "🎉 MySQL IP update process completed!" -ForegroundColor Green
Write-Host "📋 Summary of changes:" -ForegroundColor Blue
Write-Host "  • Updated Terraform variables file" -ForegroundColor White
Write-Host "  • Updated CloudFormation stack (if exists)" -ForegroundColor White
Write-Host "  • Applied Terraform changes (if confirmed)" -ForegroundColor White
Write-Host ""
Write-Host "💡 Next steps:" -ForegroundColor Yellow
Write-Host "  1. Verify DMS connectivity to new IP: $NewMySQLIP" -ForegroundColor White
Write-Host "  2. Test database replication" -ForegroundColor White
Write-Host "  3. Update any hardcoded references in application code" -ForegroundColor White