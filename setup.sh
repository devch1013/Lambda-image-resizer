#!/bin/bash

set -e

# 설정 파일 경로 (첫 번째 인자로 받거나 기본값 사용)
CONFIG_FILE="${1:-config.txt}"

echo "========================================"
echo "  Lambda Image Resizer Setup"
echo "========================================"
echo ""

# 설정 파일 확인
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Error: Configuration file '$CONFIG_FILE' not found!"
    echo ""
    echo "Usage: $0 [config-file]"
    echo "Example: $0 config-public.txt"
    echo ""
    echo "If no config file is specified, 'config.txt' will be used by default."
    exit 1
fi

# 설정 파일에서 변수 로드 (주석 제외)
source <(grep -v '^#' "$CONFIG_FILE" | grep -v '^$')

echo "Configuration loaded from $CONFIG_FILE:"
echo "  AWS Account ID: $AWS_ACCOUNT_ID"
echo "  CloudFront ID: $CLOUDFRONT_ID"
echo "  S3 Bucket: $S3_BUCKET ($S3_REGION)"
echo "  Lambda Function: $LAMBDA_FUNCTION_NAME"
echo ""

# 사용자 확인
read -p "Continue with this configuration? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Setup cancelled."
    exit 0
fi

echo ""
echo "=========================================="
echo "Step 1/4: Deploying Lambda Function"
echo "=========================================="
./deploy.sh "$CONFIG_FILE"

echo ""
echo "=========================================="
echo "Step 2/4: Enabling Query String Forwarding"
echo "=========================================="
./enable-query-string.sh "$CONFIG_FILE"

echo ""
echo "=========================================="
echo "Step 3/4: Configuring CloudFront"
echo "=========================================="
./configure-cloudfront.sh "$CONFIG_FILE"

echo ""
echo "=========================================="
echo "Step 4/4: Waiting for CloudFront Deployment"
echo "=========================================="
echo "CloudFront distribution is being deployed..."
echo "This may take 10-15 minutes."
echo ""

# CloudFront 배포 상태 확인
echo "Checking deployment status every 30 seconds..."
while true; do
    STATUS=$(aws cloudfront get-distribution --id $CLOUDFRONT_ID --query 'Distribution.Status' --output text)

    if [ "$STATUS" == "Deployed" ]; then
        echo ""
        echo "✓ CloudFront deployment completed!"
        break
    fi

    echo "  Status: $STATUS (waiting...)"
    sleep 30
done

echo ""
echo "=========================================="
echo "Invalidating CloudFront Cache"
echo "=========================================="
INVALIDATION_ID=$(aws cloudfront create-invalidation --distribution-id $CLOUDFRONT_ID --paths "/*" --query 'Invalidation.Id' --output text)
echo "Cache invalidation started: $INVALIDATION_ID"

echo ""
echo "========================================"
echo "  Setup Complete!"
echo "========================================"
echo ""
echo "Your image resizer is now ready to use!"
echo ""
echo "Test with:"
echo "  https://your-cloudfront-domain/image.jpg?w=300"
echo ""
echo "Available parameters:"
echo "  w - Width (pixels)"
echo "  h - Height (pixels)"
echo "  q - Quality (1-100, default: 80)"
echo "  f - Format (jpg, png, webp, avif, gif, tiff)"
echo ""
echo "Example URLs:"
echo "  ?w=300              - Resize to 300px width"
echo "  ?w=300&h=200        - Resize to 300x200"
echo "  ?w=800&f=webp&q=90  - Convert to WebP with 90% quality"
echo ""
echo "To view logs:"
echo "  aws logs tail /aws/lambda/$LAMBDA_REGION.$LAMBDA_FUNCTION_NAME --follow"
echo ""