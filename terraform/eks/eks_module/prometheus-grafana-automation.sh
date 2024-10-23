#!/bin/bash

# Ensure the script is run as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 
   exit 1
fi

# Add Helm repositories
echo "Adding Helm repositories..."
helm repo add stable https://charts.helm.sh/stable
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts

# Update Helm repositories
echo "Updating Helm repositories..."
helm repo update

# Search for available Prometheus charts
echo "Searching for Prometheus charts..."
helm search repo prometheus-community
##44
# Create a namespace for Prometheus
echo "Creating namespace for Prometheus..."
kubectl create namespace prometheus

# Install Prometheus and Grafana using Helm
echo "Installing Prometheus and Grafana..."
helm install prometheus prometheus-community/kube-prometheus-stack -n prometheus

# Wait for pods to be running
echo "Waiting for Prometheus and Grafana pods to be running..."
kubectl wait --for=condition=ready pod -l "app.kubernetes.io/instance=prometheus" -n prometheus --timeout=5m

# Get the list of pods and services
echo "Listing pods and services..."
kubectl get pods -n prometheus
kubectl get svc -n prometheus

# Edit Prometheus Service to use LoadBalancer
echo "Modifying Prometheus Service to use LoadBalancer..."
kubectl patch svc prometheus-kube-prometheus-prometheus -n prometheus -p '{"spec": {"type": "LoadBalancer"}}'

# Edit Grafana Service to use LoadBalancer
echo "Modifying Grafana Service to use LoadBalancer..."
kubectl patch svc prometheus-grafana -n prometheus -p '{"spec": {"type": "LoadBalancer"}}'

# Get the updated services
echo "Getting updated services..."
kubectl get svc -n prometheus

echo "Prometheus and Grafana installation and configuration complete."
echo "You may need to configure your firewall or security groups to allow external access if using LoadBalancer."




# #!/bin/bash

# # Add Helm repositories
# helm repo add stable https://charts.helm.sh/stable
# helm repo add prometheus-community https://prometheus-community.github.io/helm-charts

# # Update Helm repositories
# helm repo update

# # Search for available Prometheus charts
# helm search repo prometheus-community

# # Create a namespace for Prometheus
# kubectl create namespace prometheus

# # Install Prometheus and Grafana using Helm
# helm install prometheus prometheus-community/kube-prometheus-stack -n prometheus

# # Wait for pods to be running
# echo "Waiting for Prometheus and Grafana pods to be running..."
# kubectl wait --for=condition=ready pod -l "app.kubernetes.io/instance=prometheus" -n prometheus --timeout=5m

# # Get the list of pods and services
# kubectl get pods -n prometheus
# kubectl get svc -n prometheus

# # Inform the user about accessing Prometheus and Grafana services
# echo "To access Prometheus and Grafana services outside the cluster, you need to update the service type."

# # Edit Prometheus Service to use LoadBalancer or NodePort
# kubectl edit svc prometheus-kube-prometheus-prometheus -n prometheus

# # Edit Grafana Service to use LoadBalancer or NodePort
# kubectl edit svc prometheus-grafana -n prometheus

# # Get the updated services
# kubectl get svc -n prometheus

# echo "Prometheus and Grafana installation and configuration complete."
# echo "You may need to configure your firewall or security groups to allow external access if using LoadBalancer."
