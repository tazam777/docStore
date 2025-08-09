#!/bin/bash
set -e
ECR_REPO="033376538641.dkr.ecr.us-east-2.amazonaws.com/aws-project-3ca4"
AWS_REGION="us-east-2"

echo "Logging into ECR..."
aws ecr get-login-password --region $AWS_REGION \
  | docker login --username AWS --password-stdin $ECR_REPO

echo "Stopping old container..."
docker ps -q --filter "name=app" | xargs -r docker stop || true
docker ps -aq --filter "name=app" | xargs -r docker rm || true

echo "Pulling latest image..."
docker pull $ECR_REPO:latest

echo "Starting new container..."
docker run -d --name app -p 8080:8080 $ECR_REPO:latest
