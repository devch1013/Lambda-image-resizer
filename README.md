# Lambda Image Resizer - Lambda@Edge

[English Version](README_EN.md) | 한국어

CloudFront와 Lambda@Edge를 사용한 온디맨드 이미지 리사이징 서버입니다.

## 주요 기능

- **온디맨드 이미지 리사이징**: 쿼리 파라미터로 이미지 크기 조정
- **Signed URL 지원**: Private CloudFront 배포에서도 정상 작동
- **1MB 제한 처리**: 응답이 1MB를 초과할 경우 S3 원본 반환
- **비이미지 파일 처리**: 영상 등 비이미지 파일은 원본 그대로 반환
- **다양한 포맷 지원**: JPG, PNG, WebP, AVIF, GIF, TIFF
- **자동 캐싱**: CloudFront를 통한 전역 엣지 캐싱

## 사전 요구사항

- **Ubuntu 환경** (또는 bash 쉘 지원 환경)
- **Node.js 18.x 이상**
- **AWS CLI** 설치 및 구성 완료
- **jq** 설치: `sudo apt-get install jq`
- **zip** 설치: `sudo apt-get install zip`

## 빠른 시작 (Quick Start)

### 1단계: AWS CLI 설정

AWS CLI를 설치하고 자격 증명을 구성해야 합니다:

```bash
# AWS CLI 설치 (아직 설치하지 않은 경우)
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# AWS 자격 증명 구성
aws configure
```

`aws configure` 실행 시 다음 정보를 입력해야 합니다:
- **AWS Access Key ID**: IAM 사용자의 액세스 키
- **AWS Secret Access Key**: IAM 사용자의 시크릿 키
- **Default region name**: 기본 리전 (예: `ap-northeast-2`)
- **Default output format**: 출력 형식 (예: `json`)

**필요한 IAM 권한:**
- Lambda 함수 생성 및 관리
- CloudFront 배포 수정
- S3 버킷 읽기
- IAM 역할 생성 및 관리

### 2단계: 의존성 설치

```bash
sudo apt-get update
sudo apt-get install -y jq zip nodejs npm
```

### 3단계: 설정 파일 생성

**단일 환경:**

`config.txt` 파일을 열어 자신의 AWS 환경에 맞게 수정하세요:

```bash
nano config.txt
```

**여러 환경 관리 (Production, Development 등):**

환경별로 다른 설정 파일을 만들 수 있습니다:

```bash
# 예시 파일을 복사하여 환경별 설정 생성
cp config.example.txt config-production.txt
cp config.example.txt config-development.txt

# 또는 기존 설정을 복사
cp config.txt config-public.txt
cp config.txt config-private.txt

# 각 파일을 편집
nano config-production.txt
nano config-development.txt
```

수정이 필요한 항목:
- `AWS_ACCOUNT_ID`: AWS 계정 ID
- `CLOUDFRONT_ID`: CloudFront Distribution ID
- `S3_BUCKET`: S3 버킷명
- `S3_REGION`: S3 버킷이 위치한 리전
- `LAMBDA_FUNCTION_NAME`: Lambda 함수명 (환경별로 다르게 설정 권장)
- `LAMBDA_ROLE_NAME`: IAM 역할명 (환경별로 다르게 설정 권장)

### 4단계: 전체 설치 및 배포

**기본 설정 파일 사용:**

```bash
chmod +x setup.sh
./setup.sh
```

**특정 설정 파일 사용:**

```bash
chmod +x setup.sh
./setup.sh config-production.txt
```

이 스크립트는 다음 작업을 자동으로 수행합니다:
1. Lambda 함수 배포
2. Query String Forwarding 활성화
3. CloudFront에 Lambda@Edge 연결
4. 배포 완료 대기 및 캐시 무효화

**완료!** 10-15분 후 이미지 리사이징 서비스를 사용할 수 있습니다.

## 사용법

### 쿼리 파라미터

