# Quick Data Pipeline: Upload Parquet files to S3
# Uploads existing Parquet files from mysql-exports to trigger Lambda pipeline

param(
    [string]$Region = "us-east-2",
    [string]$AccountId = "450133579764",
    [switch]$ExportFromMySQL = $false,
    [string]$MySQLHost = "localhost",
    [string]$MySQLUser = "root",
    [string]$Database = "ecommerce"
)

$ErrorActionPreference = "Stop"

Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "Quick Data Pipeline: Upload Parquet to S3" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""

$ExportDir = ".\mysql-exports"
$SharedRawBucket = "ecommerce-raw-$AccountId"

# Tables to process
$Tables = @(
    "categories", "customers", "inventory", "orders", 
    "order_items", "payments", "products", "promotions", 
    "reviews", "shipments"
)

# Optional: Export from MySQL if requested
if ($ExportFromMySQL) {
    Write-Host "[Step 1/3] Exporting MySQL data to CSV and Parquet..." -ForegroundColor Green
    
    if (-not (Test-Path $ExportDir)) {
        New-Item -ItemType Directory -Path $ExportDir | Out-Null
    }
    
    Write-Host "Enter MySQL password:" -ForegroundColor Yellow
    $Password = Read-Host -AsSecureString
    $PlainPassword = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
        [Runtime.InteropServices.Marshal]::SecureStringToBSTR($Password)
    )
    
    # Check Python dependencies
    $packages = @("pandas", "pyarrow")
    foreach ($pkg in $packages) {
        python -c "import $pkg" 2>$null
        if ($LASTEXITCODE -ne 0) {
            Write-Host "  Installing $pkg..." -ForegroundColor Yellow
            pip install $pkg --quiet
        }
    }
    
    # Create export and convert script
    $ExportScript = @"
import pandas as pd
import mysql.connector
import sys

host = '$MySQLHost'
user = '$MySQLUser'
password = '$PlainPassword'
database = '$Database'
table = sys.argv[1]
output_dir = '$ExportDir'

try:
    conn = mysql.connector.connect(host=host, user=user, password=password, database=database)
    query = f'SELECT * FROM {table}'
    df = pd.read_sql(query, conn)
    conn.close()
    
    # Save as CSV and Parquet
    csv_file = f'{output_dir}/{table}.csv'
    parquet_file = f'{output_dir}/{table}.parquet'
    
    df.to_csv(csv_file, index=False)
    df.to_parquet(parquet_file, engine='pyarrow', compression='snappy', index=False)
    
    print(f'Exported {table}: {len(df)} records')
except Exception as e:
    print(f'Error exporting {table}: {e}')
    sys.exit(1)
"@
    
    $ExportScript | Out-File -FilePath "export_table.py" -Encoding UTF8
    
    foreach ($Table in $Tables) {
        Write-Host "  Exporting: $Table" -ForegroundColor Cyan
        python export_table.py "$Table"
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "    [OK] $Table exported" -ForegroundColor Green
        } else {
            Write-Host "    [ERROR] Failed: $Table" -ForegroundColor Red
        }
    }
    
    Remove-Item "export_table.py" -ErrorAction SilentlyContinue
    Write-Host ""
}

# Check if Parquet files exist
Write-Host "[Step 2/3] Checking for Parquet files..." -ForegroundColor Green

if (-not (Test-Path $ExportDir)) {
    Write-Host "[ERROR] Directory not found: $ExportDir" -ForegroundColor Red
    Write-Host "Run with -ExportFromMySQL flag to export from MySQL first" -ForegroundColor Yellow
    exit 1
}

$ParquetFiles = Get-ChildItem -Path $ExportDir -Filter "*.parquet"

if ($ParquetFiles.Count -eq 0) {
    Write-Host "[ERROR] No Parquet files found in $ExportDir" -ForegroundColor Red
    Write-Host "Run with -ExportFromMySQL flag to export from MySQL first" -ForegroundColor Yellow
    exit 1
}

Write-Host "[OK] Found $($ParquetFiles.Count) Parquet files" -ForegroundColor Green
Write-Host ""

# Upload Parquet files to S3
Write-Host "[Step 3/3] Uploading Parquet files to S3..." -ForegroundColor Green
Write-Host "  Target bucket: $SharedRawBucket" -ForegroundColor Cyan
Write-Host ""

$UploadedCount = 0
$FailedCount = 0

foreach ($Table in $Tables) {
    $ParquetFile = Join-Path $ExportDir "$Table.parquet"
    
    if (Test-Path $ParquetFile) {
        $S3Path = "s3://$SharedRawBucket/ecommerce/$Table/$Table.parquet"
        
        Write-Host "  Uploading: $Table.parquet" -ForegroundColor Cyan
        aws s3 cp "$ParquetFile" "$S3Path" --region $Region 2>&1 | Out-Null
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "    [OK] Uploaded to $S3Path" -ForegroundColor Green
            $UploadedCount++
        } else {
            Write-Host "    [ERROR] Upload failed" -ForegroundColor Red
            $FailedCount++
        }
    } else {
        Write-Host "  [SKIP] $Table.parquet not found" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "Upload Complete!" -ForegroundColor Green
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Summary:" -ForegroundColor Yellow
Write-Host "  Uploaded: $UploadedCount files" -ForegroundColor Green
Write-Host "  Failed: $FailedCount files" -ForegroundColor $(if ($FailedCount -gt 0) { "Red" } else { "Green" })
Write-Host ""
Write-Host "What happens next:" -ForegroundColor Yellow
Write-Host "  1. S3 triggers raw-to-curated Lambda function" -ForegroundColor White
Write-Host "  2. Lambda validates, deduplicates, masks sensitive data" -ForegroundColor White
Write-Host "  3. Lambda writes to curated bucket" -ForegroundColor White
Write-Host "  4. S3 triggers curated-to-prod Lambda function" -ForegroundColor White
Write-Host "  5. Lambda runs AI models for all 5 systems" -ForegroundColor White
Write-Host "  6. Lambda writes analytics to prod buckets" -ForegroundColor White
Write-Host "  7. Glue crawlers create Athena tables" -ForegroundColor White
Write-Host ""
Write-Host "Monitor Lambda execution:" -ForegroundColor Yellow
Write-Host "  aws logs tail /aws/lambda/futureim-ecommerce-ai-platform-raw-to-curated --follow --region $Region" -ForegroundColor Cyan
Write-Host ""
Write-Host "Check S3 buckets:" -ForegroundColor Yellow
Write-Host "  Raw:     s3://$SharedRawBucket/ecommerce/" -ForegroundColor Cyan
Write-Host "  Curated: s3://ecommerce-curated-$AccountId/ecommerce/" -ForegroundColor Cyan
Write-Host "  Prod:    s3://<system>-prod-$AccountId/analytics/" -ForegroundColor Cyan
Write-Host ""
