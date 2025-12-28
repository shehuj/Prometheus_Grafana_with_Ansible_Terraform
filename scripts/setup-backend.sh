#!/bin/bash
# Setup Terraform S3 Backend
# Creates S3 bucket and DynamoDB table for state management

set -e

REGION="${AWS_REGION:-us-east-1}"
BUCKET_NAME="ec2-shutdown-lambda-bucket"
DYNAMODB_TABLE="dyning_table"

echo "========================================="
echo "Setting up Terraform Backend"
echo "========================================="
echo "Region: $REGION"
echo "Bucket: $BUCKET_NAME"
echo "DynamoDB: $DYNAMODB_TABLE"
echo "========================================="

# Create S3 bucket
echo "Creating S3 bucket..."
if aws s3 ls "s3://${BUCKET_NAME}" 2>&1 | grep -q 'NoSuchBucket'; then
    aws s3api create-bucket \
        --bucket "${BUCKET_NAME}" \
        --region "${REGION}" \
        $([ "$REGION" != "us-east-1" ] && echo "--create-bucket-configuration LocationConstraint=${REGION}")
    echo "✅ S3 bucket created: ${BUCKET_NAME}"
else
    echo "✅ S3 bucket already exists: ${BUCKET_NAME}"
fi

# Enable versioning
echo "Enabling versioning..."
aws s3api put-bucket-versioning \
    --bucket "${BUCKET_NAME}" \
    --versioning-configuration Status=Enabled
echo "✅ Versioning enabled"

# Enable encryption
echo "Enabling encryption..."
aws s3api put-bucket-encryption \
    --bucket "${BUCKET_NAME}" \
    --server-side-encryption-configuration '{
        "Rules": [{
            "ApplyServerSideEncryptionByDefault": {
                "SSEAlgorithm": "AES256"
            }
        }]
    }'
echo "✅ Encryption enabled"

# Block public access
echo "Blocking public access..."
aws s3api put-public-access-block \
    --bucket "${BUCKET_NAME}" \
    --public-access-block-configuration \
        BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
echo "✅ Public access blocked"

# Create DynamoDB table for state locking
echo "Creating DynamoDB table..."
if aws dynamodb describe-table --table-name "${DYNAMODB_TABLE}" --region "${REGION}" 2>&1 | grep -q 'ResourceNotFoundException'; then
    aws dynamodb create-table \
        --table-name "${DYNAMODB_TABLE}" \
        --attribute-definitions AttributeName=LockID,AttributeType=S \
        --key-schema AttributeName=LockID,KeyType=HASH \
        --billing-mode PAY_PER_REQUEST \
        --region "${REGION}"

    echo "Waiting for table to be active..."
    aws dynamodb wait table-exists \
        --table-name "${DYNAMODB_TABLE}" \
        --region "${REGION}"

    echo "✅ DynamoDB table created: ${DYNAMODB_TABLE}"
else
    echo "✅ DynamoDB table already exists: ${DYNAMODB_TABLE}"
fi

echo ""
echo "========================================="
echo "✅ Terraform backend setup complete!"
echo "========================================="
echo ""
echo "Update your terraform backend configuration:"
echo ""
echo "backend \"s3\" {"
echo "  bucket         = \"${BUCKET_NAME}\""
echo "  key            = \"prometheus-grafana/terraform.tfstate\""
echo "  region         = \"${REGION}\""
echo "  encrypt        = true"
echo "  dynamodb_table = \"${DYNAMODB_TABLE}\""
echo "}"
echo ""
echo "========================================="
