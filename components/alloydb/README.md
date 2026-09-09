# Integrate Online Boutique with AlloyDB

By default the `cartservice` stores its data in an in-cluster Redis database. Using a fully managed database service outside your GKE cluster (such as [AlloyDB](https://cloud.google.com/alloydb)) could bring more resiliency and more security.

> **Note:** Due to AlloyDB's current connectivity requirements, you'll need to run this from a VM with VPC access to the network you want to use. Cloud Shell doesn't work because of transitive VPC peering limitations.

## Quick Start

### 1. Set Environment Variables

```bash
# Required variables - replace <values> with your own
PROJECT_ID=<project_id>
REGION=<region>  # See available regions: https://cloud.google.com/alloydb/docs/locations
PGPASSWORD=<password>  # Don't use $ in the password

# Optional variables (defaults shown)
ALLOYDB_NETWORK=default
ALLOYDB_CLUSTER_NAME=onlineboutique-cluster
ALLOYDB_INSTANCE_NAME=onlineboutique-instance
ALLOYDB_DATABASE_NAME=carts
ALLOYDB_TABLE_NAME=cart_items
ALLOYDB_SECRET_NAME=alloydb-secret
```

### 2. Provision AlloyDB Infrastructure

Run the [alloydb-setup.sh](./scripts/gke/alloydb-setup.sh) script to provision AlloyDB and supporting infrastructure:

```bash
./scripts/gke/alloydb-setup.sh
```

> **Note:** AlloyDB instance creation can take 20+ minutes.

### 3. Setup Service Account

```bash
./scripts/gke/service-account-setup.sh
```

### 4. Deploy Online Boutique

Run the deployment script:

```bash
./scripts/gke/deploy-with-alloydb.sh
```

Or manually with Kustomize:

```bash
cd kustomize/
kustomize edit add component components/alloydb
kubectl apply -k .
```

### 5. Cleanup

When you're done, remove all resources:

```bash
./scripts/gke/cleanup.sh
```

## Manual Steps Reference

- [Provision AlloyDB](./scripts/gke/alloydb-setup.sh)
- [Setup Service Account](./scripts/gke/service-account-setup.sh)
- [Deploy Application](./scripts/gke/deploy-with-alloydb.sh)
- [Cleanup Resources](./scripts/gke/cleanup.sh)