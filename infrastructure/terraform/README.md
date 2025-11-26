# Content Marketing Swarm - Terraform Infrastructure

This directory contains Terraform modules for deploying the Content Marketing Swarm application to AWS.

## Architecture Overview

The infrastructure consists of the following components:

- **VPC Module**: Virtual Private Cloud with public and private subnets across multiple availability zones
- **RDS Module**: PostgreSQL database with Multi-AZ deployment and read replicas
- **ECS Module**: Fargate cluster with auto-scaling for the FastAPI backend
- **S3 Module**: S3 buckets for images and frontend assets with CloudFront CDN
- **IAM Module**: IAM roles and policies with least-privilege access
- **Monitoring Module**: CloudWatch logs, metrics, alarms, and dashboards

## Module Structure

```
terraform/
├── modules/
│   ├── vpc/              # VPC, subnets, NAT gateways, security groups
│   ├── rds/              # PostgreSQL database
│   ├── ecs/              # ECS cluster, task definitions, ALB, auto-scaling
│   ├── s3/               # S3 buckets and CloudFront distributions
│   ├── iam/              # IAM roles and policies
│   └── monitoring/       # CloudWatch logs, alarms, and dashboards
└── environments/
    ├── dev/              # Development environment configuration
    └── prod/             # Production environment configuration
```

## Key Features

### VPC Module
- Multi-AZ deployment with public and private subnets
- NAT Gateways for private subnet internet access
- Security groups for ALB, ECS tasks, RDS, Lambda, and VPC endpoints
- Network isolation and least-privilege access

### RDS Module
- PostgreSQL 16.3 with Multi-AZ deployment
- Automated backups with 7-day retention
- Read replicas for analytics workloads
- Encryption at rest with KMS
- Performance Insights enabled
- Automated minor version upgrades

### ECS Module
- Fargate launch type for serverless container management
- Application Load Balancer with HTTPS support
- Auto-scaling based on CPU, memory, and request count (2-10 tasks)
- Task definitions with environment variables and secrets
- CloudWatch Logs integration
- X-Ray tracing support

### S3 Module
- Separate buckets for generated images and frontend assets
- CloudFront distributions with SSL/TLS support
- Origin Access Control (OAC) for secure S3 access
- Lifecycle policies for cost optimization:
  - Images: Transition to IA after 30 days, Glacier after 90 days
  - Automatic deletion after 365 days
- Versioning enabled for data protection
- Server-side encryption with AES256

### IAM Module
- ECS Task Execution Role: Pull images, read secrets, write logs
- ECS Task Role: Access Bedrock, S3, RDS, X-Ray
- Lambda Execution Role: VPC access, Bedrock, S3, RDS
- CloudWatch Logs and Metrics policies
- Least-privilege access with specific resource ARNs

### Monitoring Module
- CloudWatch Log Groups for ECS, Lambda, and application logs
- SNS topic for alert notifications
- CloudWatch Alarms:
  - ECS: CPU and memory utilization
  - ALB: Response time, 5xx errors, unhealthy targets
  - RDS: CPU, storage, connections
  - Application: Error count, agent performance
- Custom metrics for agent execution time
- CloudWatch Dashboard with key metrics

## Security Features

1. **Network Security**
   - Private subnets for backend services
   - Security groups with least-privilege rules
   - No public access to RDS or ECS tasks

2. **Data Encryption**
   - Encryption at rest for RDS and S3
   - TLS 1.2+ for all HTTPS connections
   - KMS encryption for sensitive data

3. **Access Control**
   - IAM roles with least-privilege policies
   - No hardcoded credentials
   - Secrets Manager for database passwords

4. **Monitoring & Auditing**
   - CloudWatch Logs for all services
   - X-Ray tracing for distributed requests
   - CloudWatch Alarms for anomaly detection

## Auto-Scaling Configuration

### ECS Service Auto-Scaling
- **Minimum tasks**: 2
- **Maximum tasks**: 10
- **Scaling triggers**:
  - CPU utilization > 70%
  - Memory utilization > 80%
  - Request count per target > 1000

### Scaling Policies
- Scale-out cooldown: 60 seconds
- Scale-in cooldown: 300 seconds
- Target tracking policies for smooth scaling

## Cost Optimization

1. **S3 Lifecycle Policies**
   - Automatic transition to cheaper storage classes
   - Deletion of old objects

2. **RDS**
   - Right-sized instance classes
   - Automated backups with retention limits
   - Read replicas only when needed

