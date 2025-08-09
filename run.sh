#!/bin/bash

# Build the Docker image
echo "Building Docker image..."
docker build -t aws-project:latest .

# Get AWS credentials from local configuration
AWS_KEY=$(aws configure get aws_access_key_id)
AWS_SECRET=$(aws configure get aws_secret_access_key)
AWS_REGION=$(aws configure get region)

# Stop and remove existing container if it exists
echo "Stopping and removing existing container..."
docker stop aws-project-container 2>/dev/null
docker rm aws-project-container 2>/dev/null

# Run the new container
echo "Starting new container..."
docker run -d --name aws-project-container \
  -p 8080:8080 \
  -e AWS_ACCESS_KEY_ID=$AWS_KEY \
  -e AWS_SECRET_ACCESS_KEY=$AWS_SECRET \
  -e AWS_REGION=$AWS_REGION \
  aws-project:latest

# Wait a moment for container to start
sleep 2

# Tail the logs
echo "Following container logs (Press Ctrl+C to stop)..."
docker logs -f aws-project-container