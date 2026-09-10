#!/bin/bash
# local-secret-setup.sh
# Setup Kubernetes secrets for local development with PostgreSQL

set -e

# Source environment variables
if [ -f .env ]; then
    source .env
fi

# Validate required variables
if [ -z "$PROJECT_ID" ] || [ -z "$PG_PASSWORD" ]; then
    echo "ERROR: Required environment variables not set."
    echo "Please set: PROJECT_ID, PG_PASSWORD"
    echo "Run local-alloydb-setup.sh first if you haven't."
    exit 1
fi

# Set defaults
PG_DATABASE=${PG_DATABASE:-carts}
PG_USER=${PG_USER:-postgres}
PG_TABLE=${PG_TABLE:-cart_items}
PG_PORT=${PG_PORT:-5432}
PG_HOST=${PG_HOST:-host.docker.internal}
if [ "$PG_HOST" = "localhost" ]; then
  PG_HOST=host.docker.internal
fi
K8S_NAMESPACE=${K8S_NAMESPACE:-default}
LOCAL_SECRET_NAME=${LOCAL_SECRET_NAME:-alloydb-secret}
K8S_SECRET_NAME=${K8S_SECRET_NAME:-alloydb-secret}

echo "🔐 Setting up Kubernetes secrets for local development..."
echo "Project: $PROJECT_ID"
echo "Secret: $K8S_SECRET_NAME"
echo "Namespace: $K8S_NAMESPACE"

# Check if kubectl is available
if ! command -v kubectl &>/dev/null; then
    echo "ERROR: kubectl is not installed"
    exit 1
fi

# Check if minikube or kind is running (optional)
if command -v minikube &>/dev/null && minikube status &>/dev/null; then
    echo "ℹ️ Minikube is running"
elif command -v kind &>/dev/null && kind get clusters &>/dev/null; then
    echo "ℹ️ Kind is running"
fi

# Create or update Kubernetes secret
echo "Creating/updating secret ${K8S_SECRET_NAME} in namespace ${K8S_NAMESPACE}..."
kubectl create secret generic ${K8S_SECRET_NAME} \
    -n ${K8S_NAMESPACE} \
    --from-literal=postgresql-password="${PG_PASSWORD}" \
    --from-literal=postgresql-username="${PG_USER}" \
    --from-literal=postgresql-database="${PG_DATABASE}" \
    --from-literal=postgresql-host="${PG_HOST}" \
    --from-literal=postgresql-port="${PG_PORT}" \
    --from-literal=postgresql-table="${PG_TABLE}" \
    --dry-run=client -o yaml | kubectl apply -f -

# Update the deployment to use the local secret
echo "Updating Kustomize component for local development..."

# Create or update kustomization patch for local development
mkdir -p kustomize/components/local-alloydb

cat > kustomize/components/local-alloydb/kustomization.yaml << EOF
apiVersion: kustomize.config.k8s.io/v1alpha1
kind: Component

patches:
- target:
    kind: Deployment
    name: cartservice
  patch: |-
    apiVersion: apps/v1
    kind: Deployment
    metadata:
      name: cartservice
    spec:
      template:
        spec:
          containers:
          - name: server
            env:
            - name: REDIS_ADDR
              \$patch: delete
            - name: ALLOYDB_PRIMARY_IP
              value: ${PG_HOST}
            - name: ALLOYDB_PORT
              value: "${PG_PORT}"
            - name: ALLOYDB_DATABASE_NAME
              value: ${PG_DATABASE}
            - name: ALLOYDB_TABLE_NAME
              value: ${PG_TABLE}
            - name: ALLOYDB_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: ${K8S_SECRET_NAME}
                  key: postgresql-password
            - name: ALLOYDB_USER
              value: ${PG_USER}
EOF

echo "✅ Kubernetes secrets setup complete!"
echo ""
echo "To deploy with local PostgreSQL:"
echo "  cd kustomize/"
echo "  kustomize edit add component components/local-alloydb"
echo "  kubectl apply -k ."
echo ""
echo "To verify the secret:"
echo "  kubectl get secret ${K8S_SECRET_NAME} -n ${K8S_NAMESPACE} -o yaml"
echo ""
echo "To view secret values (base64 encoded):"
echo "  kubectl get secret ${K8S_SECRET_NAME} -n ${K8S_NAMESPACE} -o jsonpath='{.data}'"