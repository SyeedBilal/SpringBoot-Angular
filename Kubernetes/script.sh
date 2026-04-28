#bin/bash
NAMESPACE=employee-app

echo Checking if namespace exists...
if kubectl get namespace  &> /dev/null; then
    echo Namespace found. Current status:
    kubectl get namespace 
    
    echo Removing all resources in namespace ...
    kubectl delete all --all -n  --force --grace-period=0
    
    echo Removing the namespace...
    kubectl delete namespace  --force --grace-period=0
    
    echo Waiting for namespace to be removed...
    sleep 5
    
    # Force remove if still terminating
    if kubectl get namespace  &> /dev/null; then
        echo Namespace still terminating, forcing removal...
        kubectl get namespace  -o json |             jq '.spec.finalizers = []' |             kubectl replace --raw /api/v1/namespaces//finalize -f -
    fi
fi

echo Recreating namespace ...
kubectl create namespace 

echo Applying Kubernetes resources...
kubectl apply -k Kubernetes/

echo Done! Checking status...
kubectl get all -n 