| 파라미터 | 설명 | 예시 |
|---------|------|-----|
| `w` | 너비 (픽셀) | `w=300` |
| `h` | 높이 (픽셀) | `h=200` |
| `q` | 품질 (1-100) | `q=85` |
| `f` | 출력 포맷 | `f=webp` |

### 사용 예시

**원본 이미지:**
```
https://your-cloudfront-domain.cloudfront.net/images/photo.jpg
```

**너비 300px로 리사이징:**
```
https://your-cloudfront-domain.cloudfront.net/images/photo.jpg?w=300
```

**너비 300px, 높이 200px로 리사이징:**
```
https://your-cloudfront-domain.cloudfront.net/images/photo.jpg?w=300&h=200
```

**WebP 포맷으로 변환 + 품질 90:**
```
https://your-cloudfront-domain.cloudfront.net/images/photo.jpg?w=800&f=webp&q=90
```

**여러 파라미터 조합:**
```
https://your-cloudfront-domain.cloudfront.net/images/photo.jpg?w=500&h=300&q=75&f=webp
```

## 동작 방식

1. **이미지 요청**: 사용자가 쿼리 파라미터와 함께 이미지를 요청
2. **Lambda@Edge 실행**: origin-request 시점에 Lambda 함수 실행
3. **검증**:
   - 파일 확장자가 이미지 형식인지 확인
   - 리사이징 파라미터가 있는지 확인
4. **처리**:
   - S3에서 원본 이미지 가져오기
   - Sharp 라이브러리로 이미지 처리
   - 결과 크기가 750KB 이하인지 확인
5. **응답**:
   - 750KB 이하: Lambda에서 직접 응답 (base64 인코딩)
   - 750KB 초과 또는 에러: 원본 요청을 S3로 전달

## 프로젝트 구조

```
lambda_resizing/
├── config.txt                      # 기본 설정 파일
├── config.example.txt              # 설정 파일 예시
├── config-public.txt               # Public 환경 설정 예시
├── config-private.txt.example      # Private 환경 설정 예시
├── .gitignore                      # Git 제외 파일 목록
├── index.js                        # Lambda@Edge 함수 코드 (배포 시 생성)
├── index.js.template               # Lambda 함수 템플릿
├── package.json                    # Node.js 의존성 정의
├── setup.sh                        # 통합 설치 스크립트 (권장)
├── deploy.sh                       # Lambda 배포 스크립트
├── enable-query-string.sh          # Query String 활성화 스크립트
├── configure-cloudfront.sh         # CloudFront 설정 스크립트
└── README.md                       # 이 문서
```

### 코드 주입 시스템

Lambda@Edge는 환경 변수를 지원하지 않기 때문에, 배포 시점에 설정 값을 코드에 직접 주입합니다:

1. **index.js.template**: S3 버킷과 리전을 플레이스홀더(`{{S3_BUCKET}}`, `{{S3_REGION}}`)로 포함한 템플릿
2. **deploy.sh**: 배포 시 config 파일의 값을 읽어 템플릿에서 `index.js`를 생성
3. **index.js**: 생성된 실제 Lambda 함수 코드 (설정 값이 하드코딩됨)

이 방식으로 환경별로 다른 S3 버킷과 리전을 사용할 수 있습니다.

## 고급 사용법

### 여러 환경 관리

여러 AWS 환경(Production, Development, Public, Private 등)을 관리할 때 각각 다른 설정 파일을 사용할 수 있습니다:

```bash
# Production 환경 배포
./setup.sh config-production.txt

# Development 환경 배포
./setup.sh config-development.txt

# Public CloudFront 배포
./setup.sh config-public.txt

# Private CloudFront 배포
./setup.sh config-private.txt
```

**환경별 Lambda 함수명을 다르게 설정하는 것을 권장합니다:**

```bash
# config-production.txt
LAMBDA_FUNCTION_NAME=image-resizer-production

# config-development.txt
LAMBDA_FUNCTION_NAME=image-resizer-development
```

### 개별 스크립트 실행

전체 설치 대신 개별 단계를 실행하려면:

