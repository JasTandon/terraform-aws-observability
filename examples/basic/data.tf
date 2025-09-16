# Discover account/region (used to build ARNs in the IAM inline policy)
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}