#!/bin/bash
set -ex

# 1. Docker
sudo apt-get update -y
sudo apt-get install -y docker.io
sudo systemctl start docker
# AWS CLI
sudo apt-get install -y awscli

# 2. K3s için Public IP ve ECR bilgilerini al
TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 30")
PUBLIC_IP=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" -s http://169.254.169.254/latest/meta-data/public-ipv4)
ECR_REGISTRY="952128764978.dkr.ecr.us-east-1.amazonaws.com"
AWS_REGION="us-east-1"

# 3. K3s'i doğru parametrelerle kur
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--docker --tls-san $PUBLIC_IP --node-external-ip $PUBLIC_IP --bind-address 0.0.0.0 --advertise-address $PUBLIC_IP --write-kubeconfig-mode 644" sh -

# 3. Kubeconfig'i Dinamik Olarak Düzelt (Sed Magic!)
sudo bash -c "until [ -f /etc/rancher/k3s/k3s.yaml ]; do sleep 2; echo 'Waiting for k3s.yaml...'; done"
sudo sed -i "s|server: https://127.0.0.1:6443|server: https://$PUBLIC_IP:6443|g" /etc/rancher/k3s/k3s.yaml

# 4. Kubeconfig'i SSM'e Kaydet (Base64 without newlines)
sudo bash -c "cat /etc/rancher/k3s/k3s.yaml | base64 -w0 | aws ssm put-parameter --name '/k3s/kubeconfig' --type 'SecureString' --region $AWS_REGION --value file:///dev/stdin --overwrite"

# 5. ECR Secret oluştur (Docker registry kimlik bilgileri)
ECR_PASSWORD=$(aws ecr get-login-password --region "$AWS_REGION")
sudo kubectl create secret docker-registry ecr-secret \
  --docker-server="$ECR_REGISTRY" \
  --docker-username=AWS \
  --docker-password="$ECR_PASSWORD" \
  --namespace=default

# Helm'i kur
curl https://baltocdn.com/helm/signing.asc | gpg --dearmor | sudo tee /usr/share/keyrings/helm.gpg > /dev/null
sudo apt-get install apt-transport-https --yes
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
sudo apt-get update
sudo apt-get install helm

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
