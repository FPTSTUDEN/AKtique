#!/bin/bash
# local-cleanup.sh
# Clean up local development resources

set -e

# Source environment variables
if [ -f .env ]; then
    source .env
fi

# Set defaults
PG_CONTAINER_NAME=${PG_CONTAINER_NAME:-alloydb-local}
K8S_NAMESPACE=${K8S_NAMESPACE:-default}
LOCAL_SECRET_NAME=${LOCAL_SECRET_NAME:-alloydb-secret}
K8S_SECRET_NAME=${K8S_SECRET_NAME:-alloydb-secret}

echo "🧹 Starting local cleanup..."

# Stop and remove PostgreSQL container
echo "🐘 Removing PostgreSQL container..."
if docker ps -a --format '{{.Names}}' | grep -q "^${PG_CONTAINER_NAME}$"; then
    docker stop ${PG_CONTAINER_NAME} 2>/dev/null || true
    docker rm ${PG_CONTAINER_NAME} 2>/dev/null || true
    echo "Container removed"
else
    echo "Container not found"
fi

# Remove Kubernetes secret
echo "🔐 Removing Kubernetes secret..."
if command -v kubectl &>/dev/null; then
    kubectl delete secret ${K8S_SECRET_NAME} -n ${K8S_NAMESPACE} 2>/dev/null || echo "Secret not found"
    kubectl delete configmap gsm-simulation -n ${K8S_NAMESPACE} 2>/dev/null || echo "ConfigMap not found"
else
    echo "kubectl not available"
fi

# Remove local Kustomize component
echo "📁 Removing local Kustomize component..."
rm -rf kustomize/components/local-alloydb 2>/dev/null || true

# Remove local entries from .env
if [ -f .env ]; then
    echo "Removing local entries from .env..."
    sed -i.bak '/# Local PostgreSQL settings/d' .env 2>/dev/null || true
    sed -i.bak '/ALLOYDB_PRIMARY_IP=localhost/d' .env 2>/dev/null || true
    sed -i.bak '/ALLOYDB_READ_IP=localhost/d' .env 2>/dev/null || true
    sed -i.bak '/PG_PASSWORD=/d' .env 2>/dev/null || true
    sed -i.bak '/PG_HOST=localhost/d' .env 2>/dev/null || true
    sed -i.bak '/PG_PORT=/d' .env 2>/dev/null || true
    sed -i.bak '/PG_DATABASE=/d' .env 2>/dev/null || true
    sed -i.bak '/PG_TABLE=/d' .env 2>/dev/null || true
    sed -i.bak '/PG_USER=/d' .env 2>/dev/null || true
    rm -f .env.bak
fi

echo "✅ Local cleanup complete!"