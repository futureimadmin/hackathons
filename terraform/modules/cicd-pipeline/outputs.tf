# Outputs for CI/CD Pipeline Module

output "pipeline_name" {
  description = "Name of the CodePipeline"
  value       = aws_codepipeline.main.name
}

output "pipeline_arn" {
  description = "ARN of the CodePipeline"
  value       = aws_codepipeline.main.arn
}

output "pipeline_url" {
  description = "URL to the CodePipeline in AWS Console"
  value       = "https://console.aws.amazon.com/codesuite/codepipeline/pipelines/${aws_codepipeline.main.name}/view?region=${var.aws_region}"
}

output "artifacts_bucket" {
  description = "S3 bucket for pipeline artifacts"
  value       = aws_s3_bucket.pipeline_artifacts.bucket
}

output "github_connection_arn" {
  description = "ARN of GitHub connection"
  value       = aws_codestarconnections_connection.github.arn
}

output "github_connection_status" {
  description = "Status of GitHub connection"
  value       = aws_codestarconnections_connection.github.connection_status
}

output "codebuild_projects" {
  description = "CodeBuild project names"
  value = {
    java_lambda     = aws_codebuild_project.java_lambda.name
    python_lambdas  = aws_codebuild_project.python_lambdas.name
    frontend        = aws_codebuild_project.frontend.name
  }
}
