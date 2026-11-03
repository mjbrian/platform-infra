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

variable "aws_endpoint" {
  type        = string
  default     = null
  description = "Set for an emulator such as Floci. Leave unset for real AWS"
}

variable "eks_version" {
  type        = string
  description = "Kubernetes version, from versions.env unless the cluster's settings file sets its own"
}

variable "cluster_name" {
  type        = string
  description = "The cluster's name, such as dev"
}

variable "environment" {
  type        = string
  description = "The environment label, usually the same as the name"
}

variable "instance_type" {
  type        = string
  description = "Machine size for the cluster's node"
}

locals {
  emulated = var.aws_endpoint != null

  node_user_data = <<-EOT
    MIME-Version: 1.0
    Content-Type: multipart/mixed; boundary="==LAB=="

    --==LAB==
    Content-Type: text/x-shellscript; charset="us-ascii"

    #!/bin/sh
    set -eu
    mkdir -p /etc/containerd/certs.d/docker.io /etc/containerd/certs.d/ghcr.io
    cat > /etc/containerd/certs.d/docker.io/hosts.toml <<'EOF'
    server = "https://registry-1.docker.io"
    [host."http://cache-docker-io:5000"]
      capabilities = ["pull", "resolve"]
    EOF
    cat > /etc/containerd/certs.d/ghcr.io/hosts.toml <<'EOF'
    server = "https://ghcr.io"
    [host."http://cache-ghcr-io:5000"]
      capabilities = ["pull", "resolve"]
    EOF

    --==LAB==--
  EOT
}

provider "aws" {
  region                      = var.region
  skip_credentials_validation = local.emulated
  skip_metadata_api_check     = local.emulated
  skip_requesting_account_id  = local.emulated

  endpoints {
    ec2 = var.aws_endpoint
    eks = var.aws_endpoint
    iam = var.aws_endpoint
    sts = var.aws_endpoint
  }

  default_tags {
    tags = {
      lab    = "true"
      target = var.target
      ttl    = "never"
    }
  }
}

data "aws_iam_role" "cluster" {
  name = "lab-eks-cluster"
}

data "aws_iam_role" "node" {
  name = "lab-eks-node"
}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

resource "aws_launch_template" "node" {
  name      = "lab-eks-node-${var.cluster_name}"
  user_data = base64encode(local.node_user_data)
}

resource "aws_eks_cluster" "this" {
  name     = var.cluster_name
  role_arn = data.aws_iam_role.cluster.arn
  version  = var.eks_version

  vpc_config {
    subnet_ids = data.aws_subnets.default.ids
  }

  access_config {
    authentication_mode                         = "API_AND_CONFIG_MAP"
    bootstrap_cluster_creator_admin_permissions = true
  }

  tags = {
    environment = var.environment
  }
}

resource "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "main"
  node_role_arn   = data.aws_iam_role.node.arn
  subnet_ids      = data.aws_subnets.default.ids
  ami_type        = "AL2023_ARM_64_STANDARD"
  instance_types  = [var.instance_type]

  scaling_config {
    desired_size = 1
    min_size     = 1
    max_size     = 1
  }

  launch_template {
    id      = aws_launch_template.node.id
    version = aws_launch_template.node.latest_version
  }

  labels = {
    environment = var.environment
  }
}

output "endpoint" {
  value = aws_eks_cluster.this.endpoint
}
