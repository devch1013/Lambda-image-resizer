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

echo "=== Lambda Image Resizer Deployment Script ==="
echo ""
echo "Configuration:"
echo "  AWS Account ID: $AWS_ACCOUNT_ID"
echo "  Lambda Function: $LAMBDA_FUNCTION_NAME"
echo "  Lambda Region: $LAMBDA_REGION"
echo "  S3 Bucket: $S3_BUCKET"
echo "  S3 Region: $S3_REGION"
echo ""

# 1. IAM 역할 생성 (이미 있으면 스킵)
echo "Step 1: Creating IAM role for Lambda@Edge..."
ROLE_ARN=$(aws iam get-role --role-name $LAMBDA_ROLE_NAME --query 'Role.Arn' --output text 2>/dev/null || echo "")

if [ -z "$ROLE_ARN" ]; then
    # Trust policy 생성
    cat > trust-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": [
          "lambda.amazonaws.com",
          "edgelambda.amazonaws.com"
        ]
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

    # 역할 생성
    ROLE_ARN=$(aws iam create-role \
        --role-name $LAMBDA_ROLE_NAME \
        --assume-role-policy-document file://trust-policy.json \
        --query 'Role.Arn' \
        --output text)

    echo "Role created: $ROLE_ARN"

    # 정책 연결
    aws iam attach-role-policy \
        --role-name $LAMBDA_ROLE_NAME \
        --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole

    # S3 읽기 권한 추가
    cat > s3-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject"
      ],
      "Resource": "arn:aws:s3:::${S3_BUCKET}/*"
    }
  ]
}
EOF

    aws iam put-role-policy \
        --role-name $LAMBDA_ROLE_NAME \
        --policy-name S3ReadPolicy \
        --policy-document file://s3-policy.json

    echo "Waiting 10 seconds for IAM role to propagate..."
    sleep 10

    # 임시 파일 삭제
    rm trust-policy.json s3-policy.json
else
    echo "Role already exists: $ROLE_ARN"
fi

# 2. 설정 값 주입 및 패키징
echo ""
echo "Step 2: Generating index.js from template..."

# 템플릿에서 index.js 생성 (설정 값 주입)
if [ ! -f "index.js.template" ]; then
    echo "Error: index.js.template not found!"
    exit 1
fi

sed -e "s|{{S3_BUCKET}}|$S3_BUCKET|g" \
    -e "s|{{S3_REGION}}|$S3_REGION|g" \
    index.js.template > index.js

echo "index.js generated with configuration:"
echo "  S3_BUCKET: $S3_BUCKET"
echo "  S3_REGION: $S3_REGION"

echo ""
echo "Step 3: Installing dependencies and packaging..."

# node_modules 정리
rm -rf node_modules package-lock.json

# Lambda 환경에 맞게 의존성 설치
npm install --arch=x64 --platform=linux --production

# 패키지 생성
if [ -f function.zip ]; then
    rm function.zip
fi

zip -r function.zip index.js node_modules package.json

echo "Package created: function.zip"

# 3. Lambda 함수 생성 또는 업데이트
echo ""
echo "Step 3: Deploying Lambda function..."

FUNCTION_EXISTS=$(aws lambda get-function --function-name $LAMBDA_FUNCTION_NAME --region $LAMBDA_REGION 2>/dev/null || echo "")

if [ -z "$FUNCTION_EXISTS" ]; then
    # 함수 생성
    aws lambda create-function \
        --function-name $LAMBDA_FUNCTION_NAME \
        --runtime nodejs18.x \
        --role $ROLE_ARN \
        --handler index.handler \
        --zip-file fileb://function.zip \
        --timeout 30 \
        --memory-size 512 \
        --region $LAMBDA_REGION \
        --publish

    echo "Lambda function created and published"
else
    # 함수 코드 업데이트
    aws lambda update-function-code \
        --function-name $LAMBDA_FUNCTION_NAME \
        --zip-file fileb://function.zip \
        --region $LAMBDA_REGION \
        --publish

    echo "Lambda function updated and published"
fi

# 최신 버전 번호 가져오기
VERSION=$(aws lambda list-versions-by-function \
    --function-name $LAMBDA_FUNCTION_NAME \
    --region $LAMBDA_REGION \
    --query 'Versions[-1].Version' \
    --output text)

FUNCTION_ARN="arn:aws:lambda:$LAMBDA_REGION:$AWS_ACCOUNT_ID:function:$LAMBDA_FUNCTION_NAME:$VERSION"

echo ""
echo "=== Deployment Complete ==="
echo "Function ARN: $FUNCTION_ARN"
echo ""
echo "Next step: Run ./configure-cloudfront.sh to attach this function to CloudFront"
echo ""