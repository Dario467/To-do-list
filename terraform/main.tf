terraform {
  required_version = ">= 1.5"

  required_providers {
    aws    = { source = "hashicorp/aws", version = "~> 5.0" }
    random = { source = "hashicorp/random", version = "~> 3.0" }
    tls    = { source = "hashicorp/tls", version = "~> 4.0" }
    local  = { source = "hashicorp/local", version = "~> 2.0" }
  }

  backend "s3" {
    bucket = "tfstate-todolist-dario-2026"
    key    = "todo-list/terraform.tfstate"
    region = "us-east-1"
  }
}

provider "aws" {
  region = var.aws_region
}

data "aws_vpc" "default" {
  default = true
}

data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }
}

# ---------- Key Pair ----------
resource "tls_private_key" "ssh" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "app" {
  key_name   = "${var.project_name}-key"
  public_key = tls_private_key.ssh.public_key_openssh
}

resource "local_file" "pem" {
  content         = tls_private_key.ssh.private_key_pem
  filename        = "${path.module}/${var.project_name}-key.pem"
  file_permission = "0400"
}

# ---------- Security Groups ----------
resource "aws_security_group" "app" {
  name        = "${var.project_name}-app-sg"
  description = "SSH y API"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8000
    to_port     = 8000
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

resource "aws_security_group" "db" {
  name        = "${var.project_name}-db-sg"
  description = "MySQL solo desde la EC2"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.app.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ---------- RDS + Secrets Manager ----------
resource "random_password" "db" {
  length  = 20
  special = false
}

resource "aws_db_instance" "db" {
  identifier             = "${var.project_name}-db"
  engine                 = "mysql"
  engine_version         = "8.0"
  instance_class         = "db.t3.micro"
  allocated_storage      = 20
  db_name                = "todos"
  username               = "admin"
  password               = random_password.db.result
  vpc_security_group_ids = [aws_security_group.db.id]
  publicly_accessible    = false
  skip_final_snapshot    = true
}

resource "aws_secretsmanager_secret" "db" {
  name                    = "${var.project_name}-db-credentials"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "db" {
  secret_id = aws_secretsmanager_secret.db.id
  secret_string = jsonencode({
    username = aws_db_instance.db.username
    password = random_password.db.result
    host     = aws_db_instance.db.address
    port     = 3306
    dbname   = "todos"
  })
}

# ---------- EC2 ----------
resource "aws_instance" "app" {
  ami                    = data.aws_ami.al2023.id
  instance_type          = var.instance_type
  key_name               = aws_key_pair.app.key_name
  vpc_security_group_ids = [aws_security_group.app.id]
  iam_instance_profile   = "LabInstanceProfile"

  user_data_replace_on_change = true
  user_data                   = <<EOT
#!/bin/bash
dnf install -y git python3.11 python3.11-pip
git clone ${var.repo_url} /opt/app
python3.11 -m pip install -r /opt/app/src/requirements.txt
cat > /etc/systemd/system/todo.service <<EOF
[Unit]
Description=To-do list API
After=network.target

[Service]
WorkingDirectory=/opt/app/src
Environment=SECRET_NAME=${aws_secretsmanager_secret.db.name}
Environment=AWS_REGION=${var.aws_region}
Environment=APP_VERSION=${var.app_version}
ExecStart=/usr/bin/python3.11 -m uvicorn main:app --host 0.0.0.0 --port 8000
Restart=always

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable --now todo
EOT

  tags = {
    Name = "${var.project_name}-app"
  }

  depends_on = [aws_secretsmanager_secret_version.db]
}
