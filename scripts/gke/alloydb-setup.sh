#!/bin/bash
# Provision AlloyDB database and supporting infrastructure

set -e # Exit immediately if a command exits with a non-zero status

# Source environment variables if .env file exists
if [ -f .env ]; then
    source .env
fi

# Validate required variables
if [ -z "$PROJECT_ID" ] || [ -z "$REGION" ] || [ -z "$PGPASSWORD" ]; then
    echo "ERROR: Required environment variables not set."
    echo "Please set: PROJECT_ID, REGION, PGPASSWORD"
    exit 1
fi

# Set defaults if not already set
ALLOYDB_NETWORK=${ALLOYDB_NETWORK:-default}
ALLOYDB_SERVICE_NAME=${ALLOYDB_SERVICE_NAME:-onlineboutique-network-range}
ALLOYDB_CLUSTER_NAME=${ALLOYDB_CLUSTER_NAME:-onlineboutique-cluster}
ALLOYDB_INSTANCE_NAME=${ALLOYDB_INSTANCE_NAME:-onlineboutique-instance}
ALLOYDB_DATABASE_NAME=${ALLOYDB_DATABASE_NAME:-carts}
ALLOYDB_TABLE_NAME=${ALLOYDB_TABLE_NAME:-cart_items}
ALLOYDB_SECRET_NAME=${ALLOYDB_SECRET_NAME:-alloydb-secret}

echo "📦 Provisioning AlloyDB infrastructure..."
echo "Project: $PROJECT_ID"
echo "Region: $REGION"
echo "Cluster: $ALLOYDB_CLUSTER_NAME"
echo "Instance: $ALLOYDB_INSTANCE_NAME"

# Enable required services
echo "🔧 Enabling required GCP services..."
gcloud services enable alloydb.googleapis.com
gcloud services enable servicenetworking.googleapis.com
gcloud services enable secretmanager.googleapis.com

# Create secret for database password
echo "🔐 Creating secret for database password..."
if gcloud secrets describe ${ALLOYDB_SECRET_NAME} &>/dev/null; then
    echo "Secret ${ALLOYDB_SECRET_NAME} already exists, updating..."
    echo -n ${PGPASSWORD} | gcloud secrets versions add ${ALLOYDB_SECRET_NAME} --data-file=-
else
    echo -n ${PGPASSWORD} | gcloud secrets create ${ALLOYDB_SECRET_NAME} --data-file=-
fi

# Setup VPC peering
echo "🌐 Setting up VPC peering..."
gcloud compute addresses create ${ALLOYDB_SERVICE_NAME} \
    --global \
    --purpose=VPC_PEERING \
    --prefix-length=16 \
    --description="Online Boutique Private Services" \
    --network=${ALLOYDB_NETWORK} 2>/dev/null || echo "Address already exists"

gcloud services vpc-peerings connect \
    --service=servicenetworking.googleapis.com \
    --ranges=${ALLOYDB_SERVICE_NAME} \
    --network=${ALLOYDB_NETWORK} 2>/dev/null || echo "VPC peering already exists"

# Create AlloyDB cluster
echo "🏗️ Creating AlloyDB cluster (this may take several minutes)..."
gcloud alloydb clusters create ${ALLOYDB_CLUSTER_NAME} \
    --region=${REGION} \
    --password=${PGPASSWORD} \
    --disable-automated-backup \
    --network=${ALLOYDB_NETWORK} 2>/dev/null || echo "Cluster already exists"

# Create primary instance
echo "📊 Creating primary instance (this may take 10-15 minutes)..."
gcloud alloydb instances create ${ALLOYDB_INSTANCE_NAME} \
    --cluster=${ALLOYDB_CLUSTER_NAME} \
    --region=${REGION} \
    --cpu-count=4 \
    --instance-type=PRIMARY 2>/dev/null || echo "Primary instance already exists"

# Create read replica
echo "📊 Creating read replica instance..."
gcloud alloydb instances create ${ALLOYDB_INSTANCE_NAME}-replica \
    --cluster=${ALLOYDB_CLUSTER_NAME} \
    --region=${REGION} \
    --cpu-count=4 \
    --instance-type=READ_POOL \
    --read-pool-node-count=2 2>/dev/null || echo "Read replica already exists"

# Get IP addresses
echo "🔍 Retrieving IP addresses..."
ALLOYDB_PRIMARY_IP=$(gcloud alloydb instances list \
    --region=${REGION} \
    --cluster=${ALLOYDB_CLUSTER_NAME} \
    --filter="INSTANCE_TYPE:PRIMARY" \
    --format=flattened | sed -nE "s/ipAddress:\s*(.*)/\1/p")

ALLOYDB_READ_IP=$(gcloud alloydb instances list \
    --region=${REGION} \
    --cluster=${ALLOYDB_CLUSTER_NAME} \
    --filter="INSTANCE_TYPE:READ_POOL" \
    --format=flattened | sed -nE "s/ipAddress:\s*(.*)/\1/p")

echo "Primary IP: $ALLOYDB_PRIMARY_IP"
echo "Read IP: $ALLOYDB_READ_IP"

# Wait for instances to be ready
echo "⏳ Waiting for instances to be ready..."
sleep 30

# Create database and table
echo "🗄️ Creating database and table..."
export PGPASSWORD=${PGPASSWORD}

# Wait for database to be ready before connecting
max_attempts=30
attempt=0
while [ $attempt -lt $max_attempts ]; do
    if psql -h ${ALLOYDB_PRIMARY_IP} -U postgres -c "SELECT 1" &>/dev/null; then
        break
    fi
    attempt=$((attempt + 1))
    echo "Waiting for database to be ready... (attempt $attempt/$max_attempts)"
    sleep 10
done

if [ $attempt -eq $max_attempts ]; then
    echo "ERROR: Database not ready after $max_attempts attempts"
    exit 1
fi

psql -h ${ALLOYDB_PRIMARY_IP} -U postgres -c "CREATE DATABASE ${ALLOYDB_DATABASE_NAME}" 2>/dev/null || echo "Database already exists"
psql -h ${ALLOYDB_PRIMARY_IP} -U postgres -d ${ALLOYDB_DATABASE_NAME} -c "CREATE TABLE ${ALLOYDB_TABLE_NAME} (userId text, productId text, quantity int, PRIMARY KEY(userId, productId))" 2>/dev/null || echo "Table already exists"
psql -h ${ALLOYDB_PRIMARY_IP} -U postgres -d ${ALLOYDB_DATABASE_NAME} -c "CREATE INDEX cartItemsByUserId ON ${ALLOYDB_TABLE_NAME}(userId)" 2>/dev/null || echo "Index already exists"

# Save IPs to .env for later use
echo "💾 Saving IP addresses to .env..."
cat >> .env << EOF
ALLOYDB_PRIMARY_IP=${ALLOYDB_PRIMARY_IP}
ALLOYDB_READ_IP=${ALLOYDB_READ_IP}
EOF

echo "✅ AlloyDB setup complete!"
echo "Primary IP: $ALLOYDB_PRIMARY_IP"
echo "Read IP: $ALLOYDB_READ_IP"