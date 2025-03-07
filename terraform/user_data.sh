#!/bin/bash
set -ex

# 1. Docker
sudo apt-get update -y
sudo apt-get install -y docker.io
sudo systemctl start docker
# AWS CLI
sudo apt-get install -y awscli

# 2. K3s için Public IP ve ECR bilgilerini al
PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)
ECR_REGISTRY="952128764978.dkr.ecr.us-east-1.amazonaws.com" # ECR repo URL'niz
AWS_REGION="us-east-1"

# 3. K3s'i doğru parametrelerle kur
K3S_TOKEN=$(openssl rand -hex 12)
curl -sfL https://get.k3s.io | \
  INSTALL_K3S_EXEC="--docker \
  --tls-san $PUBLIC_IP \
  --node-external-ip $PUBLIC_IP \
  --bind-address 0.0.0.0 \
  --write-kubeconfig-mode 644 \
  --token $K3S_TOKEN" sh -

# 4. Kubeconfig'i düzenle ve SSM'e kaydet
sudo sed -i "s/server: .*/server: https:\/\/$PUBLIC_IP:6443/" /etc/rancher/k3s/k3s.yaml
sudo cat /etc/rancher/k3s/k3s.yaml | base64 -w0 | sudo aws ssm put-parameter \
  --name "/k3s/kubeconfig" \
  --type "SecureString" \
  --region "$AWS_REGION" \
  --value file:///dev/stdin \
  --overwrite

# 5. ECR Secret oluştur (Docker registry kimlik bilgileri)
ECR_PASSWORD=$(aws ecr get-login-password --region "$AWS_REGION")
sudo kubectl create secret docker-registry ecr-secret \
  --docker-server="$ECR_REGISTRY" \
  --docker-username=AWS \
  --docker-password="$ECR_PASSWORD" \
  --namespace=default


# 6. Kubeconfig'i base64 encode et ve SSM'e kaydet (satır sonu OLMADAN)
sudo cat /etc/rancher/k3s/k3s.yaml | base64 -w0 | sudo aws ssm put-parameter \
  --name "$SSM_PARAM_NAME" \
  --type "SecureString" \
  --value file:///dev/stdin \
  --region "$AWS_REGION" \
  --overwrite

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

# 9. Sertifika kontrolü
echo "Sertifika kontrol komutu:"
echo "sudo openssl x509 -in /var/lib/rancher/k3s/server/tls/server.crt -text -noout | grep 'X509v3 Subject Alternative Name'"