```bash
# 기본 설정 파일 사용
./deploy.sh
./enable-query-string.sh
./configure-cloudfront.sh

# 특정 설정 파일 사용
./deploy.sh config-production.txt
./enable-query-string.sh config-production.txt
./configure-cloudfront.sh config-production.txt
```

### 코드 업데이트

Lambda 함수 코드(`index.js`)를 수정한 후:

```bash
# 기본 설정으로 업데이트
./deploy.sh
./configure-cloudfront.sh

# 특정 환경만 업데이트
./deploy.sh config-production.txt
./configure-cloudfront.sh config-production.txt
```

### 배포 상태 확인

```bash
# CloudFront 배포 상태
aws cloudfront get-distribution --id <CLOUDFRONT_ID> --query 'Distribution.Status'

# Lambda 함수 정보
aws lambda get-function --function-name {Lambda 함수 명} --region us-east-1
```

### 캐시 무효화

```bash
# 전체 캐시 무효화
aws cloudfront create-invalidation --distribution-id <CLOUDFRONT_ID> --paths "/*"

# 특정 경로만 무효화
aws cloudfront create-invalidation --distribution-id <CLOUDFRONT_ID> --paths "/images/*"
```

## 트러블슈팅

### Lambda 함수 로그 확인

Lambda@Edge 로그는 함수가 실행된 리전의 CloudWatch Logs에 저장됩니다.

```bash
# us-east-1 리전에서 로그 확인
aws logs tail /aws/lambda/us-east-1.{Lambda 함수 명} --follow --region us-east-1

# 최근 10분간의 로그
aws logs tail /aws/lambda/us-east-1.{Lambda 함수 명} --since 10m
```

### 일반적인 문제 해결

**문제: 이미지 크기가 변경되지 않음**
- 캐시 무효화 후 브라우저 캐시도 비우기 (Ctrl+Shift+R)
- curl로 테스트: `curl -I "https://your-domain/image.jpg?w=300"`

**문제: 502 Bad Gateway 에러**
- Lambda 로그에서 에러 확인
- 이미지 크기가 너무 큰 경우 (응답 750KB 초과)
- Lambda 타임아웃 (30초) 초과

**문제: Query String이 전달되지 않음**
- `enable-query-string.sh` 실행 여부 확인
- Cache Policy가 제대로 설정되었는지 확인:
  ```bash
  aws cloudfront get-distribution-config --id <CLOUDFRONT_ID> --query 'DistributionConfig.DefaultCacheBehavior.CachePolicyId'
  ```

**문제: S3 권한 에러**
- IAM 역할에 S3 읽기 권한이 있는지 확인:
  ```bash
  aws iam get-role-policy --role-name {IAM role 이름} --policy-name S3ReadPolicy
  ```

### CloudWatch 메트릭

Lambda@Edge의 성능을 모니터링하려면:

```bash
# Lambda 실행 횟수
aws cloudwatch get-metric-statistics \
  --namespace AWS/Lambda \
  --metric-name Invocations \
  --dimensions Name=FunctionName,Value={Lambda 함수 명} \
  --start-time 2024-01-01T00:00:00Z \
  --end-time 2024-01-02T00:00:00Z \
  --period 3600 \
  --statistics Sum
```

## 제한 사항

- **응답 크기**: Lambda@Edge는 최대 1MB 응답 제한 (실질적으로 ~750KB)
- **실행 시간**: 최대 30초 (설정값)
- **메모리**: 512MB (설정값)
- **지원 포맷**: JPG, PNG, WebP, AVIF, GIF, TIFF
- **Lambda 리전**: 반드시 us-east-1에 배포 (Lambda@Edge 요구사항)

## 비용 최적화

- **CloudFront 캐싱**: 동일한 요청은 Lambda를 거치지 않고 캐시에서 제공
- **쿼리 파라미터**: 자주 사용되는 크기는 미리 생성하여 S3에 저장 고려
- **CloudWatch Logs**: 로그 보관 기간을 설정하여 비용 절감
  ```bash
  aws logs put-retention-policy \
    --log-group-name /aws/lambda/us-east-1.{Lambda 함수 명} \
    --retention-in-days 7
  ```
