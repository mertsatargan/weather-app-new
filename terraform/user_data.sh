#!/bin/bash
set -ex

# 1. Docker
sudo apt-get update -y
sudo apt-get install -y docker.io
sudo systemctl start docker

# 2. AWS CLI
sudo apt-get install -y awscli

# 3. k3s
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--docker" sh -
sudo chmod 644 /etc/rancher/k3s/k3s.yaml
sudo ln -sf /usr/local/bin/k3s /usr/local/bin/kubectl

# 4. ECR Secret
ECR_TOKEN=$(aws ecr get-login-password --region us-east-1)
sudo kubectl create secret docker-registry ecr-secret \
  --docker-server=952128764978.dkr.ecr.us-east-1.amazonaws.com \
  --docker-username=AWS \
  --docker-password=$ECR_TOKEN \
  --namespace=default


# EC2'a kubeconfig'i SSM'e kaydetmesi için komut ekleyin (user_data.sh)
echo "${base64encode(file("/etc/rancher/k3s/k3s.yaml"))}" | aws ssm put-parameter --name "/k3s/kubeconfig" --type SecureString --value file:///dev/stdin --region us-east-1 --overwrite

# Helm'i kur
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
chmod 700 get_helm.sh && ./get_helm.sh

# Monitoring Namespace oluştur
kubectl create namespace monitoring

# Prometheus & Grafana'yı Helm ile kur
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

helm install prometheus prometheus-community/prometheus -n monitoring
helm install grafana grafana/grafana -n monitoring

# Argo CD'yi kur
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Kubeconfig'i SSM'e kaydet (Terraform için)
sudo apt-get install -y awscli
aws ssm put-parameter --name "/k3s/kubeconfig" --type "SecureString" --value "$(sudo cat /etc/rancher/k3s/k3s.yaml | base64)" --region us-east-1 --overwrite