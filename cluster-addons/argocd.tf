locals {
  argocd_chart_version = yamldecode(file("${var.gitops_dir}/apps/argocd.yaml")).spec.sources[0].targetRevision
  argocd_values        = file("${path.module}/../k8s/platform/argocd/values.yaml")
}

module "argocd" {
  source        = "./modules/argocd"
  cluster_name  = var.cluster_name
  environment   = var.environment
  profile       = var.profile
  chart_version = local.argocd_chart_version
  values        = local.argocd_values
  depends_on    = [module.base]
}
