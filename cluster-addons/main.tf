terraform {
  required_version = ">= 1.7"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.38"
    }
  }
  backend "local" {}
}

variable "region" {
  type = string
}

variable "aws_endpoint" {
  type    = string
  default = null
}

variable "cluster_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "kube_proxy_version" {
  type = string
}

variable "calico_chart_version" {
  type = string
}

variable "gitops_dir" {
  type        = string
  description = "Where bootstrap keeps its copy of platform-gitops"
}

variable "profile" {
  type    = string
  default = ""
  validation {
    condition     = contains(["", "observability", "delivery", "portal"], var.profile)
    error_message = "profile must be empty, observability, delivery or portal."
  }
}

locals {
  emulated = var.aws_endpoint != null
  exec_env = local.emulated ? { AWS_ENDPOINT_URL = var.aws_endpoint } : {}
}

provider "aws" {
  region                      = var.region
  skip_credentials_validation = local.emulated
  skip_metadata_api_check     = local.emulated
  skip_requesting_account_id  = local.emulated

  endpoints {
    eks = var.aws_endpoint
    sts = var.aws_endpoint
  }
}

data "aws_eks_cluster" "this" {
  name = var.cluster_name
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.this.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.this.certificate_authority[0].data)
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", var.cluster_name, "--region", var.region, "--output", "json"]
    env         = local.exec_env
  }
}

provider "helm" {
  kubernetes = {
    host                   = data.aws_eks_cluster.this.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.this.certificate_authority[0].data)
    exec = {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", var.cluster_name, "--region", var.region, "--output", "json"]
      env         = local.exec_env
    }
  }
}

module "base" {
  source               = "./modules/cluster-base"
  kube_proxy_version   = var.kube_proxy_version
  calico_chart_version = var.calico_chart_version
}
