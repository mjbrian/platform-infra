terraform {
  required_version = ">= 1.7"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
  backend "local" {}
}

variable "target" {
  type        = string
  description = "Environment name, used only in names and tags"
}

variable "region" {
  type        = string
  description = "AWS region for every resource"
}

variable "name_prefix" {
  type        = string
  description = "Start of names that must be unique across all of AWS"
}

variable "aws_endpoint" {
  type        = string
  default     = null
  description = "Set for an emulator such as Floci. Leave unset for real AWS"
}

locals {
  emulated = var.aws_endpoint != null
}

provider "aws" {
  region                      = var.region
  skip_credentials_validation = local.emulated
  skip_metadata_api_check     = local.emulated
  skip_requesting_account_id  = local.emulated
  s3_use_path_style           = local.emulated

  endpoints {
    dynamodb       = var.aws_endpoint
    iam            = var.aws_endpoint
    s3             = var.aws_endpoint
    secretsmanager = var.aws_endpoint
    sts            = var.aws_endpoint
  }

  default_tags {
    tags = {
      lab    = "true"
      target = var.target
      ttl    = "never"
    }
  }
}

resource "aws_s3_bucket" "tf_state" {
  bucket = "${var.name_prefix}-tf-state-${var.target}"
}

resource "aws_s3_bucket_versioning" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_dynamodb_table" "tf_lock" {
  name         = "lab-tf-lock"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
}

resource "aws_secretsmanager_secret" "bootstrap_check" {
  name = "lab/bootstrap-check"
}

resource "aws_secretsmanager_secret_version" "bootstrap_check" {
  secret_id     = aws_secretsmanager_secret.bootstrap_check.id
  secret_string = "ok"
}

resource "aws_iam_role" "eks_cluster" {
  name = "lab-eks-cluster"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "eks.amazonaws.com" }
      Action    = ["sts:AssumeRole", "sts:TagSession"]
    }]
  })
}

resource "aws_iam_role_policy_attachment" "eks_cluster" {
  role       = aws_iam_role.eks_cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_iam_role" "eks_node" {
  name = "lab-eks-node"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "eks_node" {
  for_each   = toset(["AmazonEKSWorkerNodePolicy", "AmazonEKS_CNI_Policy"])
  role       = aws_iam_role.eks_node.name
  policy_arn = "arn:aws:iam::aws:policy/${each.key}"
}

output "state_bucket" {
  value = aws_s3_bucket.tf_state.bucket
}
