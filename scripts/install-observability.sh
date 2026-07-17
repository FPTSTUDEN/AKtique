#!/bin/bash
# scripts/install-observability.sh
# Uses the observability component to install the stack

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OBSERVABILITY_DIR="${SCRIPT_DIR}/../components/observability"

echo "🚀 Installing Observability Stack..."

# Create namespaces
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace istio-system --dry-run=client -o yaml | kubectl apply -f -

# 1. Install Prometheus
echo "📊 Installing Prometheus..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

helm upgrade --install prometheus prometheus-community/kube-prometheus-stack \
  -n monitoring \
  -f "${OBSERVABILITY_DIR}/helm-values/prometheus-values.yaml"

# 2. Install Jaeger
echo "🔍 Installing Jaeger..."
helm repo add jaegertracing https://jaegertracing.github.io/helm-charts
helm repo update

helm upgrade --install jaeger jaegertracing/jaeger \
  -n istio-system \
  -f "${OBSERVABILITY_DIR}/helm-values/jaeger-values.yaml"

# 3. Install Kiali
echo "🌐 Installing Kiali..."
helm repo add kiali https://kiali.org/helm-charts
helm repo update

helm upgrade --install kiali kiali/kiali-server \
  -n istio-system \
  -f "${OBSERVABILITY_DIR}/helm-values/kiali-values.yaml"

# 4. Apply additional configurations from the component
echo "📝 Applying observability configurations..."
kubectl apply -k "${OBSERVABILITY_DIR}"

echo "✅ Observability Stack installed!"

# kubectl get secret --namespace monitoring -l app.kubernetes.io/component=admin-secret -o jsonpath="{.items[0].data.admin-password}" | base64 --decode ; echo