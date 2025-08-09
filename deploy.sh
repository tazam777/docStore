#!/bin/bash
set -e

# Variables
S3_BUCKET="pdf.upload-1"
SNS_TOPIC_ARN="arn:aws:sns:us-east-2:123456789012:pdfUploadNotify"

# Initialize Terraform
terraform init

# Apply Terraform
terraform apply \
  -var="s3_bucket_name=${S3_BUCKET}" \
  -var="sns_topic_arn=${SNS_TOPIC_ARN}" \
  -auto-approve
