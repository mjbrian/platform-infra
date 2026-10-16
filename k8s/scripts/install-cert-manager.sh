#!/usr/bin/env bash
# k8s/scripts/install-platform.sh
# Installs shared components before Argo CD exists. Safe to run any number of times.
set -euo pipefail
CTX=${1:-k3d-lab}
DIR="$(cd "$(dirname "$0")/../platform/cert-manager" && pwd)"
k() { kubectl --context "$CTX" "$@"; }

helm dependency build "$DIR/chart"
helm --kube-context "$CTX" upgrade --install cert-manager "$DIR/chart" \
  -n cert-manager --create-namespace --wait
k wait --for=condition=Established crd/clusterissuers.cert-manager.io --timeout=60s
k apply -f "$DIR/manifests/"
k wait --for=condition=Ready clusterissuer/lab-ca --timeout=120s
