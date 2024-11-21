#!/bin/bash

# Define the AWS Region where your EKS cluster is located
REGION="us-east-2"  # Change to your region if necessary

# Get the AWS account ID dynamically
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)

# Get the EKS cluster name dynamically (assuming you're getting the first cluster in your account)
CLUSTER_NAME=$(aws eks list-clusters --region $REGION --query "clusters[0]" --output text)

# Retrieve IAM role dynamically using the role name pattern 'AWS-EC2-Administrator-Role'
IAM_ROLE=$(aws iam list-roles --query "Roles[?RoleName=='AWS-EC2-Administrator-Role'].RoleName" --output text)

# Check if IAM Role was found
if [ -z "$IAM_ROLE" ]; then
    echo "Error: IAM role 'AWS-EC2-Administrator-Role' not found in your account."
    exit 1
fi

# Ensure aws-iam-authenticator is installed (skip if already installed)
if ! command -v aws-iam-authenticator &>/dev/null; then
    echo "aws-iam-authenticator not found, installing..."
    curl -Lo aws-iam-authenticator https://github.com/kubernetes-sigs/aws-iam-authenticator/releases/download/v0.5.9/aws-iam-authenticator-linux-amd64
    chmod +x aws-iam-authenticator
    sudo mv aws-iam-authenticator /usr/local/bin/
else
    echo "aws-iam-authenticator is already installed"
fi

# Update kubeconfig for accessing the EKS cluster using IAM
echo "Updating kubeconfig for EKS access..."
aws eks --region $REGION update-kubeconfig --name $CLUSTER_NAME

# Add IAM Role to aws-auth ConfigMap for Kubernetes access
echo "Adding IAM role $IAM_ROLE to aws-auth ConfigMap..."
kubectl apply -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: aws-auth
  namespace: kube-system
data:
  mapRoles: |
    - rolearn: arn:aws:iam::$AWS_ACCOUNT_ID:role/$IAM_ROLE
      username: jenkins
      groups:
        - system:masters
EOF

# Verify kubectl access to EKS cluster
kubectl get nodes

echo "Jenkins server is now configured to interact with the EKS cluster using IAM authentication."
