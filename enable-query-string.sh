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

echo "=== Enable Query String Forwarding ==="
echo ""
echo "Configuration:"
echo "  CloudFront ID: $CLOUDFRONT_ID"
echo ""

# 1. CachePolicy 생성
echo "Step 1: Creating cache policy with query string forwarding..."

CACHE_POLICY_NAME="${LAMBDA_FUNCTION_NAME}-cache-policy"

# 이미 존재하는지 확인
EXISTING_POLICY=$(aws cloudfront list-cache-policies --type custom --query "CachePolicyList.Items[?CachePolicy.CachePolicyConfig.Name=='$CACHE_POLICY_NAME'].CachePolicy.Id" --output text 2>/dev/null)

if [ -n "$EXISTING_POLICY" ] && [ "$EXISTING_POLICY" != "None" ]; then
    echo "Cache policy already exists: $EXISTING_POLICY"
    CACHE_POLICY_ID=$EXISTING_POLICY
else
    echo "Creating new cache policy..."
    # CachePolicy 생성
    cat > cache-policy.json <<EOF
{
  "Name": "$CACHE_POLICY_NAME",
  "Comment": "Cache policy for image resizer with query string forwarding",
  "DefaultTTL": 86400,
  "MaxTTL": 31536000,
  "MinTTL": 0,
  "ParametersInCacheKeyAndForwardedToOrigin": {
    "EnableAcceptEncodingGzip": true,
    "EnableAcceptEncodingBrotli": true,
    "QueryStringsConfig": {
      "QueryStringBehavior": "all"
    },
    "HeadersConfig": {
      "HeaderBehavior": "none"
    },
    "CookiesConfig": {
      "CookieBehavior": "none"
    }
  }
}
EOF

    CACHE_POLICY_ID=$(aws cloudfront create-cache-policy \
        --cache-policy-config file://cache-policy.json \
        --query 'CachePolicy.Id' \
        --output text)

    echo "Cache policy created: $CACHE_POLICY_ID"
    rm cache-policy.json
fi

# 2. CloudFront 배포 업데이트
echo ""
echo "Step 2: Updating CloudFront distribution..."

# 현재 설정 가져오기
aws cloudfront get-distribution-config \
    --id $CLOUDFRONT_ID \
    --output json > current-config.json

ETAG=$(jq -r '.ETag' current-config.json)
jq '.DistributionConfig' current-config.json > distribution-config.json

# CachePolicy ID 업데이트
jq --arg policy_id "$CACHE_POLICY_ID" \
  '.DefaultCacheBehavior.CachePolicyId = $policy_id' \
  distribution-config.json > updated-config.json

# CloudFront 배포 업데이트
aws cloudfront update-distribution \
    --id $CLOUDFRONT_ID \
    --distribution-config file://updated-config.json \
    --if-match $ETAG \
    --output json > update-result.json

echo ""
echo "=== Update Complete ==="
echo "Cache Policy ID: $CACHE_POLICY_ID"
echo "Distribution ID: $CLOUDFRONT_ID"
echo "Status: Deploying (this may take 10-15 minutes)"
echo ""
echo "After deployment completes, invalidate the cache:"
echo "  aws cloudfront create-invalidation --distribution-id $CLOUDFRONT_ID --paths \"/*\""
echo ""

# 임시 파일 정리
rm current-config.json distribution-config.json updated-config.json update-result.json

echo "Configuration files cleaned up."