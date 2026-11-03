terraform {
  required_version = ">= 1.7"
  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = ">= 3.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.38"
    }
  }
}

variable "cluster_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "profile" {
  type    = string
  default = ""
}

variable "chart_version" {
  type = string
}

variable "values" {
  type = string
}

resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = var.chart_version
  namespace        = "argocd"
  create_namespace = true
  values           = [var.values]

  lifecycle {
    ignore_changes = all
  }
}

resource "kubernetes_secret_v1" "this_cluster" {
  metadata {
    name      = "cluster-${var.cluster_name}"
    namespace = "argocd"
    labels = merge(
      {
        "argocd.argoproj.io/secret-type" = "cluster"
        environment                      = var.environment
        "profile.core"                   = "on"
      },
      var.profile == "" ? {} : { "profile.${var.profile}" = "on" }
    )
  }

  data = {
    name   = var.cluster_name
    server = "https://kubernetes.default.svc"
    config = jsonencode({ tlsClientConfig = { insecure = false } })
  }

  depends_on = [helm_release.argocd]
}
