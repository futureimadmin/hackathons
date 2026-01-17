#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Fix S3 frontend bucket public access

.DESCRIPTION
    This script fixes the S3 bucket permissions for the frontend static website
#>

$PROJECT_NAME = "futureim-ecommerce-ai-platform"
$AWS_REGION = "us-east-2"
$BUCKET_NAME = "${PROJECT_NAME}-frontend-dev"

$COLOR_GREEN = "Green"
$COLOR_RED = "Red"
$COLOR_YELLOW = "Yellow"
$COLOR_CYAN = "Cyan"

function Write-ColorOutput {
    param([string]$Message, [string]$Color = "White")
    Write-Host $Message -ForegroundColor $Color
}

Write-ColorOutput "`n============================================================" $COLOR_CYAN
Write-ColorOutput "   Fix S3 Frontend Bucket Access" $COLOR_CYAN
Write-ColorOutput "============================================================" $COLOR_CYAN

Write-ColorOutput "`nBucket: $BUCKET_NAME" $COLOR_CYAN
Write-ColorOutput "Region: $AWS_REGION" $COLOR_CYAN

# Step 1: Remove public access block
Write-ColorOutput "`nStep 1: Removing public access block..." $COLOR_CYAN
aws s3api delete-public-access-block --bucket $BUCKET_NAME --region $AWS_REGION 2>&1 | Out-Null

if ($LASTEXITCODE -eq 0) {
    Write-ColorOutput "[OK] Public access block removed" $COLOR_GREEN
} else {
    Write-ColorOutput "[!] Public access block may not exist (this is OK)" $COLOR_YELLOW
}

# Step 2: Set bucket policy for public read
Write-ColorOutput "`nStep 2: Setting bucket policy for public read..." $COLOR_CYAN

$policy = @{
    Version = "2012-10-17"
    Statement = @(
        @{
            Sid = "PublicReadGetObject"
            Effect = "Allow"
            Principal = "*"
            Action = "s3:GetObject"
            Resource = "arn:aws:s3:::$BUCKET_NAME/*"
        }
    )
} | ConvertTo-Json -Depth 10

$policyFile = Join-Path $PSScriptRoot "temp-bucket-policy.json"
[System.IO.File]::WriteAllText($policyFile, $policy, [System.Text.UTF8Encoding]::new($false))

aws s3api put-bucket-policy --bucket $BUCKET_NAME --policy "file://$policyFile" --region $AWS_REGION

if ($LASTEXITCODE -eq 0) {
    Write-ColorOutput "[OK] Bucket policy applied" $COLOR_GREEN
} else {
    Write-ColorOutput "[X] Failed to apply bucket policy" $COLOR_RED
    Remove-Item $policyFile -ErrorAction SilentlyContinue
    exit 1
}

Remove-Item $policyFile -ErrorAction SilentlyContinue

# Step 3: Enable static website hosting
Write-ColorOutput "`nStep 3: Enabling static website hosting..." $COLOR_CYAN

aws s3 website s3://$BUCKET_NAME --index-document index.html --error-document index.html --region $AWS_REGION

if ($LASTEXITCODE -eq 0) {
    Write-ColorOutput "[OK] Static website hosting enabled" $COLOR_GREEN
} else {
    Write-ColorOutput "[X] Failed to enable static website hosting" $COLOR_RED
    exit 1
}

# Step 4: Verify bucket policy
Write-ColorOutput "`nStep 4: Verifying bucket policy..." $COLOR_CYAN

$currentPolicy = aws s3api get-bucket-policy --bucket $BUCKET_NAME --region $AWS_REGION --query Policy --output text 2>&1

if ($LASTEXITCODE -eq 0) {
    Write-ColorOutput "[OK] Bucket policy verified" $COLOR_GREEN
    Write-ColorOutput "`nCurrent Policy:" $COLOR_CYAN
    $currentPolicy | ConvertFrom-Json | ConvertTo-Json -Depth 10
} else {
    Write-ColorOutput "[X] Could not retrieve bucket policy" $COLOR_RED
}

# Step 5: Test access
Write-ColorOutput "`nStep 5: Testing bucket access..." $COLOR_CYAN

$websiteUrl = "http://$BUCKET_NAME.s3-website.$AWS_REGION.amazonaws.com"

Write-ColorOutput "`nFrontend URL: $websiteUrl" $COLOR_GREEN

Write-ColorOutput "`nTrying to access the website..." $COLOR_CYAN
try {
    $response = Invoke-WebRequest -Uri $websiteUrl -Method Head -ErrorAction Stop
    Write-ColorOutput "[OK] Website is accessible (Status: $($response.StatusCode))" $COLOR_GREEN
} catch {
    if ($_.Exception.Response.StatusCode -eq 404) {
        Write-ColorOutput "[!] Website is accessible but index.html not found (404)" $COLOR_YELLOW
        Write-ColorOutput "    This means permissions are OK, but files may not be uploaded" $COLOR_YELLOW
    } else {
        Write-ColorOutput "[X] Website is not accessible: $($_.Exception.Message)" $COLOR_RED
    }
}

# Summary
Write-ColorOutput "`n============================================================" $COLOR_GREEN
Write-ColorOutput "   Configuration Complete" $COLOR_GREEN
Write-ColorOutput "============================================================" $COLOR_GREEN

Write-ColorOutput "`nFrontend URL:" $COLOR_CYAN
Write-ColorOutput "  $websiteUrl" $COLOR_GREEN

Write-ColorOutput "`nIf you still get 403 errors:" $COLOR_YELLOW
Write-ColorOutput "1. Wait 1-2 minutes for AWS to propagate changes" $COLOR_YELLOW
Write-ColorOutput "2. Clear your browser cache" $COLOR_YELLOW
Write-ColorOutput "3. Try accessing in incognito/private mode" $COLOR_YELLOW
Write-ColorOutput "4. Verify files were uploaded: aws s3 ls s3://$BUCKET_NAME/" $COLOR_YELLOW

exit 0
