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

# 4. Uygulamayı Deploy Et
sudo kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: weather-app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: weather-app
  template:
    metadata:
      labels:
        app: weather-app
    spec:
      containers:
      - name: weather-app
        image: 952128764978.dkr.ecr.us-east-1.amazonaws.com/weather-app:latest
        ports:
          - containerPort: 80
      imagePullSecrets:
      - name: ecr-secret
---
apiVersion: v1
kind: Service
metadata:
  name: weather-app-service
spec:
  type: NodePort  
  selector:
    app: weather-app
  ports:
    - protocol: TCP
      port: 80
      targetPort: 80
      nodePort: 30000
EOF

