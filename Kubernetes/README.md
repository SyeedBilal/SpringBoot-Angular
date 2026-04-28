# Kubernetes Deployment Guide

## Architecture

```
┌─────────────┐     ┌─────────────────┐     ┌──────────────┐     ┌─────────┐
│   Internet   │────▶│  Ingress (nginx) │────▶│   Frontend   │────▶│ Backend │────▶│  MySQL  │
└─────────────┘     └─────────────────┘     │  (Angular +  │     │ (Spring │     │  (8.0)  │
                                             │   Nginx:80)  │     │ Boot    │     │         │
                                             └──────────────┘     │  :8080) │     └─────────┘
                                                                  └─────────┘
```

## Prerequisites

- Kubernetes cluster (v1.25+)
- `kubectl` configured to target the cluster
- Docker images built and pushed to a container registry
- [NGINX Ingress Controller](https://kubernetes.github.io/ingress-nginx/deploy/) installed
- [Metrics Server](https://github.com/kubernetes-sigs/metrics-server) installed (for HPA)

## Manifest Files

| File | Description |
|------|-------------|
| `namespace.yaml` | Dedicated `employee-app` namespace |
| `mysql-secret.yaml` | Credentials for MySQL and Spring Boot |
| `mysql-configmap.yaml` | Non-sensitive DB and Spring Boot config |
| `mysql-pvc.yaml` | 5Gi PersistentVolumeClaim for MySQL data |
| `mysql-deployment.yaml` | MySQL 8.0 Deployment with health checks |
| `mysql-service.yaml` | ClusterIP Service for MySQL |
| `backend-deployment.yaml` | Spring Boot backend (2 replicas) |
| `backend-service.yaml` | ClusterIP Service for backend |
| `frontend-nginx-configmap.yaml` | Nginx config adapted for K8s service discovery |
| `frontend-deployment.yaml` | Angular frontend (2 replicas) |
| `frontend-service.yaml` | ClusterIP Service for frontend |
| `ingress.yml` | Ingress routing: `/api` → backend, `/` → frontend |
| `hpa.yaml` | HorizontalPodAutoscaler for backend & frontend |
| `network-policy.yaml` | NetworkPolicies for least-privilege access |
| `kustomization.yaml` | Kustomize orchestration file |

## Quick Start

### 1. Build & Push Docker Images

```bash
# Backend
docker build -t <your-registry>/myapp-backend:latest ./emp_backend
docker push <your-registry>/myapp-backend:latest

# Frontend
docker build -t <your-registry>/myapp-frontend:latest ./employee-frontend-final
docker push <your-registry>/myapp-frontend:latest
```

### 2. Update Image References

Edit `backend-deployment.yaml` and `frontend-deployment.yaml` — replace `myapp/backend:latest` and `myapp/frontend:latest` with your registry paths.

### 3. Update Ingress Host

Edit `ingress.yml` — replace `employee-app.example.com` with your actual domain or IP.

### 4. Update Secrets (Optional)

If you need different credentials, regenerate base64 values:

```bash
echo -n 'your-password' | base64
```

Update the values in `mysql-secret.yaml`.

### 5. Deploy

```bash
# Option A: Using Kustomize (recommended)
kubectl apply -k Kubernetes/

# Option B: Apply manifests individually (in order)
kubectl apply -f Kubernetes/namespace.yaml
kubectl apply -f Kubernetes/mysql-secret.yaml
kubectl apply -f Kubernetes/mysql-configmap.yaml
kubectl apply -f Kubernetes/frontend-nginx-configmap.yaml
kubectl apply -f Kubernetes/mysql-pvc.yaml
kubectl apply -f Kubernetes/mysql-deployment.yaml
kubectl apply -f Kubernetes/mysql-service.yaml
kubectl apply -f Kubernetes/backend-deployment.yaml
kubectl apply -f Kubernetes/backend-service.yaml
kubectl apply -f Kubernetes/frontend-deployment.yaml
kubectl apply -f Kubernetes/frontend-service.yaml
kubectl apply -f Kubernetes/ingress.yml
kubectl apply -f Kubernetes/hpa.yaml
kubectl apply -f Kubernetes/network-policy.yaml
```

### 6. Verify Deployment

```bash
# Check all resources in the namespace
kubectl get all -n employee-app

# Watch pods come up
kubectl get pods -n employee-app -w

# Check logs
kubectl logs -n employee-app -l app=backend --tail=50
kubectl logs -n employee-app -l app=frontend --tail=50
kubectl logs -n employee-app -l app=mysql --tail=50

# Check ingress
kubectl get ingress -n employee-app
```

## Tear Down

```bash
kubectl delete -k Kubernetes/
# or
kubectl delete namespace employee-app
```

## Production Checklist

- [ ] Replace image tags with your container registry paths
- [ ] Replace `employee-app.example.com` in `ingress.yml` with your domain
- [ ] Use [Sealed Secrets](https://github.com/bitnami-labs/sealed-secrets) or [External Secrets](https://external-secrets.io/) instead of plain K8s Secrets
- [ ] Enable TLS in `ingress.yml` (uncomment TLS section + cert-manager annotation)
- [ ] Adjust resource requests/limits based on load testing
- [ ] Configure a proper StorageClass in `mysql-pvc.yaml` if not using the default
- [ ] Set up monitoring (Prometheus + Grafana) and log aggregation (EFK/Loki)
