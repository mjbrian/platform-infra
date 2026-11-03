terraform {
  required_version = ">= 1.7"
  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.38"
    }
  }
}

variable "kube_proxy_version" {
  type = string
}

variable "calico_chart_version" {
  type = string
}

variable "argocd_manager" {
  type        = bool
  description = "Create a login Argo CD on mgmt can use to manage this cluster"
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

resource "kubernetes_service_account_v1" "argocd_manager" {
  count = var.argocd_manager ? 1 : 0
  metadata {
    name      = "argocd-manager"
    namespace = "kube-system"
  }
}

resource "kubernetes_cluster_role_binding_v1" "argocd_manager" {
  count = var.argocd_manager ? 1 : 0
  metadata {
    name = "argocd-manager"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "cluster-admin"
  }
  subject {
    kind      = "ServiceAccount"
    name      = "argocd-manager"
    namespace = "kube-system"
  }
}

resource "kubernetes_secret_v1" "argocd_manager" {
  count = var.argocd_manager ? 1 : 0
  metadata {
    name      = "argocd-manager-token"
    namespace = "kube-system"
    annotations = {
      "kubernetes.io/service-account.name" = kubernetes_service_account_v1.argocd_manager[0].metadata[0].name
    }
  }
  type                           = "kubernetes.io/service-account-token"
  wait_for_service_account_token = true
}

output "argocd_token" {
  value     = var.argocd_manager ? kubernetes_secret_v1.argocd_manager[0].data["token"] : null
  sensitive = true
}
