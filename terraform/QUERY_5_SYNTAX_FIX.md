# Query #5: Syntax Error Fix

## Error Encountered

After running the script to remove `count` parameters, Terraform reported 29 syntax errors:

```
Error: Invalid single-argument block definition

  on modules\api-gateway\main.tf line 751, in resource "aws_api_gateway_integration" "di_segments_lambda":
 751: resource "aws_api_gateway_integration" "di_segments_lambda" {  rest_api_id             = aws_api_gateway_rest_api.main.id
```

## Root Cause

The `fix-integration-count.ps1` script removed the `count` parameter lines but also removed the newline after the opening brace `{`, causing the first parameter to appear on the same line as the brace.

## Solution

Created `fix-brace-syntax.ps1` to add newlines after opening braces:

```powershell
# Fix the syntax error: {  rest_api_id should be {\n  rest_api_id
$pattern = '\{\s\s(rest_api_id)'
$replacement = "{`n  `$1"
$content = $content -replace $pattern, $replacement
```

## Files Modified

- **terraform/modules/api-gateway/main.tf** - Fixed 31 integration resources
- **terraform/fix-brace-syntax.ps1** - Created fix script

## Result

✅ All 29 syntax errors fixed
✅ Terraform can now parse the file
✅ Ready to deploy

## Next Steps

```powershell
cd terraform
terraform apply
```

## Documentation

- **Detailed Fix**: `terraform/FIX_SYNTAX_ERROR.md`
- **Complete Status**: `FINAL_API_GATEWAY_STATUS.md`