3. **CloudFront**
   - PriceClass_100 for cost-effective CDN
   - Caching to reduce origin requests

4. **CloudWatch**
   - Log retention policies (30 days default)
   - Metric filters for custom metrics only

## Deployment

### Prerequisites
- Terraform >= 1.0
- AWS CLI configured with appropriate credentials
- S3 bucket for Terraform state (recommended)

### Environment Variables
Set the following environment variables or use a `.tfvars` file:
- `AWS_REGION`: AWS region for deployment
- `PROJECT_NAME`: Name of the project
- `ENVIRONMENT`: Environment (dev, prod)
- `DATABASE_PASSWORD`: Master password for RDS (use Secrets Manager)

### Deployment Steps

1. Initialize Terraform:
```bash
cd environments/dev  # or prod
terraform init
```

2. Review the plan:
```bash
terraform plan
```

3. Apply the configuration:
```bash
terraform apply
```

4. Note the outputs for application configuration:
```bash
terraform output
```

## Outputs

Key outputs from the infrastructure:
- VPC ID and subnet IDs
- RDS endpoint and connection details
- ECS cluster name and service name
- ALB DNS name
- CloudFront distribution URLs
- IAM role ARNs
- CloudWatch log group names

## Maintenance

### Updating Infrastructure
1. Modify the relevant module
2. Run `terraform plan` to review changes
3. Run `terraform apply` to apply changes

### Monitoring
- Access CloudWatch Dashboard: AWS Console > CloudWatch > Dashboards
- View logs: AWS Console > CloudWatch > Log Groups
- Check alarms: AWS Console > CloudWatch > Alarms

### Scaling
- ECS auto-scaling is automatic based on metrics
- Manual scaling: Update `desired_count` in ECS module

## Troubleshooting

### Common Issues

1. **ECS tasks not starting**
   - Check CloudWatch Logs for task errors
   - Verify IAM role permissions
   - Check security group rules

2. **Database connection failures**
   - Verify security group allows ECS tasks to access RDS
   - Check database credentials in Secrets Manager
   - Verify RDS instance is in available state

3. **High costs**
   - Review CloudWatch metrics for over-provisioning
   - Check S3 lifecycle policies are working
   - Consider reducing RDS instance size for dev

## Property-Based Tests

Two property-based tests validate the infrastructure design:

1. **Property 42: Horizontal scaling under load**
   - Location: `backend/tests/test_property_horizontal_scaling.py`
   - Validates: Auto-scaling maintains performance under load
   - Status: ✅ Passed

2. **Property 44: Frontend deployment configuration**
   - Location: `backend/tests/test_property_frontend_deployment.py`
   - Validates: HTTPS, SSL certificates, and CDN caching
   - Status: ✅ Passed

## HTTPS Configuration

### Overview

The Application Load Balancer (ALB) is configured with HTTPS support to enable secure communication between the CloudFront-hosted frontend and the backend API. This eliminates mixed content errors and ensures all traffic is encrypted in transit.

### Architecture

```
Frontend (CloudFront HTTPS) → Backend (ALB HTTPS) → ECS Fargate
                                ✅ Secure Communication
```

### Components

#### 1. ACM Certificate

**Resource:** `aws_acm_certificate.alb_cert`

The infrastructure uses AWS Certificate Manager (ACM) to provision and manage SSL/TLS certificates:

- **Validation Method:** DNS validation (automatic)
- **Certificate Type:** Public certificate (free)
- **Renewal:** Automatic by ACM (no manual intervention required)
- **Region:** Must match ALB region (us-east-1)

**Terraform Configuration:**
```hcl
resource "aws_acm_certificate" "alb_cert" {
  domain_name       = aws_lb.main.dns_name
  validation_method = "DNS"
  
  lifecycle {
    create_before_destroy = true
  }
  
  tags = {
    Name        = "${var.project_name}-${var.environment}-alb-cert"
    Environment = var.environment
  }
}

resource "aws_acm_certificate_validation" "alb_cert" {
  certificate_arn = aws_acm_certificate.alb_cert.arn
}
```

#### 2. HTTPS Listener (Port 443)

**Resource:** `aws_lb_listener.https`

The HTTPS listener accepts secure traffic on port 443 and forwards it to the ECS target group:

- **Port:** 443
- **Protocol:** HTTPS
- **SSL Policy:** ELBSecurityPolicy-TLS13-1-2-2021-06
  - Supports TLS 1.2 and TLS 1.3
  - Strong cipher suites
  - Compatible with modern browsers
- **Certificate:** Attached ACM certificate
- **Default Action:** Forward to ECS target group

**Terraform Configuration:**
```hcl
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.main.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = aws_acm_certificate.alb_cert.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main.arn
  }
}
```

#### 3. HTTP to HTTPS Redirect (Port 80)

**Resource:** `aws_lb_listener.http_redirect`

The HTTP listener redirects all insecure traffic to HTTPS:

- **Port:** 80
- **Protocol:** HTTP
- **Redirect:** 301 (permanent) to HTTPS on port 443
- **Preserves:** Path and query parameters

**Terraform Configuration:**
```hcl
resource "aws_lb_listener" "http_redirect" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}
```

#### 4. Security Group Rules

**Resource:** `aws_security_group_rule.alb_https_ingress`

Security group rules allow HTTPS traffic to the ALB:

- **Port:** 443
- **Protocol:** TCP
- **Source:** 0.0.0.0/0 (public internet)
- **Existing Rule:** Port 80 remains for redirects

**Terraform Configuration:**
```hcl
resource "aws_security_group_rule" "alb_https_ingress" {
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.alb.id
  description       = "Allow HTTPS traffic from internet"
}
```

### Domain Strategy

**Current Approach:** Using ALB DNS name directly with ACM certificate

The infrastructure uses the ALB's AWS-provided DNS name for HTTPS configuration:
- **Domain:** `content-marketing-swarm-dev-alb-41944691.us-east-1.elb.amazonaws.com`
- **Certificate:** AWS Certificate Manager (ACM)
- **Validation:** DNS validation (automatic)

This approach provides:
- Immediate HTTPS enablement without custom domain setup
- Zero additional cost (ACM certificates are free for AWS services)
- Automatic certificate renewal by ACM
- No Route 53 configuration required

### Future Enhancement: Custom Domain

For production deployments, consider migrating to a custom domain:
1. Register domain or configure existing domain in Route 53
2. Create hosted zone in Route 53
3. Request ACM certificate for custom domain
4. Create Route 53 alias record pointing to ALB
5. Update frontend environment variables
6. Redeploy frontend application

**Documentation:** See `.kiro/specs/https-alb-setup/DOMAIN_STRATEGY.md` for detailed analysis

### Deployment Process

#### Step 1: Provision ACM Certificate

```bash
cd infrastructure/terraform/environments/dev  # or prod
terraform apply -target=aws_acm_certificate.alb_cert
```

**Expected Duration:** 5-30 minutes (depends on DNS validation)

**Verification:**
```bash
# Check certificate status
aws acm describe-certificate \
  --certificate-arn $(terraform output -raw acm_certificate_arn) \
  --region us-east-1

# Status should be "ISSUED"
```

#### Step 2: Create HTTPS Listener and Update HTTP Listener

```bash
terraform apply
```

This creates:
- HTTPS listener on port 443
- Updates HTTP listener to redirect to HTTPS
- Adds security group rule for port 443

**Expected Duration:** 2-3 minutes

#### Step 3: Update Frontend Configuration

Update `frontend/.env.production` with HTTPS endpoints:

```bash
# Backend API URL (HTTPS)
NEXT_PUBLIC_API_URL=https://<alb-dns-name>

# WebSocket URL (WSS)
NEXT_PUBLIC_WS_URL=wss://<alb-dns-name>/ws/stream-generation
```

#### Step 4: Rebuild and Redeploy Frontend

```bash
cd frontend
npm run build
aws s3 sync out/ s3://<frontend-bucket>/ --delete
aws cloudfront create-invalidation --distribution-id <dist-id> --paths "/*"
```

**Expected Duration:** 5-10 minutes

### Verification

#### 1. Test HTTPS Endpoint

```bash
# Get ALB DNS name
ALB_DNS=$(cd infrastructure/terraform/environments/dev && terraform output -raw alb_dns_name)

# Test HTTPS endpoint
curl -v https://${ALB_DNS}/health

# Expected: 200 OK with valid TLS handshake
```

#### 2. Test HTTP Redirect

```bash
# Test HTTP redirect
curl -v http://${ALB_DNS}/health

# Expected: 301 redirect with Location header pointing to HTTPS
```

#### 3. Verify Certificate

```bash
# Check certificate details
openssl s_client -connect ${ALB_DNS}:443 -servername ${ALB_DNS} < /dev/null

# Verify:
# - Certificate is valid
# - Issuer is Amazon
# - Not expired
```

#### 4. Test Frontend

```bash
# Open frontend in browser
# Check Network tab in developer tools
# Verify:
# - All API requests use HTTPS
# - WebSocket connections use WSS
# - No mixed content warnings
```

### Troubleshooting

#### Certificate Validation Stuck

**Symptom:** ACM certificate remains in "Pending Validation" status

**Solutions:**
1. Check DNS validation records are created
2. Verify domain is accessible
3. Wait up to 30 minutes for validation
4. Consider using email validation as alternative

```bash
# Check certificate validation status
aws acm describe-certificate \
  --certificate-arn <cert-arn> \
  --region us-east-1 \
  --query 'Certificate.DomainValidationOptions'
```

#### HTTPS Listener Not Responding

**Symptom:** HTTPS requests timeout or fail

**Solutions:**
1. Verify security group allows port 443
2. Check certificate is attached to listener
3. Verify target group health checks pass
4. Review ALB access logs

```bash
# Check security group rules
aws ec2 describe-security-groups \
  --group-ids <alb-security-group-id> \
  --query 'SecurityGroups[0].IpPermissions'

# Check listener configuration
aws elbv2 describe-listeners \
  --load-balancer-arn <alb-arn> \
  --query 'Listeners[?Port==`443`]'
```

#### Mixed Content Errors Persist

**Symptom:** Browser shows mixed content warnings after HTTPS setup

**Solutions:**
1. Verify frontend environment variables use HTTPS/WSS
2. Confirm frontend was rebuilt with new variables
3. Check CloudFront cache was invalidated
4. Inspect browser Network tab for HTTP requests

```bash
# Verify environment variables in deployed frontend
aws s3 cp s3://<frontend-bucket>/_next/static/chunks/main-*.js - | grep -o 'http://[^"]*'

# Should return no results (all should be HTTPS)
```

#### Certificate Renewal Issues

**Symptom:** Certificate approaching expiration

**Solutions:**
ACM automatically renews certificates 60 days before expiration. If renewal fails:

1. Check domain validation records still exist
2. Verify domain is still accessible
3. Review ACM console for renewal status
4. Contact AWS support if automatic renewal fails

```bash
# Check certificate expiration
aws acm describe-certificate \
  --certificate-arn <cert-arn> \
  --region us-east-1 \
  --query 'Certificate.NotAfter'
```

### Security Considerations

1. **TLS Version:** Minimum TLS 1.2, prefer TLS 1.3
2. **Cipher Suites:** Use AWS recommended security policy
3. **Certificate Management:** ACM handles private keys securely
4. **HSTS Headers:** Consider adding Strict-Transport-Security header
5. **Certificate Transparency:** ACM certificates are logged in CT logs

### Performance Impact

- **TLS Handshake:** ~50-100ms additional latency for initial connection
- **Connection Reuse:** HTTP/2 and keep-alive reduce overhead
- **Certificate Caching:** Browsers cache certificate validation
- **Overall Impact:** Minimal (<5% increase in response time)

### Cost

- **ACM Certificate:** $0 (free for AWS services)
- **ALB HTTPS Listener:** $0 (no additional cost beyond existing ALB)
- **Data Transfer:** Same as HTTP (no additional cost)

**Total Additional Cost:** $0/month

### Related Documentation

- **HTTPS Setup Spec:** `.kiro/specs/https-alb-setup/`
- **Domain Strategy:** `.kiro/specs/https-alb-setup/DOMAIN_STRATEGY.md`
- **Quick Reference:** `.kiro/specs/https-alb-setup/QUICK_REFERENCE.md`
- **Property Tests:** 
  - `backend/tests/test_property_https_listener.py`
  - `backend/tests/test_property_http_redirect.py`
  - `backend/tests/test_property_certificate_validity.py`
  - `frontend/__tests__/test_property_frontend_deployment.test.tsx`

## Next Steps

After infrastructure deployment:
1. Deploy the FastAPI backend Docker image to ECR
2. Update ECS task definition with the image URI
3. Deploy the Next.js frontend to S3
4. Configure HTTPS on ALB (see HTTPS Configuration section)
5. Set up CI/CD pipeline for automated deployments
6. Configure AgentCore Runtime for agent deployment
7. Set up Gateway integrations for social media APIs

## Support

For issues or questions:
- Review CloudWatch Logs and Alarms
- Check AWS Service Health Dashboard
- Review Terraform state for resource details
