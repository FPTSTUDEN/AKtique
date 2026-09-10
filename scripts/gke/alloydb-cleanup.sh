#!/bin/bash
# Clean up all resources

set -e

# Source environment variables
if [ -f .env ]; then
    source .env
fi

# Validate required variables
if [ -z "$PROJECT_ID" ] || [ -z "$REGION" ]; then
    echo "ERROR: Required environment variables not set."
    echo "Please set: PROJECT_ID, REGION"
    exit 1
fi

# Set defaults
ALLOYDB_NETWORK=${ALLOYDB_NETWORK:-default}
ALLOYDB_SERVICE_NAME=${ALLOYDB_SERVICE_NAME:-onlineboutique-network-range}
ALLOYDB_CLUSTER_NAME=${ALLOYDB_CLUSTER_NAME:-onlineboutique-cluster}
ALLOYDB_INSTANCE_NAME=${ALLOYDB_INSTANCE_NAME:-onlineboutique-instance}
ALLOYDB_USER_GSA_NAME=${ALLOYDB_USER_GSA_NAME:-alloydb-user-sa}
ALLOYDB_USER_GSA_ID="${ALLOYDB_USER_GSA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"
ALLOYDB_SECRET_NAME=${ALLOYDB_SECRET_NAME:-alloydb-secret}

echo "🧹 Starting cleanup..."

# Delete Kubernetes deployments (if in the right directory)
if [ -f "kustomize/kustomization.yaml" ]; then
    echo "Removing Kubernetes resources..."
    cd kustomize/
    kubectl delete -k . 2>/dev/null || echo "No Kubernetes resources found"
    cd ..
fi

# Delete AlloyDB cluster
echo "🗄️ Deleting AlloyDB cluster..."
gcloud alloydb clusters delete ${ALLOYDB_CLUSTER_NAME} \
    --force \
    --region ${REGION} 2>/dev/null || echo "Cluster not found or already deleted"

# Delete VPC peering address
echo "🌐 Deleting VPC peering address..."
gcloud compute addresses delete ${ALLOYDB_SERVICE_NAME} \
    --global 2>/dev/null || echo "Address not found"

# Delete service account
echo "🔐 Deleting service account..."
gcloud iam service-accounts delete ${ALLOYDB_USER_GSA_ID} \
    --quiet 2>/dev/null || echo "Service account not found"

# Delete secret
echo "🔐 Deleting secret..."
gcloud secrets delete ${ALLOYDB_SECRET_NAME} \
    --quiet 2>/dev/null || echo "Secret not found"

# Remove .env file (optional)
read -p "Remove .env file? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    rm .env
    echo "Removed .env file"
fi

echo "✅ Cleanup complete!"