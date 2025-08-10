
# AWS Project – S3 Upload + SNS Notification with Terraform & GitHub Actions

## Overview
This project is a Spring Boot application that:
- Accepts file uploads via REST API
- Stores files in an S3 bucket
- Sends an SNS notification upon successful upload
- Can list existing files in the S3 bucket

Infrastructure is provisioned using Terraform (ECR, EC2, ALB, IAM roles, security groups, etc.), and deployments are automated via GitHub Actions to multiple EC2 instances.

## Architecture



### Diagram

         +-------------------+
         |  GitHub Actions   |
         |  (CI/CD Pipeline) |
         +--------+----------+
                  |
          Build & Push Docker
                  |
                  v
         +-------------------+
         |       ECR         |
         | (Image Storage)   |
         +--------+----------+
                  |
          Docker Pull on EC2
         +--------+----------+
         |   EC2 Instance A  |
         | (Spring Boot App) |
         +--------+----------+
                  |
         +--------v----------+
         |   Application     |
         | Load Balancer     |
         +--------+----------+
                  |
          HTTP Requests
                  |
         +--------v----------+
         |     Internet      |
         +-------------------+

App Interactions:
  - Uploads file to S3
  - Publishes message to SNS

### Terraform Provisions:
- ECR repository for Docker image
- EC2 instances behind an Application Load Balancer (ALB)
- Security groups for ALB and EC2
- IAM roles/policies to allow EC2 to:
  - Pull images from ECR
  - Upload files to S3
  - Publish messages to SNS
- S3 and SNS integration

### Spring Boot App
- Runs inside Docker on EC2

### GitHub Actions CI/CD:
- Builds and pushes Docker image to ECR
- SSHes into each EC2 instance and redeploys the updated container

## Endpoints

### POST /upload
**Description**: Uploads a file to S3 and sends an SNS notification.

**Form-data parameter**: `file` (multipart file)

**Response**: 200 OK with uploaded S3 URL, or 500 on error

**Example**:
```bash
curl -F "file=@/path/to/file.pdf" http://<ALB_DNS>/upload
GET /get
Description: Lists files stored in the S3 bucket.

Response: 200 OK with a success message (keys are printed in server logs)

Example:

bash
curl http://<ALB_DNS>/get

```
## Terraform Setup

### Prerequisites
Terraform installed locally

AWS CLI configured

Existing S3 bucket and SNS topic

DynamoDB table for state locking

Init & Apply
bash
terraform init
terraform apply \
  -var="s3_bucket_name=<your-bucket-name>" \
  -var="sns_topic_arn=<your-sns-topic-arn>" \
  -auto-approve
Outputs:

ALB DNS Name → Public URL for your app

ECR Repo URL → For pushing Docker images

EC2 SSH Key → For connecting to instances

Local Build & Test
bash
## Build JAR
./mvnw clean package

## Run locally
java -jar target/awsProject-0.0.1-SNAPSHOT.jar
Docker Build & Push (Manual)
bash
## Authenticate with ECR
aws ecr get-login-password --region us-east-2 \
  | docker login --username AWS --password-stdin <ECR_REPO_URL>

## Build image
docker build -t <ECR_REPO_URL>:latest .

## Push image
docker push <ECR_REPO_URL>:latest
GitHub Actions Deployment
This project includes .github/workflows/deploy.yml that:

Builds & pushes the Docker image to ECR

SSHes into EC2 instances

Stops the running container

Pulls the latest image

Runs the container

Secrets Required
Add these in GitHub repo Settings → Secrets and variables → Actions:

AWS_ACCESS_KEY_ID

AWS_SECRET_ACCESS_KEY

EC2_SSH_KEY → Private key matching the EC2 key pair from Terraform

EC2 Deployment Script (deploy-gha.sh)
When triggered, each EC2 instance:

Logs into ECR

Stops/removes old container

Pulls latest image

Starts new container:

bash
sudo docker run -d --name app -p 8080:8080 <ECR_REPO_URL>:latest
Environment Variables in Container
Currently, the container runs with default AWS SDK region resolution (via EC2 IAM role). If needed, pass environment variables when running the container:

bash
-e AWS_REGION=us-east-2 \
-e APP_S3_BUCKET=<your-bucket-name> \
-e APP_SNS_TOPIC_ARN=<your-sns-topic-arn>
Notes
Security groups allow SSH from 0.0.0.0/0 for now. Lock down in production.

ALB health check path is /, currently accepts HTTP 200–499 as healthy.

/get only prints S3 keys to server logs. Modify to return keys in API response if needed.

For zero downtime, deploy to EC2 instances one at a time instead of stopping both at once.

### License
MIT License. Use at your own risk.