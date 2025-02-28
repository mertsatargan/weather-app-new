provider "aws" {
  region  = var.aws_region
  profile = "devops-user"
}

resource "aws_key_pair" "weather_app_key" {
  key_name   = "weather-app-key"
  public_key = file("~/.ssh/weather-app-key.pub")
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"] # hvm-ssd önemli
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"] # EBS tabanlı AMI'ler
  }
}
# main.tf
resource "aws_instance" "k3s_master" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  key_name               = aws_key_pair.weather_app_key.key_name
  vpc_security_group_ids = [aws_security_group.k3s_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.ecr_profile.name

  user_data = file("${path.module}/user_data.sh")

  tags = {
    Name = "k3s-master"
  }
}

resource "aws_security_group" "k3s_sg" {
  name = "k3s-sg"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 30000 # NodePort 
    to_port     = 30000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 3000 # Grafana
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 9090 # Prometheus
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8080 # Argo CD
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_ecr_repository" "weather_app" {
  name         = "weather-app"
  force_delete = true

}
resource "aws_iam_role" "ecr_access" {
  name = "ecr-access-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecr_policy" {
  role       = aws_iam_role.ecr_access.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_instance_profile" "ecr_profile" {
  name = "ecr-profile"
  role = aws_iam_role.ecr_access.name
}

# SSM icin IAM rolu

resource "aws_iam_role_policy" "ssm_policy" {
  name = "ssm-policy"
  role = aws_iam_role.ecr_access.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Action = [
        "ssm:PutParameter",
        "ssm:GetParameter"
      ],
      Resource = "*"
    }]
  })
}