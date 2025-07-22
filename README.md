# SRE Kubernetes Assignment

## Overview
This project demonstrates a reliable, secure, observable, and scalable microservices system on Kubernetes, as a practical SRE assignment. It includes three web services (Node.js, Go, Python), PostgreSQL, and MinIO, with full CI/CD, monitoring, and disaster recovery features.

---

## Architecture Diagram
```
                ┌───────────────┐
                │   Ingress     │
                │   (NGINX)     │
                └──────┬────────┘
                       │
        ┌───────────────┼───────────────┐
        │               │               │
        ▼               ▼               ▼
┌───────────────┐ ┌───────────────┐ ┌───────────────┐
│ Auth Service  │ │  API Service  │ │ Image Storage │
│ (Node.js)     │ │   (Go)        │ │  (Python)     │
│ Port: 3001    │ │ Port: 3002    │ │ Port: 3003    │
└──────┬────────┘ └──────┬────────┘ └──────┬────────┘
       │                 │                 │
       ▼                 ▼                 ▼
┌───────────────┐ ┌───────────────┐ ┌───────────────┐
│ PostgreSQL    │ │ PostgreSQL    │ │ PostgreSQL    │
│ (auth_db)     │ │ (api_db)      │ │ (image_db)    │
└───────────────┘ └───────────────┘ └───────────────┘
       │                 │                 │
       └─────────────────┼─────────────────┘
                         ▼
                  ┌───────────────┐
                  │    MinIO      │
                  │   (images)    │
                  └───────────────┘

Monitoring: Prometheus, Grafana, Alertmanager (monitoring namespace)
```

---

## Quickstart
1. **Clone the repo:**
   ```sh
git clone <repo-url>
cd sre-k8s-assignment
```
2. **Build & Push Images:**
   - Update Docker Hub username in scripts if needed.
   - Run:
   ```sh
./scripts/build-and-push.sh
```
3. **Deploy to Minikube:**
   ```sh
minikube start
bash scripts/minikube-deploy.sh
```
4. **Deploy Monitoring:**
   ```sh
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm install monitoring prometheus-community/kube-prometheus-stack --namespace monitoring --create-namespace
```
5. **Access Services:**
   - API: `kubectl port-forward svc/api-service 8080:80 -n api`
   - Auth: `kubectl port-forward svc/auth-service 3001:80 -n auth`
   - Image: `kubectl port-forward svc/image-storage-service 3003:80 -n image-storage`
6. **Access Monitoring:**
   - Grafana: `kubectl port-forward svc/monitoring-grafana 3000:80 -n monitoring`
   - Prometheus: `kubectl port-forward svc/monitoring-kube-prometheus-prometheus 9090:9090 -n monitoring`
   - Grafana login: `admin/prom-operator`

---

## Features & SRE Goals
- **Isolation:** Namespaces, NetworkPolicies, and Secrets for all services.
- **Containerization:** Multi-stage Dockerfiles, non-root users, resource limits.
- **Deployment:** Separate YAMLs for Deployments, Services, Ingress, HPA, PDB, etc.
- **Security:** TLS via Ingress, network-level isolation, secrets management.
- **Observability:** Prometheus metrics, Grafana dashboards, Alertmanager rules.
- **Scalability:** HPA for all services, resource requests/limits, PDBs.
- **Disaster Recovery:** Failure simulation scripts, auto-rescheduling, logs/events.

---

## Failure Simulation & Recovery
- **Run:** `bash scripts/failure-simulation.sh`
- Simulates DB crash, service crash, high traffic, node failure, resource exhaustion.
- Observe recovery via `kubectl get pods -A`, logs, and monitoring dashboards.

---

## Lessons Learned & Improvements
- **Lessons:**
  - Kubernetes makes HA, scaling, and recovery straightforward with the right manifests.
  - Observability is critical for SRE—custom metrics and dashboards are invaluable.
  - NetworkPolicies and Secrets are essential for security in multi-service clusters.
- **Improvements:**
  - Add CI/CD pipeline for automated builds and deployments.
  - Integrate distributed tracing (Jaeger, OpenTelemetry).
  - Add backup/restore automation for DB and MinIO.
  - Expand alerting to cover more business-level SLOs.

---

## File Structure
```
services/           # All microservices (Node.js, Go, Python)
k8s/                # All Kubernetes manifests (YAMLs)
scripts/            # Build, deploy, test, and failure simulation scripts
docs/               # Architecture, diagrams, and extra docs
```

---

## Contact & Credits
- Assignment by: [Your Name]
- Architecture diagram: draw.io / Lucidchart
- All code, manifests, and docs are in this repo. 