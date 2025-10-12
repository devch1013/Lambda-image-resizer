#!/bin/bash

set -e

# 설정 파일 경로 (첫 번째 인자로 받거나 기본값 사용)
CONFIG_FILE="${1:-config.txt}"

# 설정 파일에서 설정 읽기
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Error: Configuration file '$CONFIG_FILE' not found!"
    echo ""
    echo "Usage: $0 [config-file]"
    echo "Example: $0 config-public.txt"
    exit 1
fi

# 설정 파일에서 변수 로드 (주석 제외)
source <(grep -v '^#' "$CONFIG_FILE" | grep -v '^$')

echo "=== CloudFront Configuration Script ==="
echo ""
echo "Configuration:"
echo "  CloudFront ID: $CLOUDFRONT_ID"
echo "  Lambda Function: $LAMBDA_FUNCTION_NAME"
echo ""

# Lambda 함수의 최신 버전 ARN 가져오기
VERSION=$(aws lambda list-versions-by-function \
    --function-name $LAMBDA_FUNCTION_NAME \
    --region $LAMBDA_REGION \
    --query 'Versions[-1].Version' \
    --output text)

FUNCTION_ARN="arn:aws:lambda:$LAMBDA_REGION:$AWS_ACCOUNT_ID:function:$LAMBDA_FUNCTION_NAME:$VERSION"

echo "Using Lambda function: $FUNCTION_ARN"
echo ""

# 현재 CloudFront 배포 설정 가져오기
echo "Fetching current CloudFront distribution configuration..."
aws cloudfront get-distribution-config \
    --id $CLOUDFRONT_ID \
    --output json > current-config.json

# ETag 추출 (업데이트 시 필요)
ETAG=$(jq -r '.ETag' current-config.json)

# DistributionConfig만 추출
jq '.DistributionConfig' current-config.json > distribution-config.json

# Lambda@Edge 연결 설정 추가
echo "Adding Lambda@Edge association to origin request..."

# DefaultCacheBehavior에 Lambda@Edge 연결
jq --arg arn "$FUNCTION_ARN" \
  '.DefaultCacheBehavior.LambdaFunctionAssociations.Quantity = 1 |
   .DefaultCacheBehavior.LambdaFunctionAssociations.Items = [{
     "LambdaFunctionARN": $arn,
     "EventType": "origin-request",
     "IncludeBody": false
   }]' distribution-config.json > updated-config.json

# CloudFront 배포 업데이트
echo "Updating CloudFront distribution..."
aws cloudfront update-distribution \
    --id $CLOUDFRONT_ID \
    --distribution-config file://updated-config.json \
    --if-match $ETAG \
    --output json > update-result.json

echo ""
echo "=== CloudFront Update Complete ==="
echo "Distribution ID: $CLOUDFRONT_ID"
echo "Status: Deploying (this may take 10-15 minutes)"
echo ""
echo "To check deployment status, run:"
echo "  aws cloudfront get-distribution --id $CLOUDFRONT_ID --query 'Distribution.Status'"
echo ""

# 임시 파일 정리
rm current-config.json distribution-config.json updated-config.json update-result.json

echo "Configuration files cleaned up."