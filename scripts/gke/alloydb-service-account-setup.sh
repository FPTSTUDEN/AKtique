#!/bin/bash
# Setup service account with Workload Identity

set -e

# Source environment variables
if [ -f .env ]; then
    source .env
fi

# Validate required variables
if [ -z "$PROJECT_ID" ]; then
    echo "ERROR: PROJECT_ID not set"
    exit 1
fi

# Set defaults
ALLOYDB_USER_GSA_NAME=${ALLOYDB_USER_GSA_NAME:-alloydb-user-sa}
CARTSERVICE_KSA_NAME=${CARTSERVICE_KSA_NAME:-cartservice}
ALLOYDB_SECRET_NAME=${ALLOYDB_SECRET_NAME:-alloydb-secret}

ALLOYDB_USER_GSA_ID="${ALLOYDB_USER_GSA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"

echo "🔐 Setting up service account..."
echo "Project: $PROJECT_ID"
echo "Service Account: $ALLOYDB_USER_GSA_ID"

# Create service account
echo "Creating service account..."
gcloud iam service-accounts create ${ALLOYDB_USER_GSA_NAME} \
    --display-name="${ALLOYDB_USER_GSA_NAME}" 2>/dev/null || echo "Service account already exists"

# Grant permissions
echo "Granting permissions..."
gcloud projects add-iam-policy-binding ${PROJECT_ID} \
    --member=serviceAccount:${ALLOYDB_USER_GSA_ID} \
    --role=roles/alloydb.client

gcloud projects add-iam-policy-binding ${PROJECT_ID} \
    --member=serviceAccount:${ALLOYDB_USER_GSA_ID} \
    --role=roles/secretmanager.secretAccessor

# Bind service account to Kubernetes service account
echo "Binding to Kubernetes service account..."
gcloud iam service-accounts add-iam-policy-binding ${ALLOYDB_USER_GSA_ID} \
    --member "serviceAccount:${PROJECT_ID}.svc.id.goog[default/${CARTSERVICE_KSA_NAME}]" \
    --role roles/iam.workloadIdentityUser

echo "✅ Service account setup complete!"
echo "Service Account: $ALLOYDB_USER_GSA_ID"