# Environment Variables Configuration Guide

This guide provides comprehensive information about configuring environment variables for the Content Marketing Swarm application, with a focus on HTTPS configuration.

## Table of Contents

1. [Overview](#overview)
2. [Frontend Environment Variables](#frontend-environment-variables)
3. [Backend Environment Variables](#backend-environment-variables)
4. [HTTPS Configuration](#https-configuration)
5. [Environment-Specific Configuration](#environment-specific-configuration)
6. [Verification](#verification)
7. [Troubleshooting](#troubleshooting)

## Overview

The Content Marketing Swarm application uses environment variables to configure API endpoints, WebSocket URLs, and other runtime settings. Proper configuration is essential for HTTPS communication between the frontend and backend.

### Key Principles

1. **Use HTTPS/WSS protocols** for all production endpoints
2. **Never hardcode URLs** in application code
3. **Use environment-specific files** (.env.development, .env.production)
4. **Rebuild after changes** to embed variables in static files
5. **Verify configuration** before deployment

## Frontend Environment Variables

### File Location

```
frontend/.env.production          # Production environment
frontend/.env.development         # Development environment
frontend/.env.local              # Local overrides (not committed)
```

### Required Variables

#### NEXT_PUBLIC_API_URL

**Purpose:** Backend API base URL for HTTP requests

**Format:** `https://<domain>`

**Examples:**
```bash
# Production (ALB DNS)
NEXT_PUBLIC_API_URL=https://content-marketing-swarm-prod-alb-123456789.us-east-1.elb.amazonaws.com

# Production (Custom Domain)
NEXT_PUBLIC_API_URL=https://api.contentmarketing.com

# Development
NEXT_PUBLIC_API_URL=https://content-marketing-swarm-dev-alb-987654321.us-east-1.elb.amazonaws.com

# Local Development
NEXT_PUBLIC_API_URL=http://localhost:8000
```

**Usage in Code:**
```typescript
// components/ContentGenerationForm.tsx
const API_URL = process.env.NEXT_PUBLIC_API_URL;

const response = await fetch(`${API_URL}/api/generate-content`, {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify(data),
});
```

**Important:**
- Must use `https://` for production (not `http://`)
- No trailing slash
- Must be prefixed with `NEXT_PUBLIC_` to be accessible in browser
- Embedded in static files at build time

#### NEXT_PUBLIC_WS_URL

**Purpose:** WebSocket URL for real-time streaming

**Format:** `wss://<domain>/ws/<endpoint>`

**Examples:**
```bash
# Production (ALB DNS)
NEXT_PUBLIC_WS_URL=wss://content-marketing-swarm-prod-alb-123456789.us-east-1.elb.amazonaws.com/ws/stream-generation

# Production (Custom Domain)
NEXT_PUBLIC_WS_URL=wss://api.contentmarketing.com/ws/stream-generation

# Development
NEXT_PUBLIC_WS_URL=wss://content-marketing-swarm-dev-alb-987654321.us-east-1.elb.amazonaws.com/ws/stream-generation

# Local Development
NEXT_PUBLIC_WS_URL=ws://localhost:8000/ws/stream-generation
```

**Usage in Code:**
```typescript
// hooks/useWebSocket.ts
const WS_URL = process.env.NEXT_PUBLIC_WS_URL;

const socket = new WebSocket(WS_URL);
socket.onopen = () => console.log('Connected');
socket.onmessage = (event) => handleMessage(event.data);
```

**Important:**
- Must use `wss://` for production (not `ws://`)
- Include full path to WebSocket endpoint
- Must be prefixed with `NEXT_PUBLIC_`
- WebSocket connections require HTTPS on frontend

### Complete Frontend Configuration

**Production (.env.production):**
```bash
# Backend API URL (HTTPS)
NEXT_PUBLIC_API_URL=https://content-marketing-swarm-prod-alb-123456789.us-east-1.elb.amazonaws.com

# WebSocket URL (WSS)
NEXT_PUBLIC_WS_URL=wss://content-marketing-swarm-prod-alb-123456789.us-east-1.elb.amazonaws.com/ws/stream-generation
```

**Development (.env.development):**
```bash
# Backend API URL (HTTPS)
NEXT_PUBLIC_API_URL=https://content-marketing-swarm-dev-alb-987654321.us-east-1.elb.amazonaws.com

# WebSocket URL (WSS)
NEXT_PUBLIC_WS_URL=wss://content-marketing-swarm-dev-alb-987654321.us-east-1.elb.amazonaws.com/ws/stream-generation
```

**Local Development (.env.local):**
```bash
# Backend API URL (HTTP for local)
NEXT_PUBLIC_API_URL=http://localhost:8000

# WebSocket URL (WS for local)
NEXT_PUBLIC_WS_URL=ws://localhost:8000/ws/stream-generation
```

## Backend Environment Variables

### File Location

```
backend/.env                     # All environments (not committed)
backend/.env.example            # Template file (committed)
```

### Required Variables

#### DATABASE_URL

**Purpose:** PostgreSQL database connection string

**Format:** `postgresql://<user>:<password>@<host>:<port>/<database>`

**Example:**
```bash
DATABASE_URL=postgresql://admin:password@content-marketing-swarm-db.abc123.us-east-1.rds.amazonaws.com:5432/contentmarketing
```

#### AWS_REGION

**Purpose:** AWS region for Bedrock and other services

**Example:**
```bash
AWS_REGION=us-east-1
```

#### BEDROCK_MODEL_ID

**Purpose:** Bedrock model identifier for content generation

**Example:**
```bash
BEDROCK_MODEL_ID=anthropic.claude-3-sonnet-20240229-v1:0
```

#### CORS_ORIGINS

**Purpose:** Allowed origins for CORS (must include CloudFront URL)

**Example:**
```bash
CORS_ORIGINS=https://d1234567890abc.cloudfront.net,https://contentmarketing.com
```

### Complete Backend Configuration

**Production (.env):**
```bash
# Database
DATABASE_URL=postgresql://admin:${DB_PASSWORD}@content-marketing-swarm-prod-db.abc123.us-east-1.rds.amazonaws.com:5432/contentmarketing

# AWS Configuration
AWS_REGION=us-east-1
AWS_ACCOUNT_ID=123456789012

# Bedrock
BEDROCK_MODEL_ID=anthropic.claude-3-sonnet-20240229-v1:0

# CORS
CORS_ORIGINS=https://d1234567890abc.cloudfront.net

# AgentCore
AGENTCORE_RUNTIME_NAME=content-marketing-swarm-prod

# Monitoring
LOG_LEVEL=INFO
ENABLE_XRAY=true
```

## HTTPS Configuration

### Getting ALB DNS Name

The ALB DNS name is required for frontend environment variables:

```bash
# From Terraform
cd infrastructure/terraform/environments/prod
terraform output alb_dns_name

# From AWS CLI
aws elbv2 describe-load-balancers \
  --names content-marketing-swarm-prod-alb \
  --query 'LoadBalancers[0].DNSName' \
  --output text
```

### Configuring Frontend for HTTPS

**Step 1: Get ALB DNS Name**
```bash
cd infrastructure/terraform/environments/prod
export ALB_DNS=$(terraform output -raw alb_dns_name)
echo "ALB DNS: ${ALB_DNS}"
```

**Step 2: Update Frontend Environment File**
```bash
cd ../../frontend

# Create/update .env.production
cat > .env.production << EOF
# Backend API URL (HTTPS)
NEXT_PUBLIC_API_URL=https://${ALB_DNS}

# WebSocket URL (WSS)
NEXT_PUBLIC_WS_URL=wss://${ALB_DNS}/ws/stream-generation
EOF

# Verify
cat .env.production
```

**Step 3: Rebuild Frontend**
```bash
# Clean previous build
rm -rf .next out

# Install dependencies
npm ci

# Build with production environment
npm run build

# Verify HTTPS URLs in build
grep -r "https://${ALB_DNS}" out/ | head -5
```

**Step 4: Deploy**
```bash
# Get S3 bucket
S3_BUCKET=$(cd ../infrastructure/terraform/environments/prod && terraform output -raw s3_frontend_bucket)

# Sync to S3
aws s3 sync out/ s3://${S3_BUCKET}/ --delete

# Invalidate CloudFront cache
CLOUDFRONT_ID=$(cd ../infrastructure/terraform/environments/prod && terraform output -raw cloudfront_distribution_id)
aws cloudfront create-invalidation --distribution-id ${CLOUDFRONT_ID} --paths "/*"
```

### Protocol Requirements

| Environment | API Protocol | WebSocket Protocol | Notes |
|-------------|--------------|-------------------|-------|
| Production  | `https://`   | `wss://`          | Required for CloudFront frontend |
| Development | `https://`   | `wss://`          | Recommended |
| Local       | `http://`    | `ws://`           | OK for localhost only |

**Important:**
- Production frontend (CloudFront HTTPS) **requires** backend HTTPS
- Mixed content (HTTPS → HTTP) is blocked by browsers
- WebSocket over HTTPS requires WSS protocol

## Environment-Specific Configuration

### Production Environment

**Characteristics:**
- HTTPS/WSS required
- CloudFront frontend
- ALB with ACM certificate
- RDS Multi-AZ database
- AgentCore Runtime

**Configuration:**
```bash
# Frontend (.env.production)
NEXT_PUBLIC_API_URL=https://content-marketing-swarm-prod-alb-123456789.us-east-1.elb.amazonaws.com
NEXT_PUBLIC_WS_URL=wss://content-marketing-swarm-prod-alb-123456789.us-east-1.elb.amazonaws.com/ws/stream-generation

# Backend (.env)
DATABASE_URL=postgresql://admin:${DB_PASSWORD}@prod-db.abc123.us-east-1.rds.amazonaws.com:5432/contentmarketing
AWS_REGION=us-east-1
BEDROCK_MODEL_ID=anthropic.claude-3-sonnet-20240229-v1:0
CORS_ORIGINS=https://d1234567890abc.cloudfront.net
LOG_LEVEL=INFO
```

### Development Environment

**Characteristics:**
- HTTPS/WSS recommended
- CloudFront frontend
- ALB with ACM certificate
- RDS Single-AZ database
- AgentCore Runtime

**Configuration:**
```bash
# Frontend (.env.development)
NEXT_PUBLIC_API_URL=https://content-marketing-swarm-dev-alb-987654321.us-east-1.elb.amazonaws.com
NEXT_PUBLIC_WS_URL=wss://content-marketing-swarm-dev-alb-987654321.us-east-1.elb.amazonaws.com/ws/stream-generation

# Backend (.env)
DATABASE_URL=postgresql://admin:${DB_PASSWORD}@dev-db.xyz789.us-east-1.rds.amazonaws.com:5432/contentmarketing
AWS_REGION=us-east-1
BEDROCK_MODEL_ID=anthropic.claude-3-sonnet-20240229-v1:0
CORS_ORIGINS=https://d0987654321xyz.cloudfront.net
LOG_LEVEL=DEBUG
```

### Local Development Environment

**Characteristics:**
- HTTP/WS acceptable
- Local Next.js dev server
- Local backend server
- Local PostgreSQL or RDS
- No AgentCore (optional)

**Configuration:**
```bash
# Frontend (.env.local)
NEXT_PUBLIC_API_URL=http://localhost:8000
NEXT_PUBLIC_WS_URL=ws://localhost:8000/ws/stream-generation

# Backend (.env)
DATABASE_URL=postgresql://postgres:postgres@localhost:5432/contentmarketing
AWS_REGION=us-east-1
BEDROCK_MODEL_ID=anthropic.claude-3-sonnet-20240229-v1:0
CORS_ORIGINS=http://localhost:3000
LOG_LEVEL=DEBUG
```

## Verification

### Verify Frontend Configuration

**Check Environment File:**
```bash
cd frontend
cat .env.production

# Should show:
# NEXT_PUBLIC_API_URL=https://...
# NEXT_PUBLIC_WS_URL=wss://...
```

**Check Build Output:**
```bash
# After building
grep -r "NEXT_PUBLIC_API_URL" out/_next/static/chunks/ | head -1

# Should show HTTPS URL
```

**Check Deployed Files:**
```bash
# Get S3 bucket
S3_BUCKET=$(cd ../infrastructure/terraform/environments/prod && terraform output -raw s3_frontend_bucket)

# Download and check main chunk
aws s3 cp s3://${S3_BUCKET}/_next/static/chunks/main-*.js - | grep -o "https://[^\"]*" | head -5

# Should show HTTPS URLs
```

**Test in Browser:**
```bash
# Get CloudFront URL
CLOUDFRONT_URL=$(cd ../infrastructure/terraform/environments/prod && terraform output -raw cloudfront_url)
echo "Open: ${CLOUDFRONT_URL}"

# In browser:
# 1. Open developer tools (F12)
# 2. Go to Network tab
# 3. Generate content
# 4. Verify all requests use HTTPS
# 5. Check Console for no mixed content warnings
```

### Verify Backend Configuration

**Check Environment File:**
```bash
cd backend
cat .env | grep -v PASSWORD

# Should show correct values
```

**Test Database Connection:**
```bash
# Test connection
python -c "
from app.database import engine
from sqlalchemy import text
with engine.connect() as conn:
    result = conn.execute(text('SELECT 1'))
    print('Database connection successful')
"
```

**Test API Endpoint:**
```bash
# Get ALB DNS
ALB_DNS=$(cd ../infrastructure/terraform/environments/prod && terraform output -raw alb_dns_name)

# Test health endpoint
curl https://${ALB_DNS}/health

# Should return: {"status": "healthy"}
```

### Run Property-Based Tests

**Frontend Tests:**
```bash
cd frontend
npm test -- __tests__/test_property_frontend_deployment.test.tsx

# Should verify:
# - HTTPS protocol usage
# - WSS protocol usage
# - No mixed content
```

**Backend Tests:**
```bash
cd backend
pytest tests/test_property_https_listener.py -v
pytest tests/test_property_http_redirect.py -v

# Should verify:
# - HTTPS listener responds
# - HTTP redirects to HTTPS
```

## Troubleshooting

### Issue: Environment Variables Not Loaded

**Symptom:** Application uses default URLs instead of configured values

**Solutions:**

1. **Verify file exists:**
   ```bash
   cd frontend
   ls -la .env.production
   ```

2. **Check variable names:**
   - Must be prefixed with `NEXT_PUBLIC_` for frontend
   - Must match exactly in code

3. **Rebuild application:**
   ```bash
   rm -rf .next out
   npm run build
   ```

4. **Verify in build:**
   ```bash
   grep -r "NEXT_PUBLIC" out/_next/static/chunks/ | head -5
   ```

### Issue: Mixed Content Errors

**Symptom:** Browser blocks HTTP requests from HTTPS page

**Solutions:**

1. **Check protocols:**
   ```bash
   cat frontend/.env.production
   # Must use https:// and wss://
   ```

2. **Rebuild and redeploy:**
   ```bash
   cd frontend
   npm run build
   aws s3 sync out/ s3://${S3_BUCKET}/ --delete
   aws cloudfront create-invalidation --distribution-id ${CLOUDFRONT_ID} --paths "/*"
   ```

3. **Clear browser cache:**
   - Hard refresh: Ctrl+Shift+R
   - Test in incognito mode

### Issue: WebSocket Connection Fails

**Symptom:** WebSocket connections fail to establish

**Solutions:**

1. **Verify WSS protocol:**
   ```bash
   cat frontend/.env.production | grep WS_URL
   # Must use wss:// not ws://
   ```

2. **Test WebSocket endpoint:**
   ```bash
   npm install -g wscat
   wscat -c wss://${ALB_DNS}/ws/stream-generation
   ```

3. **Check backend logs:**
   ```bash
   aws logs tail /ecs/content-marketing-swarm --follow --filter-pattern "websocket"
   ```

### Issue: Variables Not Updated After Change

**Symptom:** Changes to environment variables don't take effect

**Solutions:**

1. **Rebuild frontend:**
   ```bash
   cd frontend
   rm -rf .next out node_modules/.cache
   npm run build
   ```

2. **Redeploy to S3:**
   ```bash
   aws s3 sync out/ s3://${S3_BUCKET}/ --delete
   ```

3. **Invalidate CloudFront:**
   ```bash
   aws cloudfront create-invalidation --distribution-id ${CLOUDFRONT_ID} --paths "/*"
   ```

4. **Wait for invalidation:**
   ```bash
   # Can take 5-15 minutes
   aws cloudfront wait invalidation-completed --distribution-id ${CLOUDFRONT_ID} --id <INVALIDATION_ID>
   ```

## Best Practices

1. **Use Environment Variables:**
   - Never hardcode URLs in code
   - Use environment variables for all configuration
   - Keep sensitive values in AWS Secrets Manager

2. **Separate Environments:**
   - Use different files for each environment
   - Never commit .env.local or .env with secrets
   - Use .env.example as template

3. **HTTPS in Production:**
   - Always use HTTPS/WSS in production
   - Test HTTPS configuration before deployment
   - Monitor for mixed content errors

4. **Rebuild After Changes:**
   - Always rebuild frontend after changing variables
   - Verify variables in build output
   - Invalidate CloudFront cache after deployment

5. **Version Control:**
   - Commit .env.example (without secrets)
   - Add .env to .gitignore
   - Document required variables in README

6. **Security:**
   - Never commit secrets to version control
   - Use AWS Secrets Manager for sensitive values
   - Rotate credentials regularly
   - Use least-privilege IAM policies

## Related Documentation

- **Deployment Guide:** `DEPLOYMENT_GUIDE.md`
- **HTTPS Troubleshooting:** `HTTPS_TROUBLESHOOTING_GUIDE.md`
- **Infrastructure README:** `infrastructure/terraform/README.md`
- **HTTPS Setup Spec:** `.kiro/specs/https-alb-setup/`

---

**Last Updated:** 2025-11-25
**Version:** 1.0.0
**Maintained By:** DevOps Team
