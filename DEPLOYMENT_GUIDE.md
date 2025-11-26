# Content Marketing Swarm - Production Deployment Guide

This guide provides comprehensive instructions for deploying the Content Marketing Swarm to production.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Pre-Deployment Checklist](#pre-deployment-checklist)
3. [Deployment Steps](#deployment-steps)
4. [Post-Deployment Verification](#post-deployment-verification)
5. [Monitoring and Alerting](#monitoring-and-alerting)
6. [Rollback Procedures](#rollback-procedures)
7. [Troubleshooting](#troubleshooting)

## Prerequisites

### Required Tools

- **AWS CLI** (v2.x or later)
  ```bash
  aws --version
  ```

- **Terraform** (v1.0 or later)
  ```bash
  terraform --version
  ```

- **Docker** (for building backend images)
  ```bash
  docker --version
  ```

- **Node.js** (v18 or later, for frontend build)
  ```bash
  node --version
  ```

- **AgentCore CLI** (for agent deployment)
  ```bash
  pip install bedrock-agentcore-cli
  agentcore --version
  ```

### AWS Permissions

Ensure your AWS credentials have permissions for:
- ECS (Fargate)
- RDS (PostgreSQL)
- S3
- CloudFront
- VPC and networking
- IAM role creation
- CloudWatch
- Bedrock and AgentCore
- ECR (Elastic Container Registry)

### Environment Variables

Set the following environment variables:

```bash
export AWS_REGION=us-east-1
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
export ENVIRONMENT=production
export ALERT_EMAIL=adelanaj@amazon.co.uk
```

## Pre-Deployment Checklist

Before deploying to production, ensure:

- [ ] All tests pass in staging environment
  ```bash
  cd backend
  pytest tests/test_e2e_staging.py -v -m e2e
  pytest tests/test_performance_load.py -v -m load
  ```

- [ ] Infrastructure code is reviewed and approved
  ```bash
  cd infrastructure/terraform/environments/prod
  terraform plan
  ```

- [ ] Database backup is created (if updating existing deployment)
  ```bash
  aws rds create-db-snapshot \
    --db-instance-identifier content-marketing-swarm-db \
    --db-snapshot-identifier pre-deployment-$(date +%Y%m%d-%H%M%S)
  ```

- [ ] Secrets are configured in AWS Secrets Manager
  - Database credentials
  - Social media API keys (LinkedIn, Twitter)
  - Bedrock API keys

- [ ] DNS records are ready (if using custom domain)

- [ ] SSL certificates are provisioned in ACM

- [ ] Monitoring and alerting email is configured

- [ ] Rollback plan is documented

- [ ] Stakeholders are notified of deployment window

## Deployment Steps

### Step 1: Deploy Infrastructure

Deploy AWS infrastructure using Terraform:

```bash
cd infrastructure/terraform/environments/prod

# Initialize Terraform
terraform init

# Review planned changes
terraform plan -out=tfplan

# Apply changes (after review)
terraform apply tfplan

# Save outputs
terraform output > ../../outputs.txt
```

**Expected Duration:** 15-20 minutes

**Key Outputs:**
- ALB DNS name
- RDS endpoint
- S3 bucket names
- CloudFront distribution URL

### Step 2: Run Database Migrations

Apply database schema migrations:

```bash
cd backend

# Set database URL from Terraform output
export DATABASE_URL="postgresql://user:password@<RDS_ENDPOINT>/contentmarketing"

# Run migrations
alembic upgrade head

# Verify migration
alembic current
```

**Expected Duration:** 1-2 minutes

### Step 3: Deploy Backend

Build and deploy the FastAPI backend:

```bash
cd backend

# Build Docker image
docker build -t content-marketing-swarm-backend:latest .

# Tag for ECR
docker tag content-marketing-swarm-backend:latest \
  ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/content-marketing-swarm-backend:latest

# Login to ECR
aws ecr get-login-password --region ${AWS_REGION} | \
  docker login --username AWS --password-stdin \
  ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com

# Push to ECR
docker push ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/content-marketing-swarm-backend:latest

# Update ECS service
aws ecs update-service \
  --cluster content-marketing-swarm-cluster \
  --service content-marketing-swarm-service \
  --force-new-deployment \
  --region ${AWS_REGION}

# Wait for deployment to complete
aws ecs wait services-stable \
  --cluster content-marketing-swarm-cluster \
  --services content-marketing-swarm-service \
  --region ${AWS_REGION}
```

**Expected Duration:** 5-10 minutes

### Step 4: Configure HTTPS on ALB

Enable HTTPS on the Application Load Balancer to allow secure communication:

```bash
cd infrastructure/terraform/environments/prod

# Apply HTTPS configuration
# This creates:
# - ACM certificate for ALB
# - HTTPS listener on port 443
# - HTTP to HTTPS redirect on port 80
# - Security group rule for port 443
terraform apply

# Wait for certificate validation (5-30 minutes)
# Monitor certificate status
ALB_CERT_ARN=$(terraform output -raw acm_certificate_arn)
aws acm describe-certificate \
  --certificate-arn ${ALB_CERT_ARN} \
  --region ${AWS_REGION} \
  --query 'Certificate.Status'

# Wait until status is "ISSUED"
```

**Expected Duration:** 5-30 minutes (certificate validation)

**Verification:**
```bash
# Get ALB DNS name
ALB_DNS=$(terraform output -raw alb_dns_name)

# Test HTTPS endpoint
curl -v https://${ALB_DNS}/health
# Expected: 200 OK with valid TLS handshake

# Test HTTP redirect
curl -v http://${ALB_DNS}/health
# Expected: 301 redirect to HTTPS
```

**Troubleshooting:**
- If certificate validation is stuck, check DNS validation records
- If HTTPS requests fail, verify security group allows port 443
- See "HTTPS Configuration" section below for detailed troubleshooting

### Step 5: Update Frontend Environment Variables

Configure frontend to use custom domain HTTPS endpoints:

```bash
cd frontend

# Update .env.production with custom domain
cat > .env.production << EOF
# Backend API URL (HTTPS with custom domain)
NEXT_PUBLIC_API_URL=https://api.blacksteep.com

# WebSocket URL (WSS with custom domain)
NEXT_PUBLIC_WS_URL=wss://api.blacksteep.com/ws/stream-generation

# CloudFront distribution
NEXT_PUBLIC_CDN_URL=https://d2b386ss3jk33z.cloudfront.net
EOF

# Verify configuration
cat .env.production
```

**Expected Duration:** 1 minute

**Important:** 
- Use custom domain (api.blacksteep.com) instead of ALB DNS name
- Ensure no hardcoded HTTP URLs remain in the code
- Frontend must be rebuilt after changing environment variables

### Step 6: Deploy Frontend

Build and deploy the Next.js frontend with HTTPS configuration:

```bash
cd frontend

# Install dependencies
npm ci

# Build application with production environment variables
npm run build

# Export static files (if using static export)
npm run export

# Get S3 bucket from Terraform
S3_BUCKET=$(cd ../infrastructure/terraform/environments/prod && terraform output -raw s3_frontend_bucket)

# Sync to S3
aws s3 sync out/ s3://${S3_BUCKET}/ --delete --region ${AWS_REGION}

# Get CloudFront distribution ID
CLOUDFRONT_ID=$(cd ../infrastructure/terraform/environments/prod && terraform output -raw cloudfront_distribution_id)

# Invalidate CloudFront cache
aws cloudfront create-invalidation \
  --distribution-id ${CLOUDFRONT_ID} \
  --paths "/*" \
  --region ${AWS_REGION}
```

**Expected Duration:** 5-10 minutes

**Verification:**
```bash
# Get CloudFront URL
CLOUDFRONT_URL=$(cd ../infrastructure/terraform/environments/prod && terraform output -raw cloudfront_url)

# Open in browser and check Network tab
echo "Open: ${CLOUDFRONT_URL}"
# Verify:
# - All API requests use HTTPS
# - WebSocket connections use WSS
# - No mixed content warnings
```

### Step 7: Deploy Agents to AgentCore

Deploy the agent swarm to AgentCore Runtime:

```bash
cd backend

# Package agents
./scripts/package_agents.sh

# Deploy to AgentCore
./scripts/deploy_to_agentcore.sh

# Verify deployment
./scripts/verify_deployment.sh
```

**Expected Duration:** 5-10 minutes

### Step 8: Run Smoke Tests

Verify the deployment with smoke tests:

```bash
cd backend

# Get API endpoint
API_ENDPOINT=$(cd ../infrastructure/terraform/environments/prod && terraform output -raw alb_dns_name)

# Test health endpoint
curl -f http://${API_ENDPOINT}/health

# Test API endpoint
curl -f http://${API_ENDPOINT}/api/health

# Run automated smoke tests
pytest tests/test_e2e_staging.py::TestSystemHealth -v
```

**Expected Duration:** 2-3 minutes

### Automated Deployment (Optional)

Use the automated deployment script:

```bash
cd backend
./scripts/deploy_production.sh
```

This script runs all deployment steps automatically with confirmation prompts.

## Post-Deployment Verification

### 1. Verify Services

Check that all services are running:

```bash
# Check ECS service
aws ecs describe-services \
  --cluster content-marketing-swarm-cluster \
  --services content-marketing-swarm-service \
  --region ${AWS_REGION}

# Check RDS instance
aws rds describe-db-instances \
  --db-instance-identifier content-marketing-swarm-db \
  --region ${AWS_REGION}

# Check AgentCore runtime
agentcore status --runtime content-marketing-swarm
```

### 2. Test Core Functionality

Test key user workflows:

```bash
# Test content generation
curl -X POST http://${API_ENDPOINT}/api/generate-content \
  -H "Content-Type: application/json" \
  -d '{
    "prompt": "Generate LinkedIn post about AI",
    "user_id": "test_user",
    "platforms": ["linkedin"]
  }'

# Test analytics endpoint
curl http://${API_ENDPOINT}/api/analytics?user_id=test_user&date_range=7d
```

### 3. Verify Monitoring

Check that monitoring is working:

```bash
# View CloudWatch dashboard
echo "Dashboard: https://console.aws.amazon.com/cloudwatch/home?region=${AWS_REGION}#dashboards:name=content-marketing-swarm-production"

# Check recent logs
aws logs tail /agentcore/content-marketing-swarm --follow --region ${AWS_REGION}

# Verify X-Ray traces
echo "X-Ray: https://console.aws.amazon.com/xray/home?region=${AWS_REGION}#/traces"
```

### 4. Performance Validation

Run performance tests:

```bash
cd backend
pytest tests/test_performance_load.py::TestConcurrentLoad::test_concurrent_content_generation -v
```

## Monitoring and Alerting

### Setup Monitoring

Configure CloudWatch dashboards and alarms:

```bash
cd backend
export ALERT_EMAIL=adelanaj@amazon.co.uk
./scripts/setup_monitoring.sh
```

This creates:
- CloudWatch dashboard with key metrics
- SNS topic for alerts
- CloudWatch alarms for:
  - High error rate (>5%)
  - High latency (>10s)
  - Low success rate (<90%)
  - ECS high CPU (>80%)
  - ALB 5XX errors
  - RDS high CPU (>80%)
  - RDS low storage (<10GB)

### Access Monitoring

- **CloudWatch Dashboard:** AWS Console > CloudWatch > Dashboards > content-marketing-swarm-production
- **Alarms:** AWS Console > CloudWatch > Alarms
- **Logs:** AWS Console > CloudWatch > Log Groups
- **X-Ray Traces:** AWS Console > X-Ray > Traces
- **AgentCore Metrics:** `agentcore metrics --runtime content-marketing-swarm`

### Alert Notifications

Alerts are sent to the configured email address via SNS. To add additional notification channels:

```bash
# Add Slack webhook
aws sns subscribe \
  --topic-arn <SNS_TOPIC_ARN> \
  --protocol https \
  --notification-endpoint <SLACK_WEBHOOK_URL>

# Add SMS
aws sns subscribe \
  --topic-arn <SNS_TOPIC_ARN> \
  --protocol sms \
  --notification-endpoint +1234567890
```

## Rollback Procedures

### Rollback Backend

If issues are detected, rollback the backend:

```bash
# Get previous task definition
PREVIOUS_TASK_DEF=$(aws ecs describe-services \
  --cluster content-marketing-swarm-cluster \
  --services content-marketing-swarm-service \
  --query 'services[0].deployments[1].taskDefinition' \
  --output text)

# Update service to previous version
aws ecs update-service \
  --cluster content-marketing-swarm-cluster \
  --service content-marketing-swarm-service \
  --task-definition ${PREVIOUS_TASK_DEF} \
  --force-new-deployment
```

### Rollback Frontend

Rollback frontend to previous version:

```bash
# List S3 versions
aws s3api list-object-versions \
  --bucket ${S3_BUCKET} \
  --prefix index.html

# Restore previous version (if versioning enabled)
aws s3api copy-object \
  --bucket ${S3_BUCKET} \
  --copy-source ${S3_BUCKET}/index.html?versionId=<VERSION_ID> \
  --key index.html

# Invalidate CloudFront
aws cloudfront create-invalidation \
  --distribution-id ${CLOUDFRONT_ID} \
  --paths "/*"
```

### Rollback Infrastructure

Rollback Terraform changes:

```bash
cd infrastructure/terraform/environments/prod

# Revert to previous state
terraform apply -target=<resource> -var-file=previous.tfvars
```

### Rollback Database

Restore database from snapshot:

```bash
# List snapshots
aws rds describe-db-snapshots \
  --db-instance-identifier content-marketing-swarm-db

# Restore from snapshot
aws rds restore-db-instance-from-db-snapshot \
  --db-instance-identifier content-marketing-swarm-db-restored \
  --db-snapshot-identifier <SNAPSHOT_ID>
```

## Custom Domain Configuration

### Overview

The application is configured with a custom domain (`api.blacksteep.com`) using AWS Route 53 for DNS management and AWS Certificate Manager (ACM) for SSL/TLS certificates. This provides a professional, branded API endpoint with trusted SSL certificates.

### Current Configuration

- **Custom Domain:** api.blacksteep.com
- **DNS Provider:** AWS Route 53
- **Certificate Provider:** AWS Certificate Manager (ACM)
- **Certificate Issuer:** Amazon RSA 2048 M04
- **Validation Method:** DNS validation (automatic)
- **Certificate Status:** ISSUED
- **Valid Until:** December 24, 2026

### Architecture

```
GoDaddy Domain → Route 53 DNS → ALB (HTTPS) → ECS Fargate
                                  ↓
                            ACM Certificate
                         (Trusted by Browsers)
```

### Setup Process

The custom domain setup involves:

1. **Route 53 Hosted Zone:** Created for blacksteep.com
2. **GoDaddy Name Servers:** Updated to point to Route 53
3. **ACM Certificate:** Issued for api.blacksteep.com with DNS validation
4. **Route 53 A Record:** Points api.blacksteep.com to ALB
5. **ALB HTTPS Listener:** Uses ACM certificate
6. **Frontend Configuration:** Updated to use custom domain

For detailed setup instructions, see `.kiro/specs/custom-domain-migration/`

### Verification

```bash
# Test HTTPS endpoint
curl -s https://api.blacksteep.com/health
# Expected: {"status":"healthy"}

# Verify certificate
openssl s_client -connect api.blacksteep.com:443 -servername api.blacksteep.com </dev/null 2>/dev/null | openssl x509 -noout -subject -issuer
# Expected: Issuer: Amazon RSA 2048 M04

# Test HTTP redirect
curl -I http://api.blacksteep.com/health
# Expected: 301 redirect to HTTPS
```

### Benefits

- ✅ **Trusted Certificate:** No browser warnings
- ✅ **Professional Branding:** Custom domain instead of ALB DNS
- ✅ **Automatic Renewal:** ACM handles certificate renewal
- ✅ **DNS Management:** Route 53 provides reliable DNS
- ✅ **Easy Updates:** Terraform manages all resources

## HTTPS Configuration

### Overview

The Application Load Balancer (ALB) is configured with HTTPS to enable secure communication between the CloudFront-hosted frontend and the backend API. This section provides detailed information about the HTTPS setup process.

### Architecture

```
Frontend (CloudFront HTTPS) → Backend (ALB HTTPS) → ECS Fargate
                                ✅ Secure Communication
```

### Components

1. **ACM Certificate:** SSL/TLS certificate for the ALB domain
2. **HTTPS Listener:** Accepts secure traffic on port 443
3. **HTTP Redirect:** Redirects port 80 traffic to HTTPS
4. **Security Groups:** Allow inbound traffic on port 443

### Setup Process

The HTTPS setup is included in the main Terraform deployment (Step 1), but can also be applied separately:

```bash
cd infrastructure/terraform/environments/prod

# Apply HTTPS configuration only
terraform apply \
  -target=aws_acm_certificate.alb_cert \
  -target=aws_acm_certificate_validation.alb_cert \
  -target=aws_lb_listener.https \
  -target=aws_lb_listener.http_redirect \
  -target=aws_security_group_rule.alb_https_ingress
```

### Certificate Validation

ACM uses DNS validation to verify domain ownership:

1. **Automatic Validation:** For ALB DNS names, validation is automatic
2. **Duration:** 5-30 minutes typically
3. **Status Check:**
   ```bash
   aws acm describe-certificate \
     --certificate-arn <cert-arn> \
     --region ${AWS_REGION} \
     --query 'Certificate.Status'
   ```
4. **Expected Status:** "ISSUED"

### Environment Variable Configuration

Frontend environment variables must use HTTPS/WSS protocols:

**File:** `frontend/.env.production`

```bash
# Backend API URL (HTTPS)
NEXT_PUBLIC_API_URL=https://<alb-dns-name>

# WebSocket URL (WSS)
NEXT_PUBLIC_WS_URL=wss://<alb-dns-name>/ws/stream-generation
```

**Important:**
- Use `https://` for API calls
- Use `wss://` for WebSocket connections
- No trailing slashes on URLs
- Rebuild frontend after changing environment variables

### Verification Steps

#### 1. Test HTTPS Endpoint

```bash
# Get ALB DNS name
ALB_DNS=$(cd infrastructure/terraform/environments/prod && terraform output -raw alb_dns_name)

# Test HTTPS endpoint
curl -v https://${ALB_DNS}/health

# Expected output:
# * TLS handshake successful
# * HTTP/2 200 OK
# * Response body: {"status": "healthy"}
```

#### 2. Test HTTP Redirect

```bash
# Test HTTP redirect
curl -v http://${ALB_DNS}/health

# Expected output:
# * HTTP/1.1 301 Moved Permanently
# * Location: https://<alb-dns-name>/health
```

#### 3. Verify Certificate

```bash
# Check certificate details
openssl s_client -connect ${ALB_DNS}:443 -servername ${ALB_DNS} < /dev/null 2>/dev/null | openssl x509 -noout -text

# Verify:
# - Issuer: Amazon
# - Subject: <alb-dns-name>
# - Validity: Not expired
# - Signature Algorithm: SHA256
```

#### 4. Test Frontend Integration

```bash
# Open frontend in browser
CLOUDFRONT_URL=$(cd infrastructure/terraform/environments/prod && terraform output -raw cloudfront_url)
echo "Open: ${CLOUDFRONT_URL}"

# In browser developer tools (Network tab):
# 1. Generate content
# 2. Verify all API requests use HTTPS
# 3. Verify WebSocket connections use WSS
# 4. Check for no mixed content warnings in Console
```

#### 5. Run Property-Based Tests

```bash
cd backend

# Test HTTPS listener
pytest tests/test_property_https_listener.py -v

# Test HTTP redirect
pytest tests/test_property_http_redirect.py -v

# Test certificate validity
pytest tests/test_property_certificate_validity.py -v

# Test frontend deployment
cd ../frontend
npm test -- __tests__/test_property_frontend_deployment.test.tsx
```

### Troubleshooting HTTPS Issues

#### Issue 1: Certificate Validation Stuck

**Symptom:** ACM certificate remains in "Pending Validation" status for >30 minutes

**Diagnosis:**
```bash
# Check certificate validation details
aws acm describe-certificate \
  --certificate-arn <cert-arn> \
  --region ${AWS_REGION} \
  --query 'Certificate.DomainValidationOptions'
```

**Solutions:**
1. **Wait longer:** DNS validation can take up to 30 minutes
2. **Check DNS records:** Verify validation records are created
3. **Verify domain accessibility:** Ensure domain resolves correctly
4. **Try email validation:** Alternative validation method
5. **Contact AWS Support:** If validation fails after 1 hour

**Prevention:**
- Use ALB DNS name directly (automatic validation)
- Ensure DNS is properly configured for custom domains

#### Issue 2: HTTPS Requests Timeout

**Symptom:** HTTPS requests to ALB timeout or fail to connect

**Diagnosis:**
```bash
# Check security group rules
aws ec2 describe-security-groups \
  --group-ids <alb-security-group-id> \
  --query 'SecurityGroups[0].IpPermissions[?FromPort==`443`]'

# Check listener configuration
aws elbv2 describe-listeners \
  --load-balancer-arn <alb-arn> \
  --query 'Listeners[?Port==`443`]'

# Check target group health
aws elbv2 describe-target-health \
  --target-group-arn <target-group-arn>
```

**Solutions:**
1. **Verify security group:** Ensure port 443 is open
   ```bash
   aws ec2 authorize-security-group-ingress \
     --group-id <alb-security-group-id> \
     --protocol tcp \
     --port 443 \
     --cidr 0.0.0.0/0
   ```
2. **Check certificate attachment:** Verify certificate is attached to listener
3. **Verify target health:** Ensure ECS tasks are healthy
4. **Check ALB state:** Ensure ALB is in "active" state
5. **Review CloudWatch logs:** Check for errors in ALB access logs

**Prevention:**
- Use Terraform to manage security groups
- Test HTTPS endpoint immediately after deployment

#### Issue 3: Mixed Content Warnings

**Symptom:** Browser shows mixed content warnings despite HTTPS setup

**Diagnosis:**
```bash
# Check frontend environment variables
aws s3 cp s3://<frontend-bucket>/_next/static/chunks/main-*.js - | grep -o 'http://[^"]*'

# Should return no results (all should be HTTPS)

# Check deployed environment variables
aws s3 cp s3://<frontend-bucket>/_next/static/chunks/webpack-*.js - | grep NEXT_PUBLIC
```

**Solutions:**
1. **Verify environment variables:** Check `.env.production` uses HTTPS/WSS
2. **Rebuild frontend:** Ensure frontend was rebuilt after updating variables
   ```bash
   cd frontend
   npm run build
   aws s3 sync out/ s3://<frontend-bucket>/ --delete
   ```
3. **Invalidate CloudFront cache:** Clear cached files
   ```bash
   aws cloudfront create-invalidation \
     --distribution-id <dist-id> \
     --paths "/*"
   ```
4. **Check hardcoded URLs:** Search code for hardcoded HTTP URLs
   ```bash
   grep -r "http://" frontend/components/ frontend/app/
   ```
5. **Clear browser cache:** Hard refresh (Ctrl+Shift+R)

**Prevention:**
- Use environment variables for all API URLs
- Never hardcode HTTP URLs in code
- Test in incognito mode after deployment

#### Issue 4: WebSocket Connection Failures

**Symptom:** WebSocket connections fail to establish over WSS

**Diagnosis:**
```bash
# Test WebSocket endpoint
wscat -c wss://${ALB_DNS}/ws/stream-generation

# Check ALB access logs for WebSocket upgrade requests
aws logs tail /aws/elasticloadbalancing/app/<alb-name> --follow
```

**Solutions:**
1. **Verify WSS URL:** Ensure frontend uses `wss://` not `ws://`
2. **Check ALB configuration:** ALB supports WebSocket by default
3. **Verify security groups:** Ensure port 443 allows WebSocket traffic
4. **Check backend WebSocket handler:** Verify backend accepts WebSocket connections
5. **Test with wscat:** Use WebSocket client tool to isolate issue
   ```bash
   npm install -g wscat
   wscat -c wss://${ALB_DNS}/ws/stream-generation
   ```

**Prevention:**
- Use WSS protocol in environment variables
- Test WebSocket connections after HTTPS setup
- Monitor WebSocket connection metrics

#### Issue 5: Certificate Expiration

**Symptom:** Certificate is approaching expiration or has expired

**Diagnosis:**
```bash
# Check certificate expiration date
aws acm describe-certificate \
  --certificate-arn <cert-arn> \
  --region ${AWS_REGION} \
  --query 'Certificate.NotAfter'

# Check renewal status
aws acm describe-certificate \
  --certificate-arn <cert-arn> \
  --region ${AWS_REGION} \
  --query 'Certificate.RenewalSummary'
```

**Solutions:**
1. **Automatic renewal:** ACM renews certificates 60 days before expiration
2. **Check validation records:** Ensure DNS validation records still exist
3. **Verify domain accessibility:** Ensure domain is still accessible
4. **Manual renewal:** Request new certificate if automatic renewal fails
5. **Contact AWS Support:** If renewal issues persist

**Prevention:**
- ACM handles renewal automatically
- Monitor certificate expiration in CloudWatch
- Set up alerts for certificate expiration

### SSL/TLS Configuration

**SSL Policy:** `ELBSecurityPolicy-TLS13-1-2-2021-06`

This policy provides:
- **TLS Versions:** TLS 1.2 and TLS 1.3
- **Cipher Suites:** Strong, modern ciphers
- **Browser Compatibility:** All modern browsers
- **Security:** Balances security and compatibility

**Alternative Policies:**
- `ELBSecurityPolicy-TLS13-1-3-2021-06`: TLS 1.3 only (more secure, less compatible)
- `ELBSecurityPolicy-TLS-1-2-2017-01`: TLS 1.2 only (older, more compatible)

### Performance Considerations

**TLS Handshake Overhead:**
- Initial connection: ~50-100ms additional latency
- Subsequent requests: Minimal overhead (connection reuse)
- HTTP/2: Reduces overhead with multiplexing
- Keep-alive: Reuses connections

**Optimization Tips:**
1. Enable HTTP/2 (enabled by default on ALB)
2. Use connection keep-alive
3. Implement connection pooling in client
4. Monitor TLS handshake time in CloudWatch

### Security Best Practices

1. **Use Strong SSL Policy:** TLS 1.2+ with modern ciphers
2. **Enable HSTS:** Add Strict-Transport-Security header (future enhancement)
3. **Monitor Certificate Expiration:** Set up CloudWatch alarms
4. **Rotate Certificates:** ACM handles automatically
5. **Audit Access Logs:** Review ALB access logs regularly
6. **Use Private Keys Securely:** ACM manages private keys
7. **Enable Certificate Transparency:** ACM logs certificates in CT logs

### Cost

**HTTPS Configuration Costs:**
- ACM Certificate: **$0** (free for AWS services)
- ALB HTTPS Listener: **$0** (no additional cost)
- Data Transfer: **Same as HTTP** (no additional cost)
- CloudWatch Logs: **Minimal increase** (~$0.50/month)

**Total Additional Cost:** ~$0.50/month

### Related Documentation

- **Infrastructure README:** `infrastructure/terraform/README.md` (HTTPS Configuration section)
- **HTTPS Setup Spec:** `.kiro/specs/https-alb-setup/`
- **Domain Strategy:** `.kiro/specs/https-alb-setup/DOMAIN_STRATEGY.md`
- **Quick Reference:** `.kiro/specs/https-alb-setup/QUICK_REFERENCE.md`
- **Property Tests:**
  - `backend/tests/test_property_https_listener.py`
  - `backend/tests/test_property_http_redirect.py`
  - `backend/tests/test_property_certificate_validity.py`
  - `frontend/__tests__/test_property_frontend_deployment.test.tsx`

## Troubleshooting

### Common Issues

#### 1. ECS Tasks Not Starting

**Symptoms:** ECS service shows tasks in PENDING or STOPPED state

**Solutions:**
```bash
# Check task logs
aws ecs describe-tasks \
  --cluster content-marketing-swarm-cluster \
  --tasks <TASK_ARN>

# Check CloudWatch logs
aws logs tail /ecs/content-marketing-swarm --follow

# Verify IAM roles
aws iam get-role --role-name ecsTaskExecutionRole
```

#### 2. Database Connection Failures

**Symptoms:** Application logs show database connection errors

**Solutions:**
```bash
# Verify RDS is available
aws rds describe-db-instances \
  --db-instance-identifier content-marketing-swarm-db

# Check security group rules
aws ec2 describe-security-groups \
  --group-ids <SECURITY_GROUP_ID>

# Test connection from ECS task
aws ecs execute-command \
  --cluster content-marketing-swarm-cluster \
  --task <TASK_ARN> \
  --command "psql -h <RDS_ENDPOINT> -U <USER> -d contentmarketing"
```

#### 3. High Latency

**Symptoms:** Response times exceed SLA

**Solutions:**
```bash
# Check ECS CPU/Memory
aws cloudwatch get-metric-statistics \
  --namespace AWS/ECS \
  --metric-name CPUUtilization \
  --dimensions Name=ServiceName,Value=content-marketing-swarm-service \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average

# Check RDS performance
aws rds describe-db-instances \
  --db-instance-identifier content-marketing-swarm-db \
  --query 'DBInstances[0].DBInstanceStatus'

# Review X-Ray traces for bottlenecks
# Access X-Ray console to identify slow operations
```

#### 4. AgentCore Deployment Failures

**Symptoms:** Agent deployment fails or agents don't respond

**Solutions:**
```bash
# Check AgentCore logs
agentcore logs --runtime content-marketing-swarm --tail 100

# Verify configuration
agentcore describe --runtime content-marketing-swarm

# Check Bedrock permissions
aws bedrock list-foundation-models --region ${AWS_REGION}

# Redeploy agents
cd backend
./scripts/deploy_to_agentcore.sh
```

#### 5. HTTPS Configuration Issues

**Symptoms:** Mixed content errors, certificate validation failures, HTTPS connection issues

**Solutions:**
See the detailed [HTTPS Configuration](#https-configuration) section above for:
- Certificate validation troubleshooting
- HTTPS connection issues
- Mixed content error resolution
- WebSocket connection failures
- Certificate expiration handling

Quick checks:
```bash
# Verify HTTPS endpoint
curl -v https://${ALB_DNS}/health

# Verify HTTP redirect
curl -v http://${ALB_DNS}/health

# Check certificate status
aws acm describe-certificate --certificate-arn <cert-arn> --region ${AWS_REGION}

# Run HTTPS property tests
cd backend
pytest tests/test_property_https_listener.py tests/test_property_http_redirect.py -v
```

### Getting Help

- **AWS Support:** Open a support case in AWS Console
- **AgentCore Documentation:** https://docs.aws.amazon.com/bedrock/agentcore
- **Project Issues:** Check GitHub issues or internal documentation
- **On-Call Team:** Contact via PagerDuty or configured alert system

## Maintenance

### Regular Tasks

- **Weekly:** Review CloudWatch metrics and logs
- **Monthly:** Review and optimize costs
- **Quarterly:** Update dependencies and security patches
- **As Needed:** Scale resources based on usage patterns

### Updates and Patches

For routine updates:

1. Test in staging environment
2. Create database backup
3. Deploy during maintenance window
4. Monitor for issues
5. Rollback if necessary

### Cost Optimization

Monitor and optimize costs:

```bash
# Review AWS Cost Explorer
echo "Cost Explorer: https://console.aws.amazon.com/cost-management/home#/cost-explorer"

# Check resource utilization
aws cloudwatch get-metric-statistics \
  --namespace AWS/ECS \
  --metric-name CPUUtilization \
  --dimensions Name=ServiceName,Value=content-marketing-swarm-service \
  --start-time $(date -u -d '7 days ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 86400 \
  --statistics Average
```

## Security

### Security Best Practices

- Rotate credentials regularly
- Enable MFA for AWS accounts
- Use least-privilege IAM policies
- Enable VPC Flow Logs
- Regular security audits
- Keep dependencies updated
- Monitor for security alerts

### Compliance

Ensure compliance with:
- GDPR (data protection)
- SOC 2 (security controls)
- HIPAA (if handling health data)
- Industry-specific regulations

## Support and Documentation

- **Architecture Diagram:** See `backend/DEPLOYMENT_SUMMARY.md`
- **API Documentation:** See `backend/README.md`
- **Infrastructure Code:** See `infrastructure/terraform/README.md`
- **Monitoring Guide:** See CloudWatch dashboard
- **Runbooks:** See `docs/runbooks/` (if available)

---

**Last Updated:** 2025-11-24
**Version:** 1.0.0
**Maintained By:** DevOps Team
