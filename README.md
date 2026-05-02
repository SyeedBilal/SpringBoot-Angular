#  Employee Management System — AWS EKS Deployment


A production-grade **3-tier Employee Management System** deployed on **Amazon EKS** with a custom Terraform-provisioned VPC, AWS Load Balancer Controller, Amazon RDS, and a full Prometheus + Grafana observability stack.

---

## 📋 Table of Contents

- [Architecture Overview](#architecture-overview)
- [Tech Stack](#tech-stack)
- [Project Structure](#project-structure)
- [Prerequisites](#prerequisites)
- [Deployment Guide](#deployment-guide)
  - [Phase 1 — Terraform VPC](#phase-1--terraform-vpc)
  - [Phase 2 — EKS Cluster with eksctl](#phase-2--eks-cluster-with-eksctl)
  - [Phase 3 — ALB Controller IAM (IRSA)](#phase-3--alb-controller-iam-irsa)
  - [Phase 4 — Install AWS Load Balancer Controller](#phase-4--install-aws-load-balancer-controller)
  - [Phase 5 — Deploy Application](#phase-5--deploy-application)
  - [Phase 6 — Monitoring Stack](#phase-6--monitoring-stack)
- [Kubernetes Manifests](#kubernetes-manifests)
- [Network & Security Design](#network--security-design)
- [Monitoring & Observability](#monitoring--observability)
- [Key Design Decisions](#key-design-decisions)
- [Verification & Testing](#verification--testing)
- [Known Issues & Improvements](#known-issues--improvements)

---

## Architecture Overview

```
                          ┌─────────────────────────────────────────────────────┐
                          │                  AWS VPC (10.0.0.0/16)              │
                          │                    ap-south-1                        │
  Internet                │                                                      │
  ───────                 │  ┌─────────────────────────────────────────────┐    │
  User/Browser ──────────────▶  PUBLIC SUBNETS (10.0.1.0/24, 10.0.2.0/24) │    │
                          │  │  ┌──────────────────┐   ┌───────────────┐  │    │
                          │  │  │   ALB (sg-alb)   │   │  NAT Gateway  │  │    │
                          │  │  │  port 80/443      │   │               │  │    │
                          │  │  └────────┬─────────┘   └───────────────┘  │    │
                          │  └──────────┼──────────────────────────────────┘    │
                          │             │                                        │
                          │  ┌──────────▼──────────────────────────────────┐    │
                          │  │  PRIVATE APP SUBNETS (10.0.10.0/24,         │    │
                          │  │                        10.0.11.0/24)         │    │
                          │  │                                               │    │
                          │  │  ┌──────────────────────────────────────┐   │    │
                          │  │  │   EKS Managed Node Group (sg-nodes)  │   │    │
                          │  │  │   ┌────────────┐  ┌───────────────┐  │   │    │
                          │  │  │   │  Node 1    │  │    Node 2     │  │   │    │
                          │  │  │   │ t3.medium  │  │  t3.medium    │  │   │    │
                          │  │  │   │ Frontend   │  │  Frontend     │  │   │    │
                          │  │  │   │ Backend    │  │  Backend      │  │   │    │
                          │  │  │   └────────────┘  └───────────────┘  │   │    │
                          │  │  │                                        │   │    │
                          │  │  │   Monitoring NS: Prometheus | Grafana  │   │    │
                          │  │  │   kube-system: ALB Controller          │   │    │
                          │  │  └───────────────────────┬────────────────┘   │    │
                          │  └────────────────────────── ┼ ──────────────────┘    │
                          │                              │                         │
                          │  ┌───────────────────────────▼──────────────────┐    │
                          │  │  PRIVATE DB SUBNETS (10.0.20.0/24,           │    │
                          │  │                       10.0.21.0/24)           │    │
                          │  │  ┌─────────────────────────────────────────┐  │    │
                          │  │  │  RDS MySQL 8.0  (sg-rds | port 3306)    │  │    │
                          │  │  └─────────────────────────────────────────┘  │    │
                          │  └──────────────────────────────────────────────┘    │
                          └─────────────────────────────────────────────────────┘
```

### Traffic Flow

```
User → IGW → ALB (sg-alb)
           ├── /api  → Backend Pods (port 8080)  → RDS MySQL (port 3306)
           └── /     → Frontend Pods (port 80)

DevOps → Grafana (port 3000) → Prometheus (port 9090)
                                     ├── node-exporter       (host metrics)
                                     ├── kube-state-metrics  (K8s object state)
                                     ├── cAdvisor            (container metrics)
                                     └── /actuator/prometheus (JVM + app metrics)
```

---

## Tech Stack

| Layer | Technology |
|---|---|
| **Frontend** | Angular (served via Nginx) |
| **Backend** | Spring Boot 3 (Java) |
| **Database** | Amazon RDS MySQL 8.0 |
| **Container Orchestration** | Amazon EKS 1.31 |
| **Infrastructure as Code** | Terraform |
| **Cluster Provisioning** | eksctl |
| **Load Balancer** | AWS ALB via AWS Load Balancer Controller |
| **Package Manager (K8s)** | Helm + Kustomize |
| **Monitoring** | Prometheus + Grafana (kube-prometheus-stack) |
| **Alerting** | Alertmanager |
| **Image Registry** | DockerHub |
| **Cloud Provider** | AWS (ap-south-1) |

---

## Project Structure

```
.
├── Terraform/
│   ├── main.tf                  # Root module — calls VPC module, RDS, SGs
│   ├── variables.tf
│   ├── outputs.tf               # Exports: vpc_id, subnet IDs, SG IDs
│   └── modules/
│       └── vpc/
│           ├── main.tf          # VPC, subnets, IGW, NAT GW, route tables
│           ├── variables.tf
│           └── outputs.tf
│
├── eksctl/
│   └── cluster-config.yaml      # EKS ClusterConfig — imports Terraform VPC
│
├── Kubernetes/
│   ├── kustomization.yaml       # Kustomize entry point (namespace: employee-app)
│   ├── ingress.yaml             # ALB Ingress — sg-alb annotation, routing rules
│   ├── frontend-deployment.yaml
│   ├── frontend-service.yaml    # ClusterIP, port 80
│   ├── backend-deployment.yaml
│   ├── backend-service.yaml     # ClusterIP, port 8080
│   ├── mysql-configmap.yaml     # RDS JDBC URL, Spring profile
│   ├── mysql-secret.yaml        # RDS credentials (base64)
│   ├── hpa.yaml                 # HPA for frontend + backend (CPU-based)
│   └── network-policy.yaml      # Allow ALB → pods on 80/8080
│
└── monitoring/
    └── values.yaml              # kube-prometheus-stack Helm values override
```

---

## Prerequisites

Make sure the following are installed and configured before starting:

| Tool | Version | Purpose |
|---|---|---|
| `aws cli` | v2+ | AWS API access |
| `terraform` | v1.5+ | VPC & RDS provisioning |
| `eksctl` | v0.180+ | EKS cluster creation |
| `kubectl` | v1.31+ | Kubernetes manifest deployment |
| `helm` | v3.14+ | ALB Controller + monitoring stack |
| `docker` | v24+ | Build & push images |

**AWS IAM permissions required:**
- `eks:*`, `ec2:*`, `iam:*`, `elasticloadbalancing:*`, `rds:*`, `cloudformation:*`

---

## Deployment Guide

### Phase 1 — Terraform VPC

Provision the entire network layer: VPC, subnets, security groups, NAT Gateway, IGW, and RDS.

```bash
cd Terraform/
terraform init
terraform plan
terraform apply
```

Save the outputs for use in later phases:

```bash
terraform output -json > ../tf-outputs.json
```

Key outputs you'll need:

| Output | Used In |
|---|---|
| `vpc_id` | eksctl cluster-config.yaml, Helm ALB install |
| `public_subnet_ids` | eksctl cluster-config.yaml |
| `app_subnet_ids` | eksctl cluster-config.yaml |
| `sg_alb_id` | Kubernetes ingress.yaml annotation |
| `sg_nodes_id` | eksctl cluster-config.yaml |

---

### Phase 2 — EKS Cluster with eksctl

Update `eksctl/cluster-config.yaml` with your actual VPC/subnet/SG IDs from Phase 1, then create the cluster:

```bash
eksctl create cluster -f eksctl/cluster-config.yaml
```

> ⏱️ This takes approximately 15–20 minutes.

**What eksctl creates:**
- EKS control plane inside your Terraform VPC
- Managed node group (2× t3.medium) in private app subnets
- OIDC provider (required for IRSA)
- Auto-updates `~/.kube/config`

Verify the cluster is ready:

```bash
kubectl get nodes -o wide
# Both nodes should show STATUS: Ready
```

#### eksctl ClusterConfig Reference

```yaml
apiVersion: eksctl.io/v1alpha5
kind: ClusterConfig
metadata:
  name: emp-management-eks
  region: ap-south-1
  version: "1.31"
vpc:
  id: "vpc-XXXXXXXXX"           # from terraform output
  cidr: "10.0.0.0/16"
  subnets:
    public:
      ap-south-1a:
        id: "subnet-XXXXX1"
      ap-south-1b:
        id: "subnet-XXXXX2"
    private:
      ap-south-1a:
        id: "subnet-XXXXX3"
      ap-south-1b:
        id: "subnet-XXXXX4"
  clusterEndpoints:
    publicAccess: true
    privateAccess: true
iam:
  withOIDC: true
managedNodeGroups:
  - name: app-nodes
    instanceType: t3.medium
    desiredCapacity: 2
    minSize: 1
    maxSize: 4
    privateNetworking: true
    securityGroups:
      attachIDs:
        - "sg-XXXXXXXXX"        # sg_nodes_id from terraform output
```

---

### Phase 3 — ALB Controller IAM (IRSA)

The AWS Load Balancer Controller needs AWS API permissions to create ALBs and manage security group rules. We use **IRSA** (IAM Roles for Service Accounts) — no static credentials stored anywhere.

#### Step 1: Download the IAM Policy

```bash
curl -o iam-policy.json \
  https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.11.0/docs/install/iam_policy.json
```

#### Step 2: Create the IAM Policy

```bash
aws iam create-policy \
  --policy-name AWSLoadBalancerControllerIAMPolicy \
  --policy-document file://iam-policy.json
```

#### Step 3: Create the IRSA (IAM Role + K8s ServiceAccount)

```bash
eksctl create iamserviceaccount \
  --cluster=emp-management-eks \
  --namespace=kube-system \
  --name=aws-load-balancer-controller \
  --role-name AmazonEKSLoadBalancerControllerRole \
  --attach-policy-arn=arn:aws:iam::<YOUR_ACCOUNT_ID>:policy/AWSLoadBalancerControllerIAMPolicy \
  --approve
```

This creates an IAM Role and annotates the Kubernetes ServiceAccount with the role ARN. Pods using this SA receive short-lived AWS credentials via OIDC token federation.

---

### Phase 4 — Install AWS Load Balancer Controller

```bash
helm repo add eks https://aws.github.io/eks-charts
helm repo update

helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=emp-management-eks \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set region=ap-south-1 \
  --set vpcId=<YOUR_VPC_ID>
```

Verify it's running:

```bash
kubectl get deployment -n kube-system aws-load-balancer-controller
# READY should show 2/2
```

---

### Phase 5 — Deploy Application

#### Step 1: Install Metrics Server (required for HPA)

```bash
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
```

#### Step 2: Update ConfigMap with your RDS endpoint

Edit `Kubernetes/mysql-configmap.yaml`:

```yaml
data:
  SPRING_DATASOURCE_URL: "jdbc:mysql://<YOUR_RDS_ENDPOINT>:3306/employee_db?useSSL=false&allowPublicKeyRetrieval=true&serverTimezone=UTC"
  MYSQL_DATABASE: "employee_db"
  SPRING_PROFILES_ACTIVE: "prod"
```

#### Step 3: Update Ingress with your sg-alb ID

Edit `Kubernetes/ingress.yaml`:

```yaml
annotations:
  alb.ingress.kubernetes.io/security-groups: "<YOUR_SG_ALB_ID>"
```

#### Step 4: Deploy everything

```bash
kubectl apply -k Kubernetes/
```

#### Step 5: Verify

```bash
kubectl get all -n employee-app
kubectl get ingress -n employee-app

# Wait ~2 minutes for ALB to provision, then:
ALB_DNS=$(kubectl get ingress -n employee-app \
  -o jsonpath='{.items[0].status.loadBalancer.ingress[0].hostname}')

echo "App URL: http://$ALB_DNS"
```

---

### Phase 6 — Monitoring Stack

Install the full **kube-prometheus-stack** (Prometheus + Grafana + Alertmanager + node-exporter + kube-state-metrics) via Helm:

```bash
kubectl create namespace monitoring

helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

helm install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  -n monitoring \
  -f monitoring/values.yaml
```

Verify all monitoring pods are running:

```bash
kubectl get pods -n monitoring
```

Access Grafana:

```bash
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80
# Open http://localhost:3000
# Default credentials: admin / prom-operator
```

#### Metrics Being Scraped

| Source | Metrics |
|---|---|
| **node-exporter** (DaemonSet) | CPU, memory, disk I/O, network per node |
| **kube-state-metrics** | Pod status, deployment replicas, HPA state |
| **cAdvisor** | Container CPU/memory/network per pod |
| **Spring Boot Actuator** `/actuator/prometheus` | JVM heap, GC, HTTP request duration, DB pool |

#### Grafana Dashboards

| Dashboard | ID |
|---|---|
| Kubernetes Cluster Overview | 7249 |
| Node Exporter Full | 1860 |
| Spring Boot Statistics | 12685 |
| Kubernetes HPA | 10257 |

---

## Kubernetes Manifests

### Ingress (ALB)

The Ingress is the critical piece that links your Terraform SG to the AWS ALB:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: employee-app-ingress
  namespace: employee-app
  annotations:
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
    alb.ingress.kubernetes.io/security-groups: "sg-XXXXXXXXX"   # Your Terraform sg-alb
    alb.ingress.kubernetes.io/manage-backend-security-group-rules: "true"
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80}]'
    alb.ingress.kubernetes.io/healthcheck-path: /
spec:
  ingressClassName: alb
  rules:
    - http:
        paths:
          - path: /api
            pathType: Prefix
            backend:
              service:
                name: backend-service
                port:
                  number: 8080
          - path: /
            pathType: Prefix
            backend:
              service:
                name: frontend-service
                port:
                  number: 80
```

> **Why `manage-backend-security-group-rules: true`?**
> This tells the ALB Controller to automatically add an inbound rule to `sg-nodes` allowing traffic from `sg-alb` on the target ports. Without it, ALB health checks and traffic will be blocked at the node SG.

### HPA Configuration

Both frontend and backend scale horizontally based on CPU utilization:

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: backend-hpa
  namespace: employee-app
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: backend-deployment
  minReplicas: 2
  maxReplicas: 6
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 70
```

---

## Network & Security Design

### Subnet Layout

| Tier | CIDR | Purpose | Subnet Tags |
|---|---|---|---|
| Public | `10.0.1.0/24`, `10.0.2.0/24` | ALB, NAT GW, IGW | `kubernetes.io/role/elb=1` |
| Private App | `10.0.10.0/24`, `10.0.11.0/24` | EKS Worker Nodes | `kubernetes.io/role/internal-elb=1` |
| Private DB | `10.0.20.0/24`, `10.0.21.0/24` | RDS MySQL | — |

All subnets are tagged with `kubernetes.io/cluster/emp-management-eks=shared` so the ALB Controller can discover them.

### Security Group Chain

```
Internet (0.0.0.0/0)
    │
    ▼  port 80/443
┌─────────┐
│  sg-alb │  ← Attached to ALB via Ingress annotation
└────┬────┘
     │  auto-managed inbound rule (manage-backend-security-group-rules: true)
     ▼
┌──────────┐
│ sg-nodes │  ← Attached to EKS node group via eksctl securityGroups.attachIDs
└────┬─────┘
     │  port 3306
     ▼
┌────────┐
│ sg-rds │  ← Attached to RDS instance (Terraform-managed)
└────────┘
```

### How the ALB SG Linkage Works

> This is the most commonly misunderstood part of this setup.

By default, the AWS Load Balancer Controller **creates its own security group** for each ALB — your Terraform `sg-alb` is ignored. To use your own SG:

1. Pass the SG ID via annotation: `alb.ingress.kubernetes.io/security-groups: "sg-xxxx"`
2. Enable backend rule management: `alb.ingress.kubernetes.io/manage-backend-security-group-rules: "true"`

The controller will then attach your `sg-alb` to the ALB and automatically add the corresponding inbound rule to `sg-nodes`, allowing the ALB to reach your pods.

---

## Monitoring & Observability

### Stack Components

```
monitoring namespace
├── Prometheus          — metrics collection & storage (TSDB)
├── Alertmanager        — alert routing & notifications
├── Grafana             — dashboards & visualization
├── node-exporter       — DaemonSet: host-level metrics per node
└── kube-state-metrics  — K8s object state metrics
```

### Spring Boot Actuator Integration

Add to your `backend-deployment.yaml` to enable Prometheus scraping:

```yaml
# Annotations on the pod template
annotations:
  prometheus.io/scrape: "true"
  prometheus.io/port: "8080"
  prometheus.io/path: "/actuator/prometheus"
```

And in your Spring Boot `application.properties`:

```properties
management.endpoints.web.exposure.include=health,prometheus,metrics
management.endpoint.prometheus.enabled=true
```

### Alert Rules

Key alerts configured in Alertmanager:

| Alert | Condition | Severity |
|---|---|---|
| PodCrashLooping | Pod restarting > 5 times in 10 min | Critical |
| HighCPUUsage | Node CPU > 85% for 5 min | Warning |
| HighMemoryUsage | Node memory > 90% for 5 min | Warning |
| DeploymentReplicasMismatch | Available replicas < desired | Critical |
| RDSConnectionFailure | Backend DB connection errors | Critical |

---

## Key Design Decisions

### IRSA over Node IAM Roles
Each pod gets least-privilege AWS credentials scoped to its ServiceAccount via OIDC token federation. No EC2 instance profile credentials are shared across all pods.

### Terraform sg-alb via Ingress Annotation
Rather than letting the ALB Controller auto-create a throwaway SG, the Terraform-managed `sg-alb` is passed via annotation. This keeps all SG lifecycle management in Terraform (IaC), making security rules auditable and reproducible.

### `target-type: ip` (Direct Pod Routing)
Pods are registered in the ALB Target Group directly by their VPC IP, bypassing NodePort overhead. This reduces one network hop and works natively with the AWS VPC CNI plugin.

### RDS over In-Cluster MySQL
Removes the need for stateful PVCs and StatefulSets in Kubernetes. RDS provides automated backups, point-in-time recovery, and Multi-AZ failover with zero application code changes.

### Kustomize for Manifest Management
All resources are deployed as a single `kubectl apply -k Kubernetes/` with correct namespace scoping, resource ordering, and no template duplication.

### kube-prometheus-stack (All-in-One Helm Chart)
A single Helm release installs Prometheus, Grafana, Alertmanager, node-exporter, and kube-state-metrics with pre-wired integrations — no manual scrape config or datasource setup needed.

---

## Verification & Testing

### Cluster Health

```bash
# Node status
kubectl get nodes -o wide

# All system pods healthy
kubectl get pods -n kube-system
kubectl get pods -n monitoring

# ALB Controller logs
kubectl logs -n kube-system \
  deployment/aws-load-balancer-controller --tail=50
```

### Application Health

```bash
# All app pods running
kubectl get pods -n employee-app

# Ingress has an ALB DNS address
kubectl get ingress -n employee-app

# End-to-end test
ALB_DNS=$(kubectl get ingress -n employee-app \
  -o jsonpath='{.items[0].status.loadBalancer.ingress[0].hostname}')

curl -s -o /dev/null -w "%{http_code}" http://$ALB_DNS/          # Expect 200
curl -s -o /dev/null -w "%{http_code}" http://$ALB_DNS/api/employees  # Expect 200
```

### ALB Security Group Verification

```bash
# Get the ALB ARN
ALB_ARN=$(aws elbv2 describe-load-balancers \
  --query "LoadBalancers[?contains(DNSName, 'employee')].LoadBalancerArn" \
  --output text)

# Verify sg-alb is attached (not an auto-created SG)
aws elbv2 describe-load-balancers \
  --load-balancer-arns $ALB_ARN \
  --query "LoadBalancers[0].SecurityGroups"
```

### HPA Status

```bash
kubectl get hpa -n employee-app
# MINPODS / MAXPODS / REPLICAS should all be populated
```

### Monitoring Stack

```bash
# Port-forward to Prometheus UI
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090

# Port-forward to Grafana
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80
```

---

## Known Issues & Improvements

### What I'd Change in Production

- [ ] **ECR over DockerHub** — Private image registry with IAM-based pull auth and vulnerability scanning
- [ ] **HTTPS from day one** — ACM certificate + Route 53 alias record + SSL redirect on Ingress
- [ ] **Split Terraform state** — Separate state files for VPC, EKS, and app layers to reduce blast radius
- [ ] **Secrets Manager / External Secrets Operator** — Instead of base64 K8s Secrets for RDS credentials
- [ ] **RDS Multi-AZ** — Enable for production HA (currently single-AZ for cost)
- [ ] **Terraform remote state** — S3 backend + DynamoDB lock instead of local state
- [ ] **CI/CD pipeline** — GitHub Actions for `terraform plan` on PR + `kubectl apply` on merge
- [ ] **Pod Disruption Budgets** — Ensure availability during node upgrades
- [ ] **Resource limits** — Set CPU/memory limits on all containers (not just requests)
- [ ] **Liveness/Readiness probes** — Fine-tune Spring Boot startup/health probe timing

---

## Cleanup

To tear down all resources and avoid ongoing AWS charges:

```bash
# 1. Remove K8s resources (this triggers ALB deletion via the controller)
kubectl delete -k Kubernetes/
kubectl delete namespace monitoring

# 2. Wait for ALB to be fully deleted before destroying VPC
sleep 60

# 3. Uninstall Helm releases
helm uninstall aws-load-balancer-controller -n kube-system
helm uninstall kube-prometheus-stack -n monitoring

# 4. Delete EKS cluster (nodes, node group, OIDC provider)
eksctl delete cluster --name emp-management-eks --region ap-south-1

# 5. Destroy Terraform-managed resources (VPC, RDS, SGs)
cd Terraform/
terraform destroy
```

> ⚠️ Always delete K8s resources **before** running `terraform destroy`. The ALB Controller creates AWS resources (ALB, Target Groups, SG rules) that Terraform doesn't know about — if you destroy the VPC first, those resources become orphaned and will block VPC deletion.

---

## License

This project is open source and available under the [MIT License](LICENSE).

---

<div align="center">
  <strong>Built with ☕ and a lot of kubectl describe</strong><br/>
  AWS EKS • Terraform • Kubernetes 1.31 • ap-south-1
</div>
