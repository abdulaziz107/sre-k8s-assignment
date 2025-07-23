
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

### **Option 1: Complete Automated Deployment**
```sh
# Clone the repo
git clone https://github.com/abdulaziz107/sre-k8s-assignment.git
cd sre-k8s-assignment

# Start Minikube
minikube start

# Run complete deployment (builds, pushes, deploys, tests)
# Make sure you're in the project root directory
bash scripts/deploy.sh
```

### **Option 2: Step-by-Step Deployment**
1. **Clone the repo:**
   ```sh
    git clone https://github.com/abdulaziz107/sre-k8s-assignment.git
    cd sre-k8s-assignment
    ```
2. **Start Minikube:**
   ```sh
    minikube start
    ```
3. **Build & Push Images:**
   ```sh
    # Standard build (single architecture)
    ./scripts/build-and-push.sh

    # Multi-architecture build (linux/amd64, linux/arm64)
    ./scripts/build-multiarch.sh
    ```
4. **Deploy to Kubernetes:**
   ```sh
    bash scripts/deploy.sh
    ```
5. **Setup External Notifications (Optional):**
   ```sh
        bash scripts/setup-notifications.sh
   ```
   - Configure Slack, Email, and PagerDuty integrations
   - Follow the interactive prompts to set up webhooks and credentials
6. **Access Services:**
   - API: `kubectl port-forward svc/api-service 8080:80 -n api`
   - Auth: `kubectl port-forward svc/auth-service 3001:80 -n auth`
   - Image: `kubectl port-forward svc/image-storage-service 3003:80 -n image-storage`
7. **Access Monitoring:**
   - Grafana: `kubectl port-forward svc/monitoring-grafana 3000:80 -n monitoring`
   - Prometheus: `kubectl port-forward svc/monitoring-kube-prometheus-prometheus 9090:9090 -n monitoring`
   - Alertmanager: `kubectl port-forward svc/monitoring-kube-prometheus-alertmanager 9093:9093 -n monitoring`
   - Grafana login: `admin/prom-operator`

---

## Features & SRE Goals
- **Isolation:** Namespaces, NetworkPolicies, and Secrets for all services.
- **Containerization:** Multi-stage Dockerfiles, non-root users, resource limits.
- **Multi-Architecture:** Support for linux/amd64 and linux/arm64 platforms.
- **Deployment:** Separate YAMLs for Deployments, Services, Ingress, HPA, PDB, etc.
- **Security:** TLS via Ingress, network-level isolation, secrets management.
- **Observability:** Prometheus metrics, Grafana dashboards, Alertmanager rules.
- **Scalability:** HPA for all services, resource requests/limits, PDBs.
- **Disaster Recovery:** Failure simulation scripts, auto-rescheduling, logs/events.

---

## Failure Simulation & Recovery
- **Run:** `bash scripts/failure-simulation.sh`
- Simulates 7 comprehensive failure scenarios:
  1. **Database Crash** - PostgreSQL pod deletion and recovery
  2. **Service Crash** - Auth service pod deletion and recovery
  3. **High Traffic** - HPA scaling demonstration
  4. **Node Failure** - Node cordoning and pod rescheduling
  5. **Resource Exhaustion** - CPU stress testing
  6. **Service Connectivity** - Network policy verification
  7. **Monitoring Verification** - Prometheus, Grafana, Alertmanager testing
- **Video recording:** The script provides comprehensive output for video documentation
- **Real-time monitoring:** Shows alerts, events, and recovery status

## Bilingual Support (Arabic/English)
- **Test:** `bash scripts/test-bilingual.sh`
- All services support both Arabic and English languages
- Language is determined by `Accept-Language` header
- Includes localized error messages, success messages, and health checks

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

> **Note on Secret Management:**
> For production environments, it is highly recommended to use an external secret manager such as [HashiCorp Vault](https://www.vaultproject.io/), [AWS Secrets Manager](https://aws.amazon.com/secrets-manager/), or [Azure Key Vault](https://azure.microsoft.com/en-us/products/key-vault/) instead of Kubernetes Secrets. These tools provide advanced encryption, access control, audit logging, and secret rotation. Integration with Kubernetes can be achieved via CSI drivers or dedicated operators.

---

## Summary Table

| Area                | Current State         | Best Practice / Missing                |
|---------------------|----------------------|----------------------------------------|
| Namespaces          | Used                 | ✅                                     |
| NetworkPolicy       | Used                 | ✅                                     |
| Secrets             | K8s Secrets          | Use Vault/Secrets Manager              |
| TLS                 | Ingress w/ TLS       | ✅                                     |
| RBAC                | Not defined          | Add RBAC per namespace                 |
| Pod Security        | Non-root             | Enforce PodSecurityAdmission           |
| Image Security      | Multi-stage, non-root| Add image scanning in CI/CD            |
| Audit Logging       | Not mentioned        | Enable K8s & app audit logs            |
| Backups             | Not automated        | Add backup/restore for DB & MinIO      |
| Tracing             | Not present          | Add Jaeger/OpenTelemetry               |
| Ingress Security    | TLS only             | Add WAF/rate limiting if public        |
| Resource Quotas     | Per-pod only         | Add namespace quotas                   |
| CI/CD               | Manual scripts       | Use GitHub Actions or similar          |

---

## File Structure
```
services/           # All microservices (Node.js, Go, Python)
k8s/                # All Kubernetes manifests (YAMLs)
scripts/            # Deployment and testing scripts
├── deploy.sh              # Complete deployment script
├── failure-simulation.sh  # Comprehensive failure simulation
├── build-and-push.sh      # Docker image build and push
├── setup-notifications.sh # External notification setup
├── test-bilingual.sh      # Bilingual functionality testing
└── check-ingress.sh       # Ingress verification
docs/               # Architecture, diagrams, and extra docs
```

---

## Contact & Credits
- Assignment by: Abdulaziz Alrouji
- Architecture diagram: draw.io / Lucidchart
- repo: https://github.com/abdulaziz107/sre-k8s-assignment.git
