#!/bin/bash
# local-deploy.sh
# Deploy Online Boutique with local PostgreSQL

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
PG_TABLE=${PG_TABLE:-cart_items}
PG_HOST=${PG_HOST:-postgres-service}
PG_PORT=${PG_PORT:-5432}
PG_USER=${PG_USER:-postgres}
K8S_NAMESPACE=${K8S_NAMESPACE:-default}
LOCAL_SECRET_NAME=${LOCAL_SECRET_NAME:-alloydb-secret}

echo "🚀 Deploying Online Boutique with local PostgreSQL..."
echo "Project: $PROJECT_ID"
echo "Database: $PG_DATABASE"
echo "Table: $PG_TABLE"
echo "Host: $PG_HOST"

# Check if we're in the right directory
if [ ! -d "kustomize" ]; then
    echo "ERROR: Must run from the root of the Online Boutique repository"
    exit 1
fi

# First, ensure secrets are set up
echo "Ensuring secrets are configured..."
if ! kubectl get secret ${LOCAL_SECRET_NAME} -n ${K8S_NAMESPACE} &>/dev/null; then
    echo "Secret not found. Running local-secret-setup.sh..."
    ./scripts/local/local-secret-setup.sh
fi

# Create a service for PostgreSQL if needed
echo "Creating PostgreSQL service..."
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: postgres-service
  namespace: ${K8S_NAMESPACE}
spec:
  selector:
    app: postgres-local
  ports:
    - protocol: TCP
      port: ${PG_PORT}
      targetPort: ${PG_PORT}
  type: ClusterIP
EOF

# cd kustomize/

# Create local component if it doesn't exist
if [ ! -d "components/local-alloydb" ]; then
    echo "Creating local component..."
    mkdir -p components/local-alloydb
fi

# Update kustomization.yaml
echo "Adding local AlloyDB component..."
cd overlays/dev
kustomize edit add component ../../components/local-alloydb 2>/dev/null || echo "Component already exists"
cd ../../

# Update component with variables
cat > components/local-alloydb/kustomization.yaml << EOF
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
            - name: DB_HOST
              value: ${PG_HOST}
            - name: DB_PORT
              value: "${PG_PORT}"
            - name: DB_USER
              value: ${PG_USER}
            - name: DB_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: ${LOCAL_SECRET_NAME}
                  key: postgresql-password
            - name: DB_NAME
              value: ${PG_DATABASE}
EOF

# Deploy
echo "Deploying to Kubernetes..."
# kubectl apply -k overlays/dev -n ${K8S_NAMESPACE}
skaffold run -p dev

# Wait for deployment to be ready
echo "⏳ Waiting for deployment to be ready..."
kubectl rollout status deployment/cartservice -n ${K8S_NAMESPACE}

echo "✅ Deployment complete!"
echo "Check status with: kubectl get pods -n ${K8S_NAMESPACE}"
echo "Check logs with: kubectl logs deployment/cartservice -n ${K8S_NAMESPACE}"

kubectl port-forward service/frontend 8000:80