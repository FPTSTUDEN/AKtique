# What I'd Actually Do

If I were building your mini-cloud from scratch:

### Month 1

```text
k3s
Online Boutique
Istio
Kiali
Grafana
Jaeger
```

### Month 2

```text
+ NATS
+ AI services
+ custom microservices
```

### Month 3

```text
+ Skaffold
```

### Month 4

```text
+ Argo CD
```

### Month 5+

```text
+ GitHub Actions
+ Canary deployments
+ Chaos engineering
```

That sequence keeps complexity proportional to the value you're getting. The biggest mistake people make is installing an entire platform stack (Argo, Backstage, Crossplane, Terraform, service catalogs, etc.) before they've even deployed and explored the microservices they're supposed to be managing.
For your current phase, I would **not start with CI/CD**.

Get this working first:

```text
k3s
├── Online Boutique
├── Istio
├── Kiali
├── Prometheus
├── Grafana
├── Jaeger
└── NATS
```

You can deploy everything with:

```bash
kubectl apply -f ...
```

for quite a while.

---

# Phase 1 — Manual Deployments

Goal:

* Understand the application
* Learn Kubernetes
* Learn Istio
* Learn observability

Workflow:

```text
Edit code
   ↓
Build image
   ↓
Push image
   ↓
kubectl rollout restart
```

Nothing wrong with this.

Many people add CI/CD before they understand what they're automating.

---

# Phase 2 — Local Image Automation

Once you start modifying services:

```text
recommendationservice
fraudservice
ai-support-service
```

add a simple build system.

Options:

* Makefile
* Taskfile
* Skaffold

I'd recommend:

Skaffold

because it was practically built for projects like Online Boutique.

Workflow:

```text
Save code
   ↓
Build image
   ↓
Deploy
   ↓
Watch logs
```

automatically.

This dramatically improves iteration speed.

---

# Phase 3 — GitOps

Once multiple people contribute.

Add:

Argo CD

Architecture:

```text
Git Repo
    ↓
Argo CD
    ↓
k3s
```

Benefits:

* Deployment history
* Rollbacks
* Drift detection
* Pull-request deployments

This is probably the single most educational CI/CD tool for a cloud-learning environment.

Participants immediately understand:

```text
Git = desired state
Cluster = actual state
```

---

# Phase 4 — Full CI Pipeline

Now add build automation.

Good lightweight stack:

```text
GitHub
   ↓
GitHub Actions
   ↓
Container Registry
   ↓
Argo CD
   ↓
k3s
```

Flow:

```text
Commit
   ↓
Tests
   ↓
Build image
   ↓
Push image
   ↓
Update manifests
   ↓
Argo syncs
```

This is essentially how many production Kubernetes teams operate.

---

# Phase 5 — Hackathon Features

Once Argo exists, interesting challenges become possible.

### Canary Deployments

Using Istio:

```text
v1 = 90%
v2 = 10%
```

Challenge:

> Release a new recommendation engine without affecting users.

---

### Rollback Challenge

Inject:

```text
bad release
```

Participants must:

```text
identify issue
rollback
verify recovery
```

---

### Deployment Race

Measure:

```text
lead time
deployment frequency
MTTR
```

This starts teaching DevOps metrics.

---

# Phase 6 — Platform Engineering

Much later.

Add:

* Argo Workflows
* Backstage
* Crossplane
* Terraform

These are powerful but add substantial complexity.

For a single-PC lab, they're often overkill until you've already exhausted the learning value of Online Boutique itself.

---