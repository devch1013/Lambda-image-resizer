# Lambda Image Resizer - Lambda@Edge

[한국어](README.md) | English Version

An on-demand image resizing server using CloudFront and Lambda@Edge.

## Key Features

- **On-demand Image Resizing**: Resize images using query parameters
- **Signed URL Support**: Works with private CloudFront distributions
- **1MB Limit Handling**: Returns S3 original when response exceeds 1MB
- **Non-image File Handling**: Returns non-image files (videos, etc.) as-is
- **Multiple Format Support**: JPG, PNG, WebP, AVIF, GIF, TIFF
- **Automatic Caching**: Global edge caching through CloudFront

## Prerequisites

- **Ubuntu Environment** (or bash shell support)
- **Node.js 18.x or higher**
- **AWS CLI** installed and configured
- **jq** installed: `sudo apt-get install jq`
- **zip** installed: `sudo apt-get install zip`

## Quick Start

### Step 1: AWS CLI Setup

You need to install and configure AWS CLI credentials:

```bash
# Install AWS CLI (if not already installed)
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# Configure AWS credentials
aws configure
```

When running `aws configure`, you need to provide the following information:
- **AWS Access Key ID**: Your IAM user's access key
- **AWS Secret Access Key**: Your IAM user's secret key
- **Default region name**: Default region (e.g., `ap-northeast-2`)
- **Default output format**: Output format (e.g., `json`)

**Required IAM Permissions:**
- Lambda function creation and management
- CloudFront distribution modification
- S3 bucket read access
- IAM role creation and management

### Step 2: Install Dependencies

```bash
sudo apt-get update
sudo apt-get install -y jq zip nodejs npm
```

### Step 3: Create Configuration File

**Single Environment:**

Open the `config.txt` file and modify it for your AWS environment:

```bash
nano config.txt
```

**Multiple Environment Management (Production, Development, etc.):**

You can create different configuration files for each environment:

```bash
# Copy example files to create environment-specific configurations
cp config.example.txt config-production.txt
cp config.example.txt config-development.txt

# Or copy existing configuration
cp config.txt config-public.txt
cp config.txt config-private.txt

# Edit each file
nano config-production.txt
nano config-development.txt
```

Items that need modification:
- `AWS_ACCOUNT_ID`: AWS Account ID
- `CLOUDFRONT_ID`: CloudFront Distribution ID
- `S3_BUCKET`: S3 bucket name
- `S3_REGION`: Region where S3 bucket is located
- `LAMBDA_FUNCTION_NAME`: Lambda function name (recommended to set differently per environment)
- `LAMBDA_ROLE_NAME`: IAM role name (recommended to set differently per environment)

### Step 4: Complete Installation and Deployment

**Using default configuration file:**

```bash
chmod +x setup.sh
./setup.sh
```

**Using specific configuration file:**

```bash
chmod +x setup.sh
./setup.sh config-production.txt
```

This script automatically performs the following tasks:
1. Deploy Lambda function
2. Enable Query String Forwarding
3. Connect Lambda@Edge to CloudFront
4. Wait for deployment completion and invalidate cache

**Done!** You can use the image resizing service after 10-15 minutes.

## Usage

### Query Parameters

| Parameter | Description | Example |
|-----------|-------------|---------|
| `w` | Width (pixels) | `w=300` |
| `h` | Height (pixels) | `h=200` |
| `q` | Quality (1-100) | `q=85` |
| `f` | Output format | `f=webp` |

### Usage Examples

**Original image:**
```
https://your-cloudfront-domain.cloudfront.net/images/photo.jpg
```

**Resize to 300px width:**
```
https://your-cloudfront-domain.cloudfront.net/images/photo.jpg?w=300
```

**Resize to 300px width and 200px height:**
```
https://your-cloudfront-domain.cloudfront.net/images/photo.jpg?w=300&h=200
```

**Convert to WebP format + quality 90:**
```
https://your-cloudfront-domain.cloudfront.net/images/photo.jpg?w=800&f=webp&q=90
```

**Multiple parameter combination:**
```
https://your-cloudfront-domain.cloudfront.net/images/photo.jpg?w=500&h=300&q=75&f=webp
```

## How It Works

1. **Image Request**: User requests image with query parameters
2. **Lambda@Edge Execution**: Lambda function executes at origin-request
3. **Validation**:
   - Check if file extension is image format
   - Check if resizing parameters exist
4. **Processing**:
   - Fetch original image from S3
   - Process image with Sharp library
   - Check if result size is under 750KB
5. **Response**:
   - Under 750KB: Direct response from Lambda (base64 encoded)
   - Over 750KB or error: Forward original request to S3

## Project Structure

```
lambda_resizing/
├── config.txt                      # Default configuration file
├── config.example.txt              # Configuration file example
├── config-public.txt               # Public environment configuration example
├── config-private.txt.example      # Private environment configuration example
├── .gitignore                      # Git ignore file list
├── index.js                        # Lambda@Edge function code (created during deployment)
├── index.js.template               # Lambda function template
├── package.json                    # Node.js dependency definition
├── setup.sh                        # Integrated installation script (recommended)
├── deploy.sh                       # Lambda deployment script
├── enable-query-string.sh          # Query String activation script
├── configure-cloudfront.sh         # CloudFront configuration script
└── README.md                       # This document
```

### Code Injection System

Since Lambda@Edge doesn't support environment variables, configuration values are directly injected into the code at deployment time:

1. **index.js.template**: Template containing S3 bucket and region as placeholders (`{{S3_BUCKET}}`, `{{S3_REGION}}`)
2. **deploy.sh**: Reads values from config file during deployment and generates `index.js` from template
3. **index.js**: Generated actual Lambda function code (configuration values are hardcoded)

This approach allows using different S3 buckets and regions for each environment.

## Advanced Usage

### Managing Multiple Environments

When managing multiple AWS environments (Production, Development, Public, Private, etc.), you can use different configuration files for each:

```bash
# Deploy Production environment
./setup.sh config-production.txt

# Deploy Development environment
./setup.sh config-development.txt

# Deploy Public CloudFront
./setup.sh config-public.txt

# Deploy Private CloudFront
./setup.sh config-private.txt
```

**It's recommended to set different Lambda function names for each environment:**

```bash
# config-production.txt
LAMBDA_FUNCTION_NAME=image-resizer-production

# config-development.txt
LAMBDA_FUNCTION_NAME=image-resizer-development
```

### Running Individual Scripts

To run individual steps instead of complete installation:

```bash
# Using default configuration file
./deploy.sh
./enable-query-string.sh
./configure-cloudfront.sh

# Using specific configuration file
./deploy.sh config-production.txt
./enable-query-string.sh config-production.txt
./configure-cloudfront.sh config-production.txt
```

### Code Updates

After modifying Lambda function code (`index.js`):

```bash
# Update with default configuration
./deploy.sh
./configure-cloudfront.sh

# Update specific environment only
./deploy.sh config-production.txt
./configure-cloudfront.sh config-production.txt
```

### Check Deployment Status

```bash
# CloudFront deployment status
aws cloudfront get-distribution --id <CLOUDFRONT_ID> --query 'Distribution.Status'

# Lambda function information
aws lambda get-function --function-name {Lambda function name} --region us-east-1
```

### Cache Invalidation

```bash
# Invalidate entire cache
aws cloudfront create-invalidation --distribution-id <CLOUDFRONT_ID> --paths "/*"

# Invalidate specific paths only
aws cloudfront create-invalidation --distribution-id <CLOUDFRONT_ID> --paths "/images/*"
```

## Troubleshooting

### Check Lambda Function Logs

Lambda@Edge logs are stored in CloudWatch Logs in the region where the function was executed.

```bash
# Check logs in us-east-1 region
aws logs tail /aws/lambda/us-east-1.{Lambda function name} --follow --region us-east-1

# Logs from the last 10 minutes
aws logs tail /aws/lambda/us-east-1.{Lambda function name} --since 10m
```

### Common Problem Solutions

**Problem: Image size not changing**
- Clear cache invalidation and browser cache (Ctrl+Shift+R)
- Test with curl: `curl -I "https://your-domain/image.jpg?w=300"`

**Problem: 502 Bad Gateway error**
- Check Lambda logs for errors
- Image size too large (response exceeds 750KB)
- Lambda timeout (30 seconds) exceeded

**Problem: Query String not being forwarded**
- Check if `enable-query-string.sh` was executed
- Verify Cache Policy is properly configured:
  ```bash
  aws cloudfront get-distribution-config --id <CLOUDFRONT_ID> --query 'DistributionConfig.DefaultCacheBehavior.CachePolicyId'
  ```

**Problem: S3 permission error**
- Check if IAM role has S3 read permissions:
  ```bash
  aws iam get-role-policy --role-name {IAM role name} --policy-name S3ReadPolicy
  ```

### CloudWatch Metrics

To monitor Lambda@Edge performance:

```bash
# Lambda execution count
aws cloudwatch get-metric-statistics \
  --namespace AWS/Lambda \
  --metric-name Invocations \
  --dimensions Name=FunctionName,Value={Lambda function name} \
  --start-time 2024-01-01T00:00:00Z \
  --end-time 2024-01-02T00:00:00Z \
  --period 3600 \
  --statistics Sum
```

## Limitations

- **Response Size**: Lambda@Edge has a maximum 1MB response limit (practically ~750KB)
- **Execution Time**: Maximum 30 seconds (configured value)
- **Memory**: 512MB (configured value)
- **Supported Formats**: JPG, PNG, WebP, AVIF, GIF, TIFF
- **Lambda Region**: Must be deployed in us-east-1 (Lambda@Edge requirement)

## Cost Optimization

- **CloudFront Caching**: Identical requests are served from cache without going through Lambda
- **Query Parameters**: Consider pre-generating frequently used sizes and storing them in S3
- **CloudWatch Logs**: Set log retention period to reduce costs
  ```bash
  aws logs put-retention-policy \
    --log-group-name /aws/lambda/us-east-1.{Lambda function name} \
    --retention-in-days 7
  ```
