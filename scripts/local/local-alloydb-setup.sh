#!/bin/bash
# local-alloydb-setup.sh
# Setup local Postgres container and secrets for development

set -e

# Source environment variables if .env file exists
if [ -f .env ]; then
    source .env
fi

# Validate required variables
if [ -z "$PROJECT_ID" ]; then
    echo "ERROR: Required environment variables not set."
    echo "Please set: PROJECT_ID"
    echo "You can create a .env file with: PROJECT_ID=your-project-id"
    exit 1
fi

# Set defaults for local development
PG_IMAGE=${PG_IMAGE:-postgres:16-alpine}
PG_CONTAINER_NAME=${PG_CONTAINER_NAME:-alloydb-local}
PG_PORT=${PG_PORT:-5432}
PG_PASSWORD=${PG_PASSWORD:-postgres123}
PG_USER=${PG_USER:-postgres}
PG_DATABASE=${PG_DATABASE:-carts}
PG_TABLE=${PG_TABLE:-cart_items}
PG_HOST=${PG_HOST:-host.docker.internal}
if [ "$PG_HOST" = "localhost" ]; then
    PG_HOST=host.docker.internal
fi
K8S_NAMESPACE=${K8S_NAMESPACE:-default}
LOCAL_SECRET_NAME=${LOCAL_SECRET_NAME:-alloydb-secret}

echo "🐘 Setting up local PostgreSQL container..."
echo "Project: $PROJECT_ID"
echo "Container: $PG_CONTAINER_NAME"
echo "Port: $PG_PORT"
echo "Database: $PG_DATABASE"
echo "Table: $PG_TABLE"

# Check if Docker is running
if ! docker info &>/dev/null; then
    echo "ERROR: Docker is not running. Please start Docker first."
    exit 1
fi

# Stop and remove existing container if it exists
if docker ps -a --format '{{.Names}}' | grep -q "^${PG_CONTAINER_NAME}$"; then
    echo "Removing existing container..."
    docker stop ${PG_CONTAINER_NAME} 2>/dev/null || true
    docker rm ${PG_CONTAINER_NAME} 2>/dev/null || true
fi

# Run PostgreSQL container
echo "🚀 Starting PostgreSQL container..."
docker run -d \
    --name ${PG_CONTAINER_NAME} \
    -e POSTGRES_USER=${PG_USER} \
    -e POSTGRES_PASSWORD=${PG_PASSWORD} \
    -e POSTGRES_DB=${PG_DATABASE} \
    -p ${PG_PORT}:5432 \
    --restart unless-stopped \
    ${PG_IMAGE}

# Wait for PostgreSQL to be ready
echo "⏳ Waiting for PostgreSQL to be ready..."
max_attempts=30
attempt=0
while [ $attempt -lt $max_attempts ]; do
    if docker exec ${PG_CONTAINER_NAME} pg_isready -U ${PG_USER} &>/dev/null; then
        break
    fi
    attempt=$((attempt + 1))
    echo "Waiting for PostgreSQL to start... (attempt $attempt/$max_attempts)"
    sleep 2
done

if [ $attempt -eq $max_attempts ]; then
    echo "ERROR: PostgreSQL failed to start after $max_attempts attempts"
    docker logs ${PG_CONTAINER_NAME}
    exit 1
fi

# Create table
echo "🗄️ Creating table..."
docker exec ${PG_CONTAINER_NAME} psql -U ${PG_USER} -d ${PG_DATABASE} -c "CREATE TABLE IF NOT EXISTS ${PG_TABLE} (userId text, productId text, quantity int, PRIMARY KEY(userId, productId))" 2>/dev/null || echo "Table already exists"
docker exec ${PG_CONTAINER_NAME} psql -U ${PG_USER} -d ${PG_DATABASE} -c "CREATE INDEX IF NOT EXISTS cartItemsByUserId ON ${PG_TABLE}(userId)" 2>/dev/null || echo "Index already exists"

# Get container IP address
PG_IP=$(docker inspect ${PG_CONTAINER_NAME} --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}')
echo "Container IP: $PG_IP"

# Save local connection details to .env
echo "💾 Saving local connection details to .env..."
# Remove existing ALLOYDB_PRIMARY_IP if it exists
sed -i.bak '/ALLOYDB_PRIMARY_IP/d' .env 2>/dev/null || true
sed -i.bak '/ALLOYDB_READ_IP/d' .env 2>/dev/null || true
sed -i.bak '/PG_PASSWORD/d' .env 2>/dev/null || true
sed -i.bak '/PG_HOST/d' .env 2>/dev/null || true
sed -i.bak '/PG_PORT/d' .env 2>/dev/null || true
rm -f .env.bak

cat >> .env << EOF
# Local PostgreSQL settings
ALLOYDB_PRIMARY_IP=${PG_HOST}
ALLOYDB_READ_IP=localhost
PG_PASSWORD=${PG_PASSWORD}
PG_HOST=${PG_HOST}
PG_PORT=${PG_PORT}
PG_DATABASE=${PG_DATABASE}
PG_TABLE=${PG_TABLE}
PG_USER=${PG_USER}
EOF

echo "✅ Local PostgreSQL setup complete!"
echo "Connection string: postgresql://${PG_USER}:${PG_PASSWORD}@localhost:${PG_PORT}/${PG_DATABASE}"
echo ""
echo "To test connection:"
echo "  docker exec -it ${PG_CONTAINER_NAME} psql -U ${PG_USER} -d ${PG_DATABASE}"