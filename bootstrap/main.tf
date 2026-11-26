# Run ONCE, locally, with admin credentials. Creates:
#   - S3 bucket for Terraform remote state (native S3 locking, Terraform >= 1.10)
#   - GitHub OIDC provider + IAM role the pipeline assumes (no long-lived AWS keys)
terraform {
  required_version = ">= 1.10"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.90" }
  }
}

variable "aws_region" {
  type    = string
  default = "ap-south-1"
}
variable "github_repo" {
  type        = string
  description = "GitHub repo in the form owner/name"
}
variable "state_bucket_name" {
  type        = string
  description = "Globally unique S3 bucket name for Terraform state"
}

provider "aws" {
  region = var.aws_region
}

resource "aws_s3_bucket" "state" {
  bucket = var.state_bucket_name
}

resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.state.id
  rule {
    apply_server_side_encryption_by_default { sse_algorithm = "AES256" }
  }
}

resource "aws_s3_bucket_public_access_block" "state" {
  bucket                  = aws_s3_bucket.state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
}

data "aws_iam_policy_document" "trust" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values = [
        "repo:${var.github_repo}:ref:refs/heads/main",
        "repo:${var.github_repo}:pull_request",
        "repo:${var.github_repo}:environment:production",
      ]
    }
  }
}

resource "aws_iam_role" "pipeline" {
  name               = "github-actions-deployer"
  assume_role_policy = data.aws_iam_policy_document.trust.json
}

# NOTE: AdministratorAccess keeps the demo simple because Terraform creates IAM
# roles, VPCs, ALBs, etc. For production, replace with a scoped policy.
resource "aws_iam_role_policy_attachment" "pipeline_admin" {
  role       = aws_iam_role.pipeline.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

output "role_arn" {
  value = aws_iam_role.pipeline.arn
}
output "state_bucket" {
  value = aws_s3_bucket.state.id
}
