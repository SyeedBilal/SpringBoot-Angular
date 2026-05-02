# EKS Monitoring & Logging Implementation Plan

This plan outlines how to monitor your entire EKS cluster, your specific application components, and how to effectively manage and view logs.

## 1. Application-Level Metrics (Spring Boot)

To monitor your Spring Boot backend with Prometheus, it needs to generate metrics in a format Prometheus understands.

### Proposed Changes:
#### [MODIFY] `emp_backend/pom.xml`
- Add the `micrometer-registry-prometheus` dependency so Spring Boot can export Prometheus metrics.

#### [MODIFY] `kubernetes-all-in-one.yaml`
- Update the `backend` Deployment to inject the environment variable `MANAGEMENT_ENDPOINTS_WEB_EXPOSURE_INCLUDE=health,prometheus,metrics` so the `/actuator/prometheus` endpoint is enabled.
- Re-build the Spring Boot Docker image and update the cluster.

---

## 2. Cluster-Level Monitoring (Prometheus & Grafana)

We will install the industry-standard **Kube-Prometheus-Stack** via Helm. This is an all-in-one package that deploys:
1. **Prometheus**: To scrape and store metrics.
2. **Grafana**: For visual dashboards.
3. **Kube-State-Metrics**: To monitor cluster health (Pod restarts, deployment statuses).
4. **Node Exporter**: To monitor EC2 node health (CPU, Memory, Disk usage).

### Installation Steps:
```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

helm install monitoring prometheus-community/kube-prometheus-stack \
  --namespace monitoring --create-namespace \
  --set grafana.adminPassword=admin
```

### [NEW] `Kubernetes/backend-servicemonitor.yaml`
- Create a `ServiceMonitor` Custom Resource. This tells Prometheus to automatically discover your `backend-service` and scrape the `/actuator/prometheus` endpoint every 15 seconds.

---

## 3. Viewing Logs

### Basic Logging (Ad-Hoc)
For immediate, real-time debugging, you can use native Kubernetes commands:
```bash
# View backend logs
kubectl logs -l app=backend -n employee-app -f

# View frontend (Nginx) logs
kubectl logs -l app=frontend -n employee-app -f
```

### Centralized Logging (AWS CloudWatch Container Insights)
Instead of manually checking individual pods (which disappear if a pod crashes or restarts), we will set up **Fluent Bit** to automatically ship all your container logs to AWS CloudWatch Logs.

### Installation Steps:
We will install the AWS CloudWatch Observability Add-on for EKS, which automatically sets up Fluent Bit.
```bash
aws eks create-addon \
  --cluster-name emp-management-eks \
  --addon-name amazon-cloudwatch-observability
```
*Note: Your EKS Node IAM Role will need the `CloudWatchAgentServerPolicy` attached to allow it to push logs.*

---

## Verification Plan

### Automated/Manual Verification
1. Verify the `monitoring` namespace is up: `kubectl get pods -n monitoring`
2. Access Grafana locally: `kubectl port-forward svc/monitoring-grafana 8080:80 -n monitoring` and verify that metrics are flowing in.
3. Open the AWS Console -> CloudWatch -> Log Groups -> `/aws/containerinsights/emp-management-eks/application` and verify that Spring Boot and Nginx logs are visible.

> [!IMPORTANT]
> **User Review Required**
> 1. Do you approve me updating your backend `pom.xml` and `kubernetes-all-in-one.yaml` to expose Prometheus metrics?
> 2. Would you like me to run the Helm commands to install Prometheus and Grafana on your cluster right now? (Your `kubectl` is currently pointing to a disconnected local context, so I will need you to update your kubeconfig first).
