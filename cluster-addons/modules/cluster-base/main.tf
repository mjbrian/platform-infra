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

variable "kube_proxy_version" {
  type = string
}

variable "calico_chart_version" {
  type = string
}

locals {
  platform = "${path.module}/../../../k8s/platform"
}

resource "helm_release" "kube_proxy" {
  name      = "kube-proxy"
  chart     = "${local.platform}/kube-proxy"
  namespace = "kube-system"
  set = [{
    name  = "version"
    value = var.kube_proxy_version
  }]
}

resource "helm_release" "calico" {
  name             = "calico"
  repository       = "https://docs.tigera.io/calico/charts"
  chart            = "tigera-operator"
  version          = var.calico_chart_version
  namespace        = "tigera-operator"
  create_namespace = true
  values           = [file("${local.platform}/calico/values.yaml")]
  depends_on       = [helm_release.kube_proxy]

  lifecycle {
    ignore_changes = all
  }
}
