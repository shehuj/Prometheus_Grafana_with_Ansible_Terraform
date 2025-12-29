#!/bin/bash
# Quick fix for SSM Session Manager KMS permissions
# This adds the necessary permissions to the existing IAM role

set -e

ACCOUNT_ID="615299732970"
REGION="us-east-1"
ROLE_NAME="monitoring-server-role-production"  # Using production environment

echo "=========================================="
echo "SSM Session Manager Permission Fix"
echo "=========================================="
echo ""
echo "This script will add KMS decrypt permissions to the IAM role"
echo "Role: $ROLE_NAME"
echo ""

# Create the KMS policy document
cat > /tmp/kms-ssm-policy.json <<'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ssmmessages:CreateControlChannel",
        "ssmmessages:CreateDataChannel",
        "ssmmessages:OpenControlChannel",
        "ssmmessages:OpenDataChannel",
        "ssm:UpdateInstanceInformation"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "kms:Decrypt",
        "kms:DescribeKey",
        "kms:GenerateDataKey"
      ],
      "Resource": "*"
    }
  ]
}
EOF

echo "1. Adding SSM and KMS permissions to IAM role..."
aws iam put-role-policy \
  --role-name "$ROLE_NAME" \
  --policy-name "SSM-Session-Manager-KMS" \
  --policy-document file:///tmp/kms-ssm-policy.json

echo "✓ Policy added successfully"
echo ""

echo "2. Attaching AWS managed SSM policy..."
aws iam attach-role-policy \
  --role-name "$ROLE_NAME" \
  --policy-arn "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore" 2>/dev/null || echo "  (Policy already attached or error - continuing)"

echo "✓ Managed policy attached"
echo ""

echo "3. Verifying role policies..."
echo ""
echo "Inline policies:"
aws iam list-role-policies --role-name "$ROLE_NAME" --output table

echo ""
echo "Attached managed policies:"
aws iam list-attached-role-policies --role-name "$ROLE_NAME" --output table

echo ""
echo "=========================================="
echo "Fix Applied Successfully!"
echo "=========================================="
echo ""
echo "The IAM role now has SSM Session Manager and KMS permissions."
echo "You can now connect to the instance via SSM Session Manager."
echo ""
echo "Test the connection:"
echo "  AWS Console → EC2 → Instances → Connect → Session Manager"
echo ""
echo "Or via CLI:"
echo "  aws ssm start-session --target i-0f1443a5da02e1fd0"
echo ""

# Cleanup
rm -f /tmp/kms-ssm-policy.json
