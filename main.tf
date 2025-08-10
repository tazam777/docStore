terraform {
  backend "s3" {
    bucket         = "tf-state-bk1"             # Your S3 bucket for state
    key            = "terraform.tfstate"        # Path/key inside the bucket
    region         = "us-east-2"                 # Your AWS region
    dynamodb_table = "tf-state-lock"             # DynamoDB table for state locking
    encrypt        = true                        # Encrypt state file at rest
  }
}




provider "aws" {
  region = var.region
}

# -----------------------------
# Variables
# -----------------------------
variable "region"        { default = "us-east-2" }
variable "image_tag"     { default = "latest" }
variable "app_port"      { default = 8080 }
variable "s3_bucket_name" { description = "Existing S3 bucket name" }
variable "sns_topic_arn"  { description = "Existing SNS topic ARN" }

# -----------------------------
# Data Sources
# -----------------------------
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

data "aws_ami" "al2" {
  most_recent = true
  owners      = ["137112412989"]
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

# -----------------------------
# Random ID
# -----------------------------
resource "random_id" "suffix" {
  byte_length = 2
}

# -----------------------------
# Key Pair for SSH
# -----------------------------
resource "tls_private_key" "ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "deployer" {
  key_name   = "app-key-${random_id.suffix.hex}"
  public_key = tls_private_key.ssh_key.public_key_openssh
}

output "ssh_private_key" {
  value     = tls_private_key.ssh_key.private_key_pem
  sensitive = true
}

# -----------------------------
# ECR Repository
# -----------------------------
resource "aws_ecr_repository" "app" {
  name                 = "aws-project-${random_id.suffix.hex}"
  image_tag_mutability = "MUTABLE"
  image_scanning_configuration { scan_on_push = true }
}

output "ecr_repo_url" {
  value = aws_ecr_repository.app.repository_url
}

# -----------------------------
# Security Groups
# -----------------------------
resource "aws_security_group" "alb_sg" {
  name   = "alb-sg-${random_id.suffix.hex}"
  vpc_id = data.aws_vpc.default.id

  ingress {
    from_port   = 80
    to_port     = 80
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

resource "aws_security_group" "ec2_sg" {
  name   = "ec2-sg-${random_id.suffix.hex}"
  vpc_id = data.aws_vpc.default.id

  ingress {
    from_port       = var.app_port
    to_port         = var.app_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  ingress {
    from_port   = 22
    to_port     = 22
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

# -----------------------------
# IAM for EC2
# -----------------------------
data "aws_iam_policy_document" "assume_ec2" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ec2_role" {
  name               = "ec2-app-role-${random_id.suffix.hex}"
  assume_role_policy = data.aws_iam_policy_document.assume_ec2.json
}

# Allow EC2 to pull images from ECR
resource "aws_iam_role_policy_attachment" "ecr_read" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# Custom policy for S3 and SNS
data "aws_iam_policy_document" "app_access" {
  statement {
    effect    = "Allow"
    actions   = ["s3:PutObject"]
    resources = ["arn:aws:s3:::${var.s3_bucket_name}/*"]
  }
  statement {
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
    resources = ["arn:aws:s3:::${var.s3_bucket_name}"]
  }
  statement {
    effect    = "Allow"
    actions   = ["sns:Publish"]
    resources = [var.sns_topic_arn]
  }
}

resource "aws_iam_policy" "app_access" {
  name   = "app-s3-sns-policy-${random_id.suffix.hex}"
  policy = data.aws_iam_policy_document.app_access.json
}

resource "aws_iam_role_policy_attachment" "app_access_attach" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = aws_iam_policy.app_access.arn
}


# Instance profile for EC2
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "ec2-app-profile-${random_id.suffix.hex}"
  role = aws_iam_role.ec2_role.name
}


resource "aws_iam_role_policy" "allow_sns_publish" {
  name = "AllowSNSPublish"
  role = aws_iam_role.ec2_role.name  # Use the EC2 role resource

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sns:Publish"
        ]
        Resource = "arn:aws:sns:us-east-2:033376538641:pdfUploadNotify"
      }
    ]
  })
}


# -----------------------------
# Load Balancer
# -----------------------------
resource "aws_lb" "app" {
  name               = "app-alb-${random_id.suffix.hex}"
  load_balancer_type = "application"
  subnets            = slice(data.aws_subnets.default.ids, 0, 2)
  security_groups    = [aws_security_group.alb_sg.id]
}

resource "aws_lb_target_group" "tg" {
  name     = "app-tg-${random_id.suffix.hex}"
  port     = var.app_port
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.default.id

  health_check {
    path                = "/"
    matcher             = "200-499"
    interval            = 15
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.app.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg.arn
  }
}

output "alb_dns" {
  value = aws_lb.app.dns_name
}

# -----------------------------
# EC2 User Data
# -----------------------------
locals {
  user_data = <<-EOF
    #!/bin/bash
    set -eux
    yum update -y
    yum install -y docker awscli
    systemctl enable docker
    systemctl start docker

    REGION=${var.region}
    REPO=${aws_ecr_repository.app.repository_url}
    REGISTRY=$(echo ${aws_ecr_repository.app.repository_url} | cut -d/ -f1)

    aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $REGISTRY
    docker pull $REPO:${var.image_tag}

    docker rm -f app || true
    docker run -d --restart=always \
      -p ${var.app_port}:${var.app_port} \
      -e AWS_REGION=${var.region} \
      -e APP_SNS_TOPIC_ARN='${var.sns_topic_arn}' \
      --name app $REPO:${var.image_tag}
  EOF
}

# -----------------------------
# EC2 Instances
# -----------------------------
resource "aws_instance" "app_a" {
  ami                    = data.aws_ami.al2.id
  instance_type          = "t3.micro"
  subnet_id              = slice(data.aws_subnets.default.ids, 0, 2)[0]
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name
  user_data              = base64encode(local.user_data)
  key_name               = aws_key_pair.deployer.key_name
  tags = { Name = "app-ec2-a-${random_id.suffix.hex}" }
}

resource "aws_instance" "app_b" {
  ami                    = data.aws_ami.al2.id
  instance_type          = "t3.micro"
  subnet_id              = slice(data.aws_subnets.default.ids, 0, 2)[1]
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name
  user_data              = base64encode(local.user_data)
  key_name               = aws_key_pair.deployer.key_name
  tags = { Name = "app-ec2-b-${random_id.suffix.hex}" }
}

resource "aws_lb_target_group_attachment" "a" {
  target_group_arn = aws_lb_target_group.tg.arn
  target_id        = aws_instance.app_a.id
  port             = var.app_port
}

resource "aws_lb_target_group_attachment" "b" {
  target_group_arn = aws_lb_target_group.tg.arn
  target_id        = aws_instance.app_b.id
  port             = var.app_port
}

# -----------------------------
# Outputs
# -----------------------------
output "instance_ids" {
  value = [aws_instance.app_a.id, aws_instance.app_b.id]
}

output "instance_public_ips" {
  value = [aws_instance.app_a.public_ip, aws_instance.app_b.public_ip]
}

output "target_group_arn" {
  value = aws_lb_target_group.tg.arn
}
