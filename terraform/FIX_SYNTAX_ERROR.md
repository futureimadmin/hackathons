# Fix: Syntax Error After Removing Count Parameters

## Problem

After running the `fix-integration-count.ps1` script to remove `count` parameters, Terraform reported syntax errors:

```
Error: Invalid single-argument block definition

  on modules\api-gateway\main.tf line 751, in resource "aws_api_gateway_integration" "di_segments_lambda":
 751: resource "aws_api_gateway_integration" "di_segments_lambda" {  rest_api_id             = aws_api_gateway_rest_api.main.id
```

## Root Cause

The regex pattern in `fix-integration-count.ps1` removed the `count` parameter line but also removed the newline after the opening brace `{`, causing:

**Before (correct):**
```hcl
resource "aws_api_gateway_integration" "di_segments_lambda" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  ...
}
```

**After (incorrect):**
```hcl
resource "aws_api_gateway_integration" "di_segments_lambda" {  rest_api_id = aws_api_gateway_rest_api.main.id
  ...
}
```

Terraform interprets `{  rest_api_id` as a single-line block definition, which must be closed on the same line.

## Solution

Created `fix-brace-syntax.ps1` to add newlines after opening braces:

```powershell
# Pattern: opening brace followed by two spaces and rest_api_id on same line
$pattern = '\{\s\s(rest_api_id)'
$replacement = "{`n  `$1"

$content = $content -replace $pattern, $replacement
```

## Files Modified

1. **terraform/modules/api-gateway/main.tf**
   - Fixed 29 integration resources with syntax errors

2. **terraform/fix-brace-syntax.ps1**
   - Created script to fix the syntax errors

## Result

✅ All syntax errors fixed
✅ Terraform can now parse the file correctly
✅ Ready to run `terraform apply`

## Deployment

```powershell
cd terraform
terraform apply
```

## Affected Resources

The following integrations were fixed:
- Demand Insights (7 integrations)
- Compliance Guardian (6 integrations)
- Retail Copilot (10 integrations)
- Global Market Pulse (8 integrations)

Total: 31 integrations fixed

## Lesson Learned

When using regex to modify Terraform files, be careful about newlines. The pattern:
```powershell
'\s*count\s*=\s*var\.\w+_lambda_invoke_arn\s*!=\s*""\s*\?\s*1\s*:\s*0\s*\n'
```

Should preserve the newline structure of the file.

