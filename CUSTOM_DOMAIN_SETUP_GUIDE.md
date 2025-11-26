# Custom Domain Setup Guide

**Domain:** api.blacksteep.com  
**Status:** ✅ Active  
**Last Updated:** November 25, 2025

---

## Table of Contents

1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Prerequisites](#prerequisites)
4. [Setup Process](#setup-process)
5. [DNS Configuration](#dns-configuration)
6. [Certificate Management](#certificate-management)
7. [Verification](#verification)
8. [Rollback Procedures](#rollback-procedures)
9. [Troubleshooting](#troubleshooting)
10. [Maintenance](#maintenance)

---

## Overview

The Content Marketing Swarm API uses a custom domain (`api.blacksteep.com`) instead of the default AWS Application Load Balancer DNS name. This provides:

- **Professional Branding:** Custom domain instead of AWS-generated name
- **Trusted SSL Certificate:** Amazon-issued certificate trusted by all browsers
- **Simplified Configuration:** Single domain for all environments
- **Automatic Certificate Renewal:** ACM handles certificate lifecycle
- **DNS Management:** Route 53 provides reliable, scalable DNS

### Key Components

| Component | Service | Purpose |
|-----------|---------|---------|
| Domain Registrar | GoDaddy | Domain ownership and registration |
| DNS Management | AWS Route 53 | DNS hosting and record management |
| SSL Certificate | AWS ACM | SSL/TLS certificate provisioning |
| Load Balancer | AWS ALB | HTTPS termination and routing |
| Infrastructure | Terraform | Infrastructure as Code management |

---

## Architecture

### DNS Flow

```
User Request
    ↓
api.blacksteep.com (DNS Query)
    ↓
GoDaddy Name Servers
    ↓
Route 53 Name Servers
    ↓
Route 53 A Record (Alias)
    ↓
Application Load Balancer
    ↓
ECS Fargate Tasks
```

### Certificate Flow

```
ACM Certificate Request
    ↓
DNS Validation Record (Route 53)
    ↓
ACM Validates Ownership
    ↓
Certificate Issued
    ↓
ALB HTTPS Listener
    ↓
Trusted Connection
```

### Infrastructure Components

```
┌─────────────────────────────────────────────────────────────┐
│                        GoDaddy                              │
│                   (Domain Registrar)                        │
│                                                             │
│  Domain: blacksteep.com                                     │
│  Name Servers: Route 53 NS records                          │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│                     AWS Route 53                            │
│                   (DNS Management)                          │
│                                                             │
│  Hosted Zone: blacksteep.com                                │
│  A Record: api.blacksteep.com → ALB                         │
│  Validation Records: ACM DNS validation                     │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│                  AWS Certificate Manager                    │
│                  (SSL/TLS Certificates)                     │
│                                                             │
│  Certificate: api.blacksteep.com                            │
│  Validation: DNS (automatic)                                │
│  Issuer: Amazon RSA 2048 M04                                │
│  Auto-Renewal: Enabled                                      │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│              Application Load Balancer                      │
│                   (HTTPS Termination)                       │
│                                                             │
│  HTTPS Listener: Port 443 (ACM Certificate)                 │
│  HTTP Listener: Port 80 (Redirect to HTTPS)                 │
│  Target: ECS Service                                        │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│                      ECS Fargate                            │
│                   (Application Runtime)                     │
│                                                             │
│  Service: content-marketing-swarm-service                   │
│  Tasks: FastAPI backend containers                          │
└─────────────────────────────────────────────────────────────┘
```

---

## Prerequisites

### Required Access

- **GoDaddy Account:** Access to domain management
- **AWS Account:** Permissions for Route 53, ACM, ALB, and Terraform
- **Terraform:** Version 1.0 or later
- **AWS CLI:** Version 2.x or later

### Required Permissions

AWS IAM permissions needed:
- `route53:*` - DNS management
- `acm:*` - Certificate management
- `elasticloadbalancing:*` - ALB configuration
- `ec2:DescribeSecurityGroups` - Security group access

### Domain Requirements

- Domain registered with GoDaddy (or other registrar)
- Ability to update name servers
- No conflicting DNS records

---

## Setup Process

### Step 1: Create Route 53 Hosted Zone

Create a hosted zone for your domain in Route 53:

```bash
cd infrastructure/terraform/environments/dev

# Add to terraform.tfvars
cat >> terraform.tfvars << EOF

# Custom domain configuration
use_custom_domain = true
custom_domain     = "blacksteep.com"
api_subdomain     = "api"
EOF

# Apply Terraform
terraform init
terraform plan
terraform apply

# Get name servers
terraform output route53_name_servers
```

**Output:**
```
route53_name_servers = [
  "ns-1269.awsdns-30.org",
  "ns-1618.awsdns-10.co.uk",
  "ns-320.awsdns-40.com",
  "ns-584.awsdns-09.net",
]
```

### Step 2: Update GoDaddy Name Servers

Update your domain's name servers in GoDaddy:

1. **Log into GoDaddy:** https://dcc.godaddy.com/
2. **Navigate to Domain Settings:**
   - Click on your domain (blacksteep.com)
   - Scroll to "Additional Settings"
   - Click "Manage DNS"
3. **Update Name Servers:**
   - Click "Change" next to "Nameservers"
   - Select "I'll use my own nameservers"
   - Enter the 4 Route 53 name servers from Step 1
   - Click "Save"

**Important:** DNS propagation can take 1-48 hours, but typically completes in 1-2 hours.

### Step 3: Verify DNS Propagation

Wait for DNS propagation and verify:

```bash
# Check name servers
dig blacksteep.com NS +short

# Expected output: Route 53 name servers
# ns-1269.awsdns-30.org.
# ns-1618.awsdns-10.co.uk.
# ns-320.awsdns-40.com.
# ns-584.awsdns-09.net.

# Check global propagation
# Visit: https://www.whatsmydns.net/#NS/blacksteep.com
```

**Wait until:** All or most DNS servers show Route 53 name servers.

### Step 4: Apply Terraform Configuration

Once DNS propagation is complete, Terraform will automatically:
- Create ACM certificate for api.blacksteep.com
- Add DNS validation records to Route 53
- Wait for certificate validation
- Create Route 53 A record pointing to ALB
- Update ALB HTTPS listener with ACM certificate

```bash
cd infrastructure/terraform/environments/dev

# Apply full configuration
terraform apply

# Monitor certificate validation
watch -n 10 'aws acm describe-certificate \
  --certificate-arn $(terraform output -raw acm_certificate_arn) \
  --region us-east-1 \
  --query "Certificate.Status" \
  --output text'

# Wait for status: ISSUED
```

**Duration:** 5-30 minutes for certificate validation

### Step 5: Update Frontend Configuration

Update frontend environment variables to use custom domain:

```bash
cd frontend

# Update .env.production
cat > .env.production << EOF
# Backend API URL (HTTPS with custom domain)
NEXT_PUBLIC_API_URL=https://api.blacksteep.com

# WebSocket URL (WSS with custom domain)
NEXT_PUBLIC_WS_URL=wss://api.blacksteep.com/ws/stream-generation

# CloudFront distribution
NEXT_PUBLIC_CDN_URL=https://d2b386ss3jk33z.cloudfront.net
EOF

# Rebuild frontend
npm run build

# Deploy to S3
aws s3 sync out/ s3://$(cd ../infrastructure/terraform/environments/dev && terraform output -raw s3_frontend_bucket)/ --delete

# Invalidate CloudFront cache
aws cloudfront create-invalidation \
  --distribution-id $(cd ../infrastructure/terraform/environments/dev && terraform output -raw cloudfront_distribution_id) \
  --paths "/*"
```

### Step 6: Verify Setup

Run comprehensive verification:

```bash
# Test HTTPS endpoint
curl -s https://api.blacksteep.com/health
# Expected: {"status":"healthy"}

# Test HTTP redirect
curl -I http://api.blacksteep.com/health
# Expected: 301 redirect to HTTPS

# Verify certificate
openssl s_client -connect api.blacksteep.com:443 -servername api.blacksteep.com </dev/null 2>/dev/null | openssl x509 -noout -subject -issuer
# Expected: Issuer: Amazon RSA 2048 M04

# Run automated tests
python3 verify_custom_domain_e2e.py
```

---

## DNS Configuration

### Route 53 Hosted Zone

**Hosted Zone ID:** (from Terraform output)  
**Domain:** blacksteep.com  
**Name Servers:** 4 AWS name servers

### DNS Records

| Record Type | Name | Value | Purpose |
|-------------|------|-------|---------|
| NS | blacksteep.com | Route 53 name servers | DNS delegation |
| SOA | blacksteep.com | Route 53 SOA record | Zone authority |
| A (Alias) | api.blacksteep.com | ALB DNS name | API endpoint |
| CNAME | _validation.api.blacksteep.com | ACM validation | Certificate validation |

### DNS Propagation

**Check Propagation:**
```bash
# Local check
dig api.blacksteep.com +short

# Global check
# Visit: https://www.whatsmydns.net/#A/api.blacksteep.com
```

**Typical Propagation Times:**
- Local ISP: 5-30 minutes
- Global: 1-2 hours
- Maximum: 48 hours (rare)

### DNS Management

All DNS records are managed by Terraform:

```hcl
# Route 53 Hosted Zone
resource "aws_route53_zone" "main" {
  name = var.custom_domain
}

# A Record (Alias to ALB)
resource "aws_route53_record" "api" {
  zone_id = aws_route53_zone.main.zone_id
  name    = "${var.api_subdomain}.${var.custom_domain}"
  type    = "A"

  alias {
    name                   = aws_lb.main.dns_name
    zone_id                = aws_lb.main.zone_id
    evaluate_target_health = true
  }
}
```

---

## Certificate Management

### ACM Certificate Details

**Certificate ARN:** (from Terraform output)  
**Domain:** api.blacksteep.com  
**Validation Method:** DNS (automatic)  
**Issuer:** Amazon RSA 2048 M04  
**Status:** ISSUED  
**Valid From:** November 25, 2025  
**Valid Until:** December 24, 2026  

### Certificate Validation

ACM uses DNS validation to verify domain ownership:

1. **Validation Record Created:** Terraform creates CNAME record in Route 53
2. **ACM Validates:** ACM checks for validation record
3. **Certificate Issued:** Certificate becomes available (5-30 minutes)
4. **Auto-Renewal:** ACM renews 60 days before expiration

**Check Certificate Status:**
```bash
aws acm describe-certificate \
  --certificate-arn $(cd infrastructure/terraform/environments/dev && terraform output -raw acm_certificate_arn) \
  --region us-east-1 \
  --query 'Certificate.Status' \
  --output text
```

### Certificate Renewal

**Automatic Renewal:**
- ACM automatically renews certificates 60 days before expiration
- DNS validation records must remain in Route 53
- No manual intervention required

**Monitoring Renewal:**
```bash
# Check renewal status
aws acm describe-certificate \
  --certificate-arn <cert-arn> \
  --region us-east-1 \
  --query 'Certificate.RenewalSummary'
```

### Certificate Trust Chain

```
Root CA: Amazon Root CA 1
    ↓
Intermediate CA: Amazon RSA 2048 M04
    ↓
Certificate: api.blacksteep.com
```

**Trusted By:**
- All major browsers (Chrome, Firefox, Safari, Edge)
- All major operating systems (Windows, macOS, Linux, iOS, Android)
- All programming languages and HTTP clients

---

## Verification

### Automated Verification

Run the comprehensive verification script:

```bash
python3 verify_custom_domain_e2e.py
```

**Tests:**
1. DNS resolution
2. HTTPS endpoint accessibility
3. HTTP to HTTPS redirect
4. SSL certificate trust
5. API documentation accessibility

### Manual Verification

#### 1. DNS Resolution

```bash
# Resolve domain to IP
dig api.blacksteep.com +short
# Expected: ALB IP addresses (2 IPs for high availability)

# Check name servers
dig blacksteep.com NS +short
# Expected: Route 53 name servers
```

#### 2. HTTPS Endpoint

```bash
# Test health endpoint
curl -v https://api.blacksteep.com/health

# Expected output:
# * TLS handshake successful
# * HTTP/2 200 OK
# * {"status":"healthy"}
```

#### 3. HTTP Redirect

```bash
# Test redirect
curl -I http://api.blacksteep.com/health

# Expected output:
# HTTP/1.1 301 Moved Permanently
# Location: https://api.blacksteep.com:443/health
```

#### 4. Certificate Verification

```bash
# Check certificate details
openssl s_client -connect api.blacksteep.com:443 -servername api.blacksteep.com </dev/null 2>/dev/null | openssl x509 -noout -text

# Verify:
# - Subject: CN=api.blacksteep.com
# - Issuer: Amazon RSA 2048 M04
# - Validity: Not expired
# - Signature Algorithm: SHA256
```

#### 5. Browser Testing

1. Open https://api.blacksteep.com/docs in browser
2. Check for:
   - ✅ Secure padlock icon in address bar
   - ✅ No certificate warnings
   - ✅ Certificate details show Amazon as issuer
   - ✅ API documentation loads correctly

### Property-Based Tests

Run property-based tests for comprehensive validation:

```bash
cd backend

# Test HTTPS functionality
pytest tests/test_property_custom_domain_https.py -v

# Test HTTP redirect
pytest tests/test_property_custom_domain_redirect.py -v

# Test certificate trust
pytest tests/test_property_custom_domain_certificate_trust.py -v
```

---

## Rollback Procedures

### Rollback to ALB DNS Name

If issues occur, rollback to using ALB DNS name:

#### Step 1: Update Frontend Environment Variables

```bash
cd frontend

# Get ALB DNS name
ALB_DNS=$(cd ../infrastructure/terraform/environments/dev && terraform output -raw alb_dns_name)

# Update .env.production
cat > .env.production << EOF
# Backend API URL (HTTPS with ALB DNS)
NEXT_PUBLIC_API_URL=https://${ALB_DNS}

# WebSocket URL (WSS with ALB DNS)
NEXT_PUBLIC_WS_URL=wss://${ALB_DNS}/ws/stream-generation
EOF

# Rebuild and deploy
npm run build
aws s3 sync out/ s3://$(cd ../infrastructure/terraform/environments/dev && terraform output -raw s3_frontend_bucket)/ --delete
aws cloudfront create-invalidation --distribution-id $(cd ../infrastructure/terraform/environments/dev && terraform output -raw cloudfront_distribution_id) --paths "/*"
```

#### Step 2: Revert Terraform Configuration (Optional)

```bash
cd infrastructure/terraform/environments/dev

# Set use_custom_domain to false
# Edit terraform.tfvars:
use_custom_domain = false

# Apply changes
terraform apply
```

**Note:** This will remove the custom domain configuration but keep the Route 53 hosted zone.

### Rollback DNS to GoDaddy

To completely revert DNS management to GoDaddy:

1. **Log into GoDaddy**
2. **Navigate to Domain Settings**
3. **Update Name Servers:**
   - Select "Use GoDaddy nameservers"
   - Click "Save"
4. **Wait for DNS Propagation:** 1-48 hours

---

## Troubleshooting

### Issue 1: DNS Not Resolving

**Symptom:** `dig api.blacksteep.com` returns no results

**Diagnosis:**
```bash
# Check name servers
dig blacksteep.com NS +short

# Check Route 53 records
aws route53 list-resource-record-sets \
  --hosted-zone-id $(cd infrastructure/terraform/environments/dev && terraform output -raw route53_zone_id)
```

**Solutions:**
1. Verify GoDaddy name servers are updated
2. Wait for DNS propagation (up to 48 hours)
3. Check Route 53 A record exists
4. Verify Terraform applied successfully

### Issue 2: Certificate Validation Stuck

**Symptom:** ACM certificate remains in "Pending Validation" status

**Diagnosis:**
```bash
# Check certificate status
aws acm describe-certificate \
  --certificate-arn $(cd infrastructure/terraform/environments/dev && terraform output -raw acm_certificate_arn) \
  --region us-east-1 \
  --query 'Certificate.DomainValidationOptions'
```

**Solutions:**
1. Verify DNS propagation is complete
2. Check validation CNAME record exists in Route 53
3. Wait longer (can take up to 30 minutes)
4. Verify Route 53 hosted zone is authoritative

### Issue 3: HTTPS Connection Fails

**Symptom:** `curl https://api.blacksteep.com/health` fails or times out

**Diagnosis:**
```bash
# Check ALB listener
aws elbv2 describe-listeners \
  --load-balancer-arn $(cd infrastructure/terraform/environments/dev && terraform output -raw alb_arn) \
  --query 'Listeners[?Port==`443`]'

# Check security group
aws ec2 describe-security-groups \
  --group-ids $(cd infrastructure/terraform/environments/dev && terraform output -raw alb_security_group_id) \
  --query 'SecurityGroups[0].IpPermissions[?FromPort==`443`]'
```

**Solutions:**
1. Verify certificate is attached to ALB listener
2. Check security group allows port 443
3. Verify ALB is in "active" state
4. Check target group health

### Issue 4: Browser Certificate Warnings

**Symptom:** Browser shows "Not Secure" or certificate warnings

**Diagnosis:**
```bash
# Check certificate details
openssl s_client -connect api.blacksteep.com:443 -servername api.blacksteep.com </dev/null 2>/dev/null | openssl x509 -noout -subject -issuer -dates
```

**Solutions:**
1. Verify certificate is issued by Amazon
2. Check certificate is not expired
3. Verify domain name matches certificate
4. Clear browser cache
5. Check system date/time is correct

### Issue 5: Frontend Still Using Old Domain

**Symptom:** Frontend makes requests to ALB DNS name instead of custom domain

**Diagnosis:**
```bash
# Check deployed environment variables
aws s3 cp s3://$(cd infrastructure/terraform/environments/dev && terraform output -raw s3_frontend_bucket)/_next/static/chunks/main-*.js - | grep -o 'https://[^"]*'
```

**Solutions:**
1. Verify .env.production has custom domain
2. Rebuild frontend: `npm run build`
3. Redeploy to S3
4. Invalidate CloudFront cache
5. Hard refresh browser (Ctrl+Shift+R)

---

## Maintenance

### Regular Tasks

**Weekly:**
- Monitor certificate expiration date
- Check DNS resolution globally
- Review CloudWatch metrics

**Monthly:**
- Verify certificate auto-renewal status
- Review Route 53 query metrics
- Check for DNS propagation issues

**Quarterly:**
- Review and optimize DNS configuration
- Update documentation
- Test rollback procedures

### Monitoring

**CloudWatch Alarms:**
```bash
# Create alarm for certificate expiration
aws cloudwatch put-metric-alarm \
  --alarm-name acm-certificate-expiration \
  --alarm-description "Alert when certificate expires in 30 days" \
  --metric-name DaysToExpiry \
  --namespace AWS/CertificateManager \
  --statistic Minimum \
  --period 86400 \
  --evaluation-periods 1 \
  --threshold 30 \
  --comparison-operator LessThanThreshold \
  --dimensions Name=CertificateArn,Value=$(cd infrastructure/terraform/environments/dev && terraform output -raw acm_certificate_arn)
```

**Route 53 Health Checks:**
```bash
# Create health check for custom domain
aws route53 create-health-check \
  --type HTTPS \
  --resource-path /health \
  --fully-qualified-domain-name api.blacksteep.com \
  --port 443 \
  --request-interval 30 \
  --failure-threshold 3
```

### Cost

**Monthly Costs:**
- Route 53 Hosted Zone: $0.50/month
- Route 53 Queries: $0.40/million queries (first 1B)
- ACM Certificate: $0 (free for AWS services)
- DNS Queries: ~$1-5/month (typical usage)

**Total Estimated Cost:** $1.50-5.50/month

### Updates

**Terraform Updates:**
```bash
cd infrastructure/terraform/environments/dev

# Update Terraform
terraform init -upgrade

# Review changes
terraform plan

# Apply updates
terraform apply
```

**Certificate Renewal:**
- Automatic (no action required)
- ACM renews 60 days before expiration
- Validation records must remain in Route 53

---

## Related Documentation

- **Verification Report:** `CUSTOM_DOMAIN_VERIFICATION_REPORT.md`
- **Migration Spec:** `.kiro/specs/custom-domain-migration/`
- **Deployment Guide:** `DEPLOYMENT_GUIDE.md` (Custom Domain section)
- **Terraform Configuration:** `infrastructure/terraform/modules/ecs/`
- **Property Tests:**
  - `backend/tests/test_property_custom_domain_https.py`
  - `backend/tests/test_property_custom_domain_redirect.py`
  - `backend/tests/test_property_custom_domain_certificate_trust.py`

---

## Support

For issues or questions:

1. **Check Troubleshooting Section:** See above for common issues
2. **Review Verification Report:** `CUSTOM_DOMAIN_VERIFICATION_REPORT.md`
3. **Check AWS Console:**
   - Route 53: DNS records and hosted zone
   - ACM: Certificate status
   - ALB: Listener configuration
4. **Run Verification Script:** `python3 verify_custom_domain_e2e.py`
5. **Contact AWS Support:** For AWS service issues

---

**Last Updated:** November 25, 2025  
**Version:** 1.0.0  
**Status:** ✅ Active and Operational
