#!/bin/bash
# Deploy Online Boutique with AlloyDB integration

set -e

# Source environment variables
if [ -f .env ]; then
    source .env
fi

# Validate required variables
if [ -z "$PROJECT_ID" ] || [ -z "$ALLOYDB_PRIMARY_IP" ]; then
    echo "ERROR: Required environment variables not set."
    echo "Please set: PROJECT_ID, ALLOYDB_PRIMARY_IP"
    echo "Run alloydb-setup.sh first if you haven't."
    exit 1
fi

# Set defaults
ALLOYDB_USER_GSA_NAME=${ALLOYDB_USER_GSA_NAME:-alloydb-user-sa}
ALLOYDB_USER_GSA_ID="${ALLOYDB_USER_GSA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"
ALLOYDB_DATABASE_NAME=${ALLOYDB_DATABASE_NAME:-carts}
ALLOYDB_TABLE_NAME=${ALLOYDB_TABLE_NAME:-cart_items}
ALLOYDB_SECRET_NAME=${ALLOYDB_SECRET_NAME:-alloydb-secret}
CARTSERVICE_KSA_NAME=${CARTSERVICE_KSA_NAME:-cartservice}

echo "🚀 Deploying Online Boutique with AlloyDB..."
echo "Project: $PROJECT_ID"
echo "Primary IP: $ALLOYDB_PRIMARY_IP"
echo "Database: $ALLOYDB_DATABASE_NAME"
echo "Table: $ALLOYDB_TABLE_NAME"

# Check if we're in the right directory
if [ ! -d "kustomize" ]; then
    echo "ERROR: Must run from the root of the Online Boutique repository"
    exit 1
fi

cd kustomize/

# Update kustomization.yaml
echo "Adding AlloyDB component..."
kustomize edit add component components/alloydb 2>/dev/null || echo "Component already exists"

# Update component with variables
echo "Updating component with variables..."
sed -i.bak "s/PROJECT_ID_VAL/${PROJECT_ID}/g" components/alloydb/kustomization.yaml
sed -i.bak "s/ALLOYDB_PRIMARY_IP_VAL/${ALLOYDB_PRIMARY_IP}/g" components/alloydb/kustomization.yaml
sed -i.bak "s/ALLOYDB_USER_GSA_ID/${ALLOYDB_USER_GSA_ID}/g" components/alloydb/kustomization.yaml
sed -i.bak "s/ALLOYDB_DATABASE_NAME_VAL/${ALLOYDB_DATABASE_NAME}/g" components/alloydb/kustomization.yaml
sed -i.bak "s/ALLOYDB_TABLE_NAME_VAL/${ALLOYDB_TABLE_NAME}/g" components/alloydb/kustomization.yaml
sed -i.bak "s/ALLOYDB_SECRET_NAME_VAL/${ALLOYDB_SECRET_NAME}/g" components/alloydb/kustomization.yaml

# Remove backup file
rm components/alloydb/kustomization.yaml.bak 2>/dev/null

# Deploy
echo "Deploying to Kubernetes..."
kubectl apply -k .

echo "✅ Deployment complete!"
echo "Check status with: kubectl get pods